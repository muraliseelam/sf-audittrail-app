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
 *
 * The date range is resolved once, on the first call of a search, and pinned in
 * the cursor; every continuation pages over exactly that window. Paging itself
 * is keyset-based on (CreatedDate, Id) - see AuditCursor.
 */
public with sharing class AuditQueryService {
    /** Salesforce retains Setup Audit Trail for 180 days; older data cannot exist. */
    public static final Integer RETENTION_DAYS = 180;

    /**
     * Scan tuning. Non-final and @TestVisible so tests can shrink them and
     * exercise the multi-batch and scan-ceiling paths with a few hundred rows
     * instead of tens of thousands; nothing outside tests assigns them. Named
     * as variables rather than constants for the same reason.
     */
    @TestVisible
    private static Integer scanBatch = 1000;
    @TestVisible
    private static Integer maxBatchesPerCall = 10;
    public static final Integer DEFAULT_PAGE_SIZE = 50;
    private static final Integer MAX_PAGE_SIZE = 200;

    /**
     * Bounds on the free-text filter. The haystack test runs once per scanned
     * row, so with up to scanBatch * maxBatchesPerCall (10,000) rows per
     * call the per-row cost must be bounded: at most this many characters of
     * search text and this many whitespace-separated terms are honoured.
     */
    private static final Integer MAX_SEARCH_TEXT_LENGTH = 200;
    private static final Integer MAX_SEARCH_TERMS = 10;

    @TestVisible
    private static AuditTrailProvider provider = new SetupAuditTrailProvider();

    public static AuditSearchResult search(AuditFilter filter, AuditCursor cursor, Integer pageSize) {
        AuditFilter effective = filter == null ? new AuditFilter() : filter;
        Integer targetPage = clampPageSize(pageSize);

        // A cursor without a position is treated as absent. The null check is
        // kept inline in the ternary so static analysis can see that `working`
        // is never null.
        AuditCursor working = (cursor == null || cursor.lastDateMillis == null) ? new AuditCursor() : cursor;
        Boolean continuing = working.lastDateMillis != null;

        // The range is resolved on the first call and pinned in the cursor so
        // the lower bound cannot drift between pages, whatever the client sends
        // on later calls. A continuation cursor missing either bound (older
        // client, hand-built payload) falls back to recomputing from the filter.
        if (!continuing || working.rangeStartMillis == null || working.rangeEndMillis == null) {
            pinRange(effective, working);
        }
        // The cursor is client-supplied, so its pinned bounds are re-clamped
        // here rather than trusted: nothing below the retention floor can
        // exist, and no position may sit above the range end.
        Datetime retentionFloor = Datetime.now().addDays(-RETENTION_DAYS);
        Datetime lowerBound = Datetime.newInstance(working.rangeStartMillis);
        if (lowerBound < retentionFloor) {
            lowerBound = retentionFloor;
        }
        Datetime rangeEnd = Datetime.newInstance(working.rangeEndMillis);

        // Validate the continuation position before anything else: a cursor
        // that claims a position without a well-formed id is rejected outright.
        Id lastId = working.lastIdValue();
        Datetime upperBound = continuing ? working.lastDate() : rangeEnd;
        if (upperBound > rangeEnd) {
            upperBound = rangeEnd;
        }

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

        while (!pageFull && batches < maxBatchesPerCall) {
            List<AuditEventRow> batch = provider.fetch(
                upperBound,
                lowerBound,
                effective.actions,
                effective.userIds,
                lastId,
                scanBatch
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
            if (batch.size() < scanBatch) {
                // A short batch means the range below has no more rows.
                exhausted = true;
                break;
            }
            // Keyset advance: resume strictly after the last consumed row.
            upperBound = working.lastDate();
            lastId = working.lastIdValue();
        }

        if (exhausted || result.scannedThroughMillis == null) {
            // Once the range is exhausted the whole window down to the lower
            // bound has been covered, so "searched back to" reports the range
            // boundary rather than the oldest row that happened to exist.
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

    /**
     * Resolves the search window from the filter using the server clock and
     * writes it into the cursor.
     *
     * A positive lastDays wins over explicit dates: end = now, start = now minus
     * min(lastDays, RETENTION_DAYS). Otherwise the explicit dates apply, with a
     * null end meaning now and the start clamped to the retention floor -
     * nothing can exist below it, so there is no point scanning for it.
     */
    private static void pinRange(AuditFilter filter, AuditCursor cursor) {
        Datetime now = Datetime.now();
        Datetime retentionFloor = now.addDays(-RETENTION_DAYS);
        Datetime rangeStart;
        Datetime rangeEnd;
        if (filter.lastDays != null && filter.lastDays > 0) {
            rangeEnd = now;
            rangeStart = now.addDays(-Math.min(filter.lastDays, RETENTION_DAYS));
        } else {
            rangeEnd = filter.endDate() == null ? now : filter.endDate();
            rangeStart = filter.startDate();
            if (rangeStart == null || rangeStart < retentionFloor) {
                rangeStart = retentionFloor;
            }
        }
        cursor.rangeStartMillis = rangeStart.getTime();
        cursor.rangeEndMillis = rangeEnd.getTime();
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
                // Bounded on purpose: the term loop runs once per scanned row,
                // up to 10,000 rows per call, so neither the text length nor
                // the term count may be left to the client.
                String bounded = filter.searchText.left(MAX_SEARCH_TEXT_LENGTH).toLowerCase();
                for (String term : bounded.split('\\s+')) {
                    if (String.isNotBlank(term)) {
                        terms.add(term);
                        if (terms.size() >= MAX_SEARCH_TERMS) {
                            break;
                        }
                    }
                }
            }
        }

        private Boolean matches(AuditEventRow row) {
            if (!sections.isEmpty() && (String.isBlank(row.section) || !sections.contains(row.section.toLowerCase()))) {
                return false;
            }
            if (terms.isEmpty()) {
                return true;
            }
            // Blank fields coalesce to '' - String.valueOf(null) would yield
            // the literal word "null", making the term "null" match every row
            // with an empty field.
            String haystack = (blankToEmpty(row.display) +
                ' ' +
                blankToEmpty(row.section) +
                ' ' +
                blankToEmpty(row.action) +
                ' ' +
                blankToEmpty(row.userName))
                .toLowerCase();
            // All terms must be present, so multi-word searches narrow results.
            for (String term : terms) {
                if (!haystack.contains(term)) {
                    return false;
                }
            }
            return true;
        }

        private String blankToEmpty(String value) {
            return String.isBlank(value) ? '' : value;
        }
    }
}
