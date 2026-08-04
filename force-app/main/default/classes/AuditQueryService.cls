/**
 * Progressive, time-sliced search over the Setup Audit Trail.
 *
 * Why this is not a simple SOQL query:
 *
 *  - `Section` and `Display` are NOT filterable on SetupAuditTrail, so the two
 *    fields users most want to search on cannot be pushed into a WHERE clause.
 *    They must be evaluated in Apex over rows already fetched.
 *  - SetupAuditTrail supports no aggregate functions, so counts/facets must also
 *    be computed in Apex.
 *  - Naively fetching six months of audit data to filter in memory would blow the
 *    50,000 SOQL row and heap limits in any large org.
 *
 * The service therefore walks backwards through time in bounded batches, applies
 * the non-filterable criteria to each batch, and returns as soon as it has filled
 * a page - handing back a cursor so the client can resume. Each call is its own
 * transaction with a hard scan ceiling, so governor limits never bind regardless
 * of how much audit history the org has.
 */
public with sharing class AuditQueryService {
    /** Salesforce retains Setup Audit Trail for 180 days; older data cannot exist. */
    public static final Integer RETENTION_DAYS = 180;

    private static final Integer SCAN_BATCH = 1000;
    private static final Integer MAX_BATCHES_PER_CALL = 10;
    public static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE = 200;

    @TestVisible
    private static AuditTrailProvider provider = new SetupAuditTrailProvider();

    public static AuditSearchResult search(AuditFilter filter, AuditCursor cursor, Integer pageSize) {
        AuditFilter effective = filter == null ? new AuditFilter() : filter;
        Integer targetPage = clampPageSize(pageSize);

        Datetime retentionFloor = Datetime.now().addDays(-RETENTION_DAYS);
        Datetime lowerBound = effective.startDate();
        if (lowerBound == null || lowerBound < retentionFloor) {
            // Nothing can exist below the retention floor, so don't scan for it.
            lowerBound = retentionFloor;
        }

        AuditCursor working = (cursor == null || cursor.lastDateMillis == null)
            ? new AuditCursor()
            : cursor;
        Datetime upperBound = working.lastDateMillis == null
            ? (effective.endDate() == null ? Datetime.now() : effective.endDate())
            : working.lastDate();

        AuditSearchResult result = new AuditSearchResult();
        result.cursor = working;

        if (upperBound < lowerBound) {
            result.done = true;
            working.exhausted = true;
            result.scannedThroughMillis = lowerBound.getTime();
            return result;
        }

        CompiledFilter compiled = new CompiledFilter(effective);
        Set<String> observedSections = new Set<String>();
        Set<String> observedActions = new Set<String>();
        Map<String, Integer> sectionCounts = new Map<String, Integer>();
        Map<String, Integer> actionCounts = new Map<String, Integer>();
        Map<String, Integer> userCounts = new Map<String, Integer>();

        Boolean pageFull = false;
        Boolean exhausted = false;
        Integer batches = 0;

        while (!pageFull && batches < MAX_BATCHES_PER_CALL) {
            List<AuditEventRow> batch = provider.fetch(
                upperBound,
                lowerBound,
                effective.actions,
                effective.userIds,
                working.seenIdSet(),
                SCAN_BATCH
            );
            batches++;

            if (batch.isEmpty()) {
                exhausted = true;
                break;
            }

            for (AuditEventRow row : batch) {
                result.scannedCount++;
                result.scannedThroughMillis = row.eventDateMillis;
                if (String.isNotBlank(row.section)) {
                    observedSections.add(row.section);
                }
                if (String.isNotBlank(row.action)) {
                    observedActions.add(row.action);
                }
                // Advance the cursor for every scanned row, matched or not - the
                // cursor tracks scan position, not match position.
                working.consume(row);

                if (compiled.matches(row)) {
                    result.rows.add(row);
                    tally(sectionCounts, row.section);
                    tally(actionCounts, row.action);
                    tally(userCounts, row.userName);
                    if (result.rows.size() >= targetPage) {
                        pageFull = true;
                        break;
                    }
                }
            }

            if (pageFull) {
                break;
            }
            if (batch.size() < SCAN_BATCH) {
                // A short batch means the range below has no more rows.
                exhausted = true;
                break;
            }
            upperBound = working.lastDate();
        }

        if (result.scannedThroughMillis == null) {
            result.scannedThroughMillis = lowerBound.getTime();
        }
        result.done = exhausted;
        working.exhausted = exhausted;
        result.observedSections = sorted(observedSections);
        result.observedActions = sorted(observedActions);
        result.sectionFacets = toFacets(sectionCounts);
        result.actionFacets = toFacets(actionCounts);
        result.userFacets = toFacets(userCounts);
        return result;
    }

    private static Integer clampPageSize(Integer requested) {
        if (requested == null || requested <= 0) {
            return DEFAULT_PAGE_SIZE;
        }
        return Math.min(requested, MAX_PAGE_SIZE);
    }

    private static void tally(Map<String, Integer> counts, String key) {
        if (String.isBlank(key)) {
            return;
        }
        counts.put(key, counts.containsKey(key) ? counts.get(key) + 1 : 1);
    }

    private static List<String> sorted(Set<String> values) {
        List<String> ordered = new List<String>(values);
        ordered.sort();
        return ordered;
    }

    private static List<AuditSearchResult.AuditFacet> toFacets(Map<String, Integer> counts) {
        List<AuditSearchResult.AuditFacet> facets = new List<AuditSearchResult.AuditFacet>();
        for (String key : counts.keySet()) {
            facets.add(new AuditSearchResult.AuditFacet(key, counts.get(key)));
        }
        facets.sort();
        return facets;
    }

    /**
     * Pre-computes the criteria that cannot be pushed into SOQL, so the per-row
     * work inside the scan loop stays cheap.
     */
    private with sharing class CompiledFilter {
        private Set<String> sections;
        private List<String> terms;

        private CompiledFilter(AuditFilter filter) {
            sections = new Set<String>();
            if (filter.sections != null) {
                for (String section : filter.sections) {
                    if (String.isNotBlank(section)) {
                        sections.add(section.toLowerCase());
                    }
                }
            }
            terms = new List<String>();
            if (String.isNotBlank(filter.searchText)) {
                for (String term : filter.searchText.toLowerCase().split('\\s+')) {
                    if (String.isNotBlank(term)) {
                        terms.add(term);
                    }
                }
            }
        }

        private Boolean matches(AuditEventRow row) {
            if (!sections.isEmpty()) {
                if (String.isBlank(row.section) || !sections.contains(row.section.toLowerCase())) {
                    return false;
                }
            }
            if (terms.isEmpty()) {
                return true;
            }
            String haystack = (
                    String.valueOf(row.display) +
                    ' ' +
                    String.valueOf(row.section) +
                    ' ' +
                    String.valueOf(row.action) +
                    ' ' +
                    String.valueOf(row.userName)
                )
                .toLowerCase();
            // All terms must be present, so multi-word searches narrow results.
            for (String term : terms) {
                if (!haystack.contains(term)) {
                    return false;
                }
            }
            return true;
        }
    }
}
