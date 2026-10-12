@IsTest
private class AuditQueryServiceTest {
    // Must be relative to now: the service correctly refuses to scan below the
    // 180-day retention floor, so a hardcoded date would silently match nothing.
    private static final Datetime BASE = Datetime.now().addDays(-5);

    private static List<AuditEventRow> descendingRows(Integer count) {
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < count; i++) {
            rows.add(
                MockAuditTrailProvider.row(
                    i + 1,
                    BASE.addMinutes(-i),
                    Math.mod(i, 2) == 0 ? 'Manage Users' : 'Apex Class',
                    'changedpassword',
                    'Event number ' + i
                )
            );
        }
        return rows;
    }

    /** Rows at distinct, descending timestamps that all share one section. */
    private static List<AuditEventRow> rowsInSection(Integer count, String section) {
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < count; i++) {
            rows.add(MockAuditTrailProvider.row(i + 1, BASE.addMinutes(-i), section, 'changedpassword', 'Event ' + i));
        }
        return rows;
    }

    /** Rows that all share a single timestamp, as one deployment produces. */
    private static List<AuditEventRow> rowsAtOneTimestamp(Integer count) {
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < count; i++) {
            rows.add(MockAuditTrailProvider.row(i + 1, BASE, 'Apex Class', 'changedApexClass', 'Deployed class ' + i));
        }
        return rows;
    }

    private static AuditFilter wideOpenFilter() {
        AuditFilter f = new AuditFilter();
        f.startDateMillis = BASE.addDays(-10).getTime();
        f.endDateMillis = BASE.addDays(1).getTime();
        return f;
    }

    /** Shrinks the scan so a few hundred rows exercise the multi-batch paths. */
    private static void useSmallBatches() {
        AuditQueryService.SCAN_BATCH = 100;
        AuditQueryService.MAX_BATCHES_PER_CALL = 3;
    }

    /**
     * Explicit dates alongside a non-positive lastDays. The window (BASE - 2
     * days to BASE + 1 day) differs from anything a preset would derive from
     * the clock, so the pinned range shows which rule was applied.
     */
    private static AuditFilter explicitRangeWithLastDays(Integer lastDays) {
        AuditFilter filter = new AuditFilter();
        filter.lastDays = lastDays;
        filter.startDateMillis = BASE.addDays(-2).getTime();
        filter.endDateMillis = BASE.addDays(1).getTime();
        return filter;
    }

    private static void assertExplicitRangeWasPinned(AuditFilter filter, AuditSearchResult result) {
        Assert.areEqual(
            filter.startDateMillis,
            result.cursor.rangeStartMillis,
            'A non-positive lastDays must leave the explicit start date in force.'
        );
        Assert.areEqual(
            filter.endDateMillis,
            result.cursor.rangeEndMillis,
            'A non-positive lastDays must leave the explicit end date in force.'
        );
        Assert.areEqual(3, result.rows.size(), 'Rows five days old sit inside the explicit window.');
    }

    @IsTest
    static void returnsFirstPageAndReportsNotDone() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(25));

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(wideOpenFilter(), null, 10);
        Test.stopTest();

        Assert.areEqual(10, result.rows.size(), 'Should fill the requested page size.');
        Assert.isFalse(result.done, 'More rows remain, so the search is not done.');
        Assert.isNotNull(result.cursor.lastDateMillis, 'Cursor must be positioned.');
        Assert.isNotNull(result.cursor.lastId, 'Cursor must carry the keyset id.');
    }

    @IsTest
    static void pagingCoversEveryRowExactlyOnce() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(25));

        Set<String> collected = new Set<String>();
        Integer totalReturned = 0;
        AuditCursor cursor = null;
        Integer guard = 0;

        Test.startTest();
        while (guard++ < 20) {
            AuditSearchResult page = AuditQueryService.search(wideOpenFilter(), cursor, 10);
            for (AuditEventRow row : page.rows) {
                collected.add(row.recordId);
                totalReturned++;
            }
            cursor = page.cursor;
            if (page.done) {
                break;
            }
        }
        Test.stopTest();

        Assert.areEqual(25, totalReturned, 'Every row should be returned.');
        Assert.areEqual(25, collected.size(), 'No row should be returned twice.');
    }

    @IsTest
    static void handlesManyRowsSharingOneTimestamp() {
        // A single metadata deployment writes many audit rows in the same second.
        // Date-only keyset paging would skip or duplicate these.
        AuditQueryService.provider = new MockAuditTrailProvider(rowsAtOneTimestamp(12));

        Set<String> collected = new Set<String>();
        Integer totalReturned = 0;
        AuditCursor cursor = null;
        Integer guard = 0;

        Test.startTest();
        while (guard++ < 20) {
            AuditSearchResult page = AuditQueryService.search(wideOpenFilter(), cursor, 5);
            for (AuditEventRow row : page.rows) {
                collected.add(row.recordId);
                totalReturned++;
            }
            cursor = page.cursor;
            if (page.done) {
                break;
            }
        }
        Test.stopTest();

        Assert.areEqual(12, totalReturned, 'All same-timestamp rows must be returned.');
        Assert.areEqual(12, collected.size(), 'All same-timestamp rows must be returned exactly once.');
    }

    @IsTest
    static void filtersOnSectionWhichSoqlCannotDo() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(20));
        AuditFilter filter = wideOpenFilter();
        filter.sections = new List<String>{ 'Apex Class' };

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.areEqual(10, result.rows.size(), 'Only Apex Class rows should match.');
        for (AuditEventRow row : result.rows) {
            Assert.areEqual('Apex Class', row.section, 'Section filter must be applied.');
        }
        Assert.areEqual(20, result.scannedCount, 'Non-matching rows are still scanned.');
    }

    @IsTest
    static void searchTextRequiresAllTerms() {
        List<AuditEventRow> rows = new List<AuditEventRow>{
            MockAuditTrailProvider.row(
                1,
                BASE,
                'Manage Users',
                'permsetAssign',
                'Assigned permission set Admin to Jane'
            ),
            MockAuditTrailProvider.row(
                2,
                BASE.addMinutes(-1),
                'Manage Users',
                'permsetAssign',
                'Assigned permission set Admin to Bob'
            ),
            MockAuditTrailProvider.row(3, BASE.addMinutes(-2), 'Manage Users', 'deactivate', 'Deactivated user Jane')
        };
        AuditQueryService.provider = new MockAuditTrailProvider(rows);

        AuditFilter filter = wideOpenFilter();
        filter.searchText = 'permission jane';

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.areEqual(1, result.rows.size(), 'Both terms must appear for a match.');
        Assert.areEqual(MockAuditTrailProvider.fakeId(1), result.rows[0].recordId);
    }

    @IsTest
    static void searchTextIsCaseInsensitive() {
        AuditQueryService.provider = new MockAuditTrailProvider(
            new List<AuditEventRow>{
                MockAuditTrailProvider.row(1, BASE, 'Manage Users', 'deactivate', 'Deactivated user Jane')
            }
        );
        AuditFilter filter = wideOpenFilter();
        filter.searchText = 'DEACTIVATED';

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.areEqual(1, result.rows.size(), 'Search should ignore case.');
    }

    @IsTest
    static void blankFieldDoesNotMatchTheWordNull() {
        // String.valueOf(null) is the literal "null"; the haystack must coalesce
        // blank fields to '' so that searching for "null" only finds rows that
        // genuinely contain the word.
        AuditQueryService.provider = new MockAuditTrailProvider(
            new List<AuditEventRow>{
                MockAuditTrailProvider.row(1, BASE, 'Manage Users', 'deactivate', null),
                MockAuditTrailProvider.row(
                    2,
                    BASE.addMinutes(-1),
                    'Custom Objects',
                    'changedfield',
                    'Set default to null'
                )
            }
        );
        AuditFilter filter = wideOpenFilter();
        filter.searchText = 'null';

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.areEqual(1, result.rows.size(), 'Only the row whose text contains "null" may match.');
        Assert.areEqual(
            MockAuditTrailProvider.fakeId(2),
            result.rows[0].recordId,
            'The blank-display row must not match.'
        );
    }

    @IsTest
    static void searchTextHonoursOnlyTheFirstTenTerms() {
        // The per-row cost of the text filter is bounded: terms beyond the
        // tenth are ignored, so an eleventh non-matching term cannot exclude a
        // row that matches the first ten.
        AuditQueryService.provider = new MockAuditTrailProvider(
            new List<AuditEventRow>{
                MockAuditTrailProvider.row(
                    1,
                    BASE,
                    'Manage Users',
                    'deactivate',
                    'alpha beta gamma delta epsilon zeta eta theta iota kappa'
                )
            }
        );
        AuditFilter filter = wideOpenFilter();
        filter.searchText = 'alpha beta gamma delta epsilon zeta eta theta iota kappa zzznomatch';

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.areEqual(1, result.rows.size(), 'Terms past the tenth must be ignored.');
    }

    @IsTest
    static void searchTextIsTruncatedToTwoHundredCharacters() {
        // Text beyond the 200-character bound is dropped before it is split
        // into terms, so a non-matching term placed past the bound is ignored.
        AuditQueryService.provider = new MockAuditTrailProvider(
            new List<AuditEventRow>{
                MockAuditTrailProvider.row(1, BASE, 'Manage Users', 'deactivate', 'Deactivated user Jane')
            }
        );
        AuditFilter filter = wideOpenFilter();
        filter.searchText = 'jane'.rightPad(200, ' ') + 'zzznomatch';

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.areEqual(1, result.rows.size(), 'Text past the 200-character bound must be ignored.');
    }

    @IsTest
    static void clampsRequestsBelowTheRetentionFloor() {
        // Asking for two years back must not cause a scan of data that cannot exist.
        AuditQueryService.provider = new MockAuditTrailProvider(new List<AuditEventRow>());
        AuditFilter filter = new AuditFilter();
        filter.startDateMillis = Datetime.now().addDays(-730).getTime();
        filter.endDateMillis = Datetime.now().getTime();

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.isTrue(result.done, 'Empty range completes immediately.');
        Datetime floorDate = Datetime.newInstance(result.scannedThroughMillis);
        Assert.isTrue(
            floorDate > Datetime.now().addDays(-(AuditQueryService.RETENTION_DAYS + 1)),
            'Scan must stop at the 180-day retention floor, not the requested start date.'
        );
        Assert.areEqual(
            result.scannedThroughMillis,
            result.cursor.rangeStartMillis,
            'The pinned range start must be the clamped floor.'
        );
    }

    @IsTest
    static void buildsFacetsSortedByCountDescending() {
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < 3; i++) {
            rows.add(MockAuditTrailProvider.row(i + 1, BASE.addMinutes(-i), 'Manage Users', 'a', 'x'));
        }
        rows.add(MockAuditTrailProvider.row(4, BASE.addMinutes(-4), 'Apex Class', 'b', 'y'));
        AuditQueryService.provider = new MockAuditTrailProvider(rows);

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(wideOpenFilter(), null, 50);
        Test.stopTest();

        Assert.areEqual(2, result.sectionFacets.size());
        Assert.areEqual('Manage Users', result.sectionFacets[0].label, 'Largest facet first.');
        Assert.areEqual(3, result.sectionFacets[0].count);
        Assert.areEqual('Apex Class', result.sectionFacets[1].label);
    }

    @IsTest
    static void reportsObservedValuesForFilterDiscovery() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(6));

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(wideOpenFilter(), null, 50);
        Test.stopTest();

        Assert.areEqual(
            new List<String>{ 'Apex Class', 'Manage Users' },
            result.observedSections,
            'Observed sections populate the filter dropdown.'
        );
    }

    @IsTest
    static void emptyResultIsDoneNotStuck() {
        AuditQueryService.provider = new MockAuditTrailProvider(new List<AuditEventRow>());

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(wideOpenFilter(), null, 50);
        Test.stopTest();

        Assert.areEqual(0, result.rows.size());
        Assert.isTrue(result.done, 'No data means the search is complete.');
    }

    @IsTest
    static void nullFilterUsesSafeDefaults() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(3));

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(null, null, null);
        Test.stopTest();

        Assert.isTrue(result.done, 'Defaults should still complete.');
        Assert.areEqual(3, result.rows.size(), 'Defaults cover the whole retention window.');
    }

    @IsTest
    static void malformedContinuationCursorIsRejected() {
        // The cursor round-trips through the browser, so it is untrusted input.
        // A cursor that claims a position without a well-formed id must be
        // refused before any query runs.
        MockAuditTrailProvider mock = new MockAuditTrailProvider(descendingRows(3));
        AuditQueryService.provider = mock;
        AuditCursor cursor = new AuditCursor();
        cursor.lastDateMillis = BASE.getTime();
        cursor.lastId = 'not-an-id';

        Test.startTest();
        try {
            AuditQueryService.search(wideOpenFilter(), cursor, 10);
            Assert.fail('A continuation cursor with a malformed id must be rejected.');
        } catch (IllegalArgumentException e) {
            Assert.areEqual('Malformed cursor', e.getMessage());
        }
        Test.stopTest();

        Assert.areEqual(0, mock.fetchCount, 'No query may run for a malformed cursor.');
    }

    @IsTest
    static void blankIdOnPositionedCursorIsRejected() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(3));
        AuditCursor cursor = new AuditCursor();
        cursor.lastDateMillis = BASE.getTime();
        cursor.lastId = '';

        Test.startTest();
        try {
            AuditQueryService.search(wideOpenFilter(), cursor, 10);
            Assert.fail('A positioned cursor without an id must be rejected.');
        } catch (IllegalArgumentException e) {
            Assert.areEqual('Malformed cursor', e.getMessage());
        }
        Test.stopTest();
    }

    @IsTest
    static void multiBatchScanFindsAMatchInTheLastShortBatch() {
        // 250 rows at distinct timestamps; only the oldest matches. With a batch
        // of 100 the scan needs three fetches, the last of them short, and must
        // report the whole range as done.
        useSmallBatches();
        List<AuditEventRow> rows = rowsInSection(250, 'Manage Users');
        rows[249].section = 'Apex Class';
        MockAuditTrailProvider mock = new MockAuditTrailProvider(rows);
        AuditQueryService.provider = mock;

        AuditFilter filter = wideOpenFilter();
        filter.sections = new List<String>{ 'Apex Class' };

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.isTrue(result.done, 'The short third batch exhausts the range.');
        Assert.areEqual(3, mock.fetchCount, 'Three batches of 100 cover 250 rows.');
        Assert.areEqual(1, result.rows.size(), 'Only the oldest row matches.');
        Assert.areEqual(MockAuditTrailProvider.fakeId(250), result.rows[0].recordId);
        Assert.areEqual(250, result.scannedCount, 'Every row must be scanned.');
    }

    @IsTest
    static void sameTimestampRowsPageByIdAcrossBatches() {
        // 250 rows in one second, batches of 100, pages of 40: the cursor must
        // advance by Id within the timestamp across both batch and page
        // boundaries, returning every row exactly once.
        useSmallBatches();
        AuditQueryService.provider = new MockAuditTrailProvider(rowsAtOneTimestamp(250));

        Set<String> collected = new Set<String>();
        Integer totalReturned = 0;
        AuditCursor cursor = null;
        Integer guard = 0;
        Boolean finished = false;

        Test.startTest();
        while (guard++ < 20) {
            AuditSearchResult page = AuditQueryService.search(wideOpenFilter(), cursor, 40);
            for (AuditEventRow row : page.rows) {
                collected.add(row.recordId);
                totalReturned++;
            }
            cursor = page.cursor;
            if (page.done) {
                finished = true;
                break;
            }
        }
        Test.stopTest();

        Assert.isTrue(finished, 'Paging must terminate with done == true.');
        Assert.areEqual(250, totalReturned, 'Every same-timestamp row must be returned.');
        Assert.areEqual(250, collected.size(), 'No same-timestamp row may be returned twice.');
    }

    @IsTest
    static void ceilingStopsACallWithoutLosingProgress() {
        // 350 non-matching rows, batches of 100, at most 3 batches per call:
        // the first call must stop at 300 scanned rows with the cursor
        // positioned, and the second must finish the remaining 50.
        useSmallBatches();
        MockAuditTrailProvider mock = new MockAuditTrailProvider(rowsInSection(350, 'Manage Users'));
        AuditQueryService.provider = mock;

        AuditFilter filter = wideOpenFilter();
        filter.sections = new List<String>{ 'Apex Class' };

        Test.startTest();
        AuditSearchResult first = AuditQueryService.search(filter, null, 50);
        Integer fetchesInFirstCall = mock.fetchCount;
        // In production the cursor round-trips through JSON, so each call gets
        // its own copy. Here the same object is handed straight back and the
        // second call advances it in place, so its position is captured now.
        Long positionAfterFirstCall = first.cursor.lastDateMillis;
        String idAfterFirstCall = first.cursor.lastId;
        AuditSearchResult second = AuditQueryService.search(filter, first.cursor, 50);
        Test.stopTest();

        Assert.areEqual(0, first.rows.size(), 'Nothing matches.');
        Assert.isFalse(first.done, 'The ceiling stops the call before the range is exhausted.');
        Assert.areEqual(300, first.scannedCount, 'Three batches of 100 are scanned.');
        Assert.areEqual(3, fetchesInFirstCall, 'The ceiling caps the fetches per call.');
        Assert.areEqual(
            BASE.addMinutes(-299).getTime(),
            positionAfterFirstCall,
            'The cursor must sit on the last scanned row.'
        );
        Assert.areEqual(MockAuditTrailProvider.fakeId(300), Id.valueOf(idAfterFirstCall));
        Assert.areEqual(
            BASE.addMinutes(-299).getTime(),
            first.scannedThroughMillis,
            'An unfinished call reports the oldest row it examined.'
        );

        Assert.areEqual(0, second.rows.size(), 'Still nothing matches.');
        Assert.isTrue(second.done, 'The second call exhausts the range.');
        Assert.areEqual(50, second.scannedCount, 'Only the remaining rows are scanned.');
        Assert.areEqual(4, mock.fetchCount, 'The second call needs a single short batch.');
    }

    @IsTest
    static void lastDaysUsesServerClockAndPinsRange() {
        // The preset range is derived from the server clock; the explicit dates
        // are deliberately wrong (a window 50-100 days ago, which holds none of
        // the rows) to prove they are ignored when lastDays is set.
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(25));
        AuditFilter filter = new AuditFilter();
        filter.lastDays = 7;
        filter.startDateMillis = BASE.addDays(-100).getTime();
        filter.endDateMillis = BASE.addDays(-50).getTime();

        // A different filter on the continuation call: the pinned range must win.
        AuditFilter tampered = new AuditFilter();
        tampered.lastDays = 1;

        Test.startTest();
        Long before = Datetime.now().getTime();
        AuditSearchResult first = AuditQueryService.search(filter, null, 10);
        Long after = Datetime.now().getTime();
        // Round-trip the cursor through JSON as the browser does, so the second
        // call works on its own copy and the drift assertions below compare two
        // distinct objects rather than one object with itself.
        AuditCursor roundTripped = (AuditCursor) JSON.deserialize(JSON.serialize(first.cursor), AuditCursor.class);
        AuditSearchResult second = AuditQueryService.search(tampered, roundTripped, 10);
        Test.stopTest();

        Assert.areEqual(10, first.rows.size(), 'Rows five days old fall inside the last seven days.');
        Assert.isTrue(
            first.cursor.rangeEndMillis >= before && first.cursor.rangeEndMillis <= after,
            'The range end must be the server clock at the time of the first call.'
        );
        Assert.areEqual(
            Datetime.newInstance(first.cursor.rangeEndMillis).addDays(-7).getTime(),
            first.cursor.rangeStartMillis,
            'The range start must be exactly lastDays before the range end.'
        );
        Long sevenDaysMillis = 7L * 24 * 60 * 60 * 1000;
        Assert.isTrue(
            Math.abs((first.cursor.rangeEndMillis - first.cursor.rangeStartMillis) - sevenDaysMillis) <= 60 * 60 * 1000,
            'The window must span seven days, allowing for a DST shift.'
        );

        Assert.areEqual(10, second.rows.size(), 'The continuation pages over the pinned range, not the new filter.');
        Assert.areEqual(first.cursor.rangeStartMillis, second.cursor.rangeStartMillis, 'Range start must not drift.');
        Assert.areEqual(first.cursor.rangeEndMillis, second.cursor.rangeEndMillis, 'Range end must not drift.');
    }

    @IsTest
    static void lastDaysZeroMeansExplicitDatesApply() {
        // Contract C1: only a POSITIVE lastDays switches to the server-clock
        // preset. A client may send 0 for a blank or unknown preset; that must
        // not become a zero-width or retention-wide window.
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(3));
        AuditFilter filter = explicitRangeWithLastDays(0);

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 10);
        Test.stopTest();

        assertExplicitRangeWasPinned(filter, result);
    }

    @IsTest
    static void negativeLastDaysMeansExplicitDatesApply() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(3));
        AuditFilter filter = explicitRangeWithLastDays(-5);

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 10);
        Test.stopTest();

        assertExplicitRangeWasPinned(filter, result);
    }

    @IsTest
    static void continuationCursorMissingRangeFallsBackToTheFilter() {
        // Contract C2 fallback: a continuation cursor that lacks either pinned
        // bound (older client, hand-built payload) must recompute the range
        // from the filter and pin it again, while still resuming from the
        // keyset position it carries.
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(25));
        AuditFilter filter = wideOpenFilter();

        Test.startTest();
        AuditSearchResult first = AuditQueryService.search(filter, null, 10);
        // A copy, as the browser round trip would produce, with the range removed.
        AuditCursor stripped = (AuditCursor) JSON.deserialize(JSON.serialize(first.cursor), AuditCursor.class);
        stripped.rangeStartMillis = null;
        stripped.rangeEndMillis = null;
        AuditSearchResult second = AuditQueryService.search(filter, stripped, 10);
        Test.stopTest();

        Assert.areEqual(10, first.rows.size(), 'The first page is full.');
        Assert.areEqual(10, second.rows.size(), 'The continuation must still fill a page.');
        Assert.areEqual(
            String.valueOf(MockAuditTrailProvider.fakeId(11)),
            second.rows[0].recordId,
            'The continuation must resume from the keyset position, not restart.'
        );
        Assert.isFalse(second.done, 'Five rows remain after the second page.');
        Assert.areEqual(
            filter.startDateMillis,
            second.cursor.rangeStartMillis,
            'The range start must be recomputed from the filter and pinned again.'
        );
        Assert.areEqual(
            filter.endDateMillis,
            second.cursor.rangeEndMillis,
            'The range end must be recomputed from the filter and pinned again.'
        );
    }

    @IsTest
    static void lastDaysIsCappedAtTheRetentionWindow() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(3));
        AuditFilter filter = new AuditFilter();
        filter.lastDays = 3650;

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 10);
        Test.stopTest();

        Assert.areEqual(
            Datetime.newInstance(result.cursor.rangeEndMillis).addDays(-AuditQueryService.RETENTION_DAYS).getTime(),
            result.cursor.rangeStartMillis,
            'A preset longer than retention must be capped at the retention window.'
        );
        Assert.areEqual(3, result.rows.size());
    }

    @IsTest
    static void exhaustedScanReportsRangeBoundary() {
        // Rows exist only before the lower bound, so the first fetch is empty.
        // "Searched back to" must report the range boundary, not the oldest row
        // that happened to be examined (there was none).
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < 3; i++) {
            rows.add(
                MockAuditTrailProvider.row(i + 1, BASE.addDays(-20).addMinutes(-i), 'Apex Class', 'a', 'old ' + i)
            );
        }
        AuditQueryService.provider = new MockAuditTrailProvider(rows);
        AuditFilter filter = wideOpenFilter();

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 10);
        Test.stopTest();

        Assert.isTrue(result.done, 'An empty fetch exhausts the range.');
        Assert.areEqual(0, result.rows.size());
        Assert.areEqual(filter.startDateMillis, result.scannedThroughMillis, 'Must report the lower bound used.');
        Assert.areEqual(filter.startDateMillis, result.cursor.rangeStartMillis, 'The lower bound is the pinned start.');
    }

    @IsTest
    static void exhaustedScanWithRowsReportsRangeBoundaryNotOldestRow() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(5));
        AuditFilter filter = wideOpenFilter();

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        Assert.isTrue(result.done, 'Five rows in one short batch exhaust the range.');
        Assert.areEqual(5, result.rows.size());
        Assert.areEqual(
            filter.startDateMillis,
            result.scannedThroughMillis,
            'Once exhausted, the whole window down to the lower bound was covered.'
        );
        Assert.areNotEqual(
            BASE.addMinutes(-4).getTime(),
            result.scannedThroughMillis,
            'The oldest examined row is not the boundary once the range is exhausted.'
        );
    }

    @IsTest
    static void cursorIdOfAnotherObjectIsRejected() {
        // A well-formed Id of the wrong object (here the running user's) must
        // not be accepted as a keyset position on SetupAuditTrail.
        MockAuditTrailProvider mock = new MockAuditTrailProvider(descendingRows(3));
        AuditQueryService.provider = mock;
        AuditCursor cursor = new AuditCursor();
        cursor.lastDateMillis = BASE.getTime();
        cursor.lastId = UserInfo.getUserId();

        Test.startTest();
        try {
            AuditQueryService.search(wideOpenFilter(), cursor, 10);
            Assert.fail('A cursor whose id belongs to another object must be rejected.');
        } catch (IllegalArgumentException e) {
            Assert.areEqual('Malformed cursor', e.getMessage());
        }
        Test.stopTest();

        Assert.areEqual(0, mock.fetchCount, 'No query may run for a rejected cursor.');
    }

    @IsTest
    static void continuationBoundsAreReclampedFromAnUntrustedCursor() {
        // A client could edit the pinned bounds. A start below the retention
        // floor is clamped back to the floor and a position above the range end
        // is clamped to the end, so a tampered cursor cannot widen the scan.
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(5));
        AuditFilter filter = wideOpenFilter();
        AuditSearchResult first = AuditQueryService.search(filter, null, 2);

        AuditCursor tampered = (AuditCursor) JSON.deserialize(JSON.serialize(first.cursor), AuditCursor.class);
        tampered.rangeStartMillis = Datetime.now().addDays(-400).getTime();
        tampered.lastDateMillis = tampered.rangeEndMillis + 86400000L;

        Test.startTest();
        AuditSearchResult second = AuditQueryService.search(filter, tampered, 50);
        Test.stopTest();

        Assert.isTrue(second.done, 'The rows fit in one short batch, so the range is exhausted.');
        Assert.isTrue(
            Datetime.newInstance(second.scannedThroughMillis) >=
            Datetime.now().addDays(-(AuditQueryService.RETENTION_DAYS + 1)),
            'The lower bound must be clamped to the retention floor, not the tampered start.'
        );
        Assert.areEqual(
            tampered.rangeStartMillis,
            second.cursor.rangeStartMillis,
            'Clamping applies to the scan, not to the pinned value the client sent back.'
        );
    }
}
