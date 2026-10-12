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

        // Branching in this method is kept deliberately low: the Graph Engine
        // enumerates every path through the search entry point, and each
        // conditional here multiplies that count. Clamps therefore use
        // Math.min/Math.max, observed values are collected unconditionally and
        // nulls removed once at the end, and one ternary decides whether the
        // client sent a complete continuation cursor - which also lets the
        // analysis see that `working` is never null.
        //
        // A cursor without a position, or without the pinned bounds (a
        // hand-built payload), starts the search afresh rather than resuming.
        AuditCursor working = (cursor == null ||
            cursor.lastDateMillis == null ||
            cursor.rangeStartMillis == null ||
            cursor.rangeEndMillis == null)
            ? new AuditCursor()
            : cursor;
        Boolean continuing = working.lastDateMillis != null;

        // The range is resolved on the first call and pinned in the cursor so
        // the lower bound cannot drift between pages, whatever the client sends
        // on later calls.
        if (!continuing) {
            pinRange(effective, working);
        }
        // The cursor is client-supplied, so its pinned bounds are re-clamped
        // here rather than trusted: nothing below the retention floor can
        // exist, and no position may sit above the range end.
        Long floorMillis = Datetime.now().addDays(-RETENTION_DAYS).getTime();
        Datetime lowerBound = Datetime.newInstance(Math.max(working.rangeStartMillis, floorMillis));
        Datetime rangeEnd = Datetime.newInstance(working.rangeEndMillis);

        // Validate the continuation position before anything else: a cursor
        // that claims a position without a well-formed id is rejected outright.
        Id lastId = working.lastIdValue();
        Datetime upperBound = continuing
            ? Datetime.newInstance(Math.min(working.lastDateMillis, working.rangeEndMillis))
            : rangeEnd;

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
                // Sets ignore repeats; null and blank are removed once, below.
                observedSections.add(row.section);
                observedActions.add(row.action);
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
            // Keyset advance: resume strictly after the last consumed row. The
            // id was just written by consume() from a provider row, so it needs
            // no validation here (and no extra branches for the path analysis).
            upperBound = working.lastDate();
            lastId = (Id) working.lastId;
        }

        if (exhausted) {
            // Once the range is exhausted the whole window down to the lower
            // bound has been covered, so "searched back to" reports the range
            // boundary rather than the oldest row that happened to exist. (An
            // empty first fetch also lands here, so the value is never left
            // null.)
            result.scannedThroughMillis = lowerBound.getTime();
        }
        result.done = exhausted;
        working.exhausted = exhausted;
        observedSections.remove(null);
        observedSections.remove('');
        observedActions.remove(null);
        observedActions.remove('');
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
        Long floorMillis = now.addDays(-RETENTION_DAYS).getTime();
        if (filter.lastDays != null && filter.lastDays > 0) {
            cursor.rangeEndMillis = now.getTime();
            cursor.rangeStartMillis = now.addDays(-Math.min(filter.lastDays, RETENTION_DAYS)).getTime();
        } else {
            Long requestedStart = filter.startDateMillis == null ? floorMillis : filter.startDateMillis;
            cursor.rangeEndMillis = filter.endDateMillis == null ? now.getTime() : filter.endDateMillis;
            cursor.rangeStartMillis = Math.max(requestedStart, floorMillis);
        }
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
                // the term count may be left to the client. Trimming first
                // means split() yields no empty tokens, so no per-token check
                // is needed.
                List<String> words = filter.searchText.left(MAX_SEARCH_TEXT_LENGTH).trim().toLowerCase().split('\\s+');
                Integer limitCount = Math.min(words.size(), MAX_SEARCH_TERMS);
                for (Integer i = 0; i < limitCount; i++) {
                    terms.add(words[i]);
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
            // Null fields must not reach the haystack: String.valueOf(null) or
            // concatenation would yield the literal word "null", making the
            // term "null" match every row with an empty field. They are dropped
            // through a set rather than conditionals because this runs once per
            // scanned row, and every conditional here multiplies the Graph
            // Engine's path count for the whole search entry point.
            Set<String> parts = new Set<String>{ row.display, row.section, row.action, row.userName };
            parts.remove(null);
            String haystack = String.join(new List<String>(parts), ' ').toLowerCase();
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
