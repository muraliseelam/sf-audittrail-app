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

    private static AuditFilter wideOpenFilter() {
        AuditFilter f = new AuditFilter();
        f.startDateMillis = BASE.addDays(-10).getTime();
        f.endDateMillis = BASE.addDays(1).getTime();
        return f;
    }

    @IsTest
    static void returnsFirstPageAndReportsNotDone() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(25));

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(wideOpenFilter(), null, 10);
        Test.stopTest();

        System.assertEquals(10, result.rows.size(), 'Should fill the requested page size');
        System.assertEquals(false, result.done, 'More rows remain, so the search is not done');
        System.assertNotEquals(null, result.cursor.lastDateMillis, 'Cursor must be positioned');
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

        System.assertEquals(25, totalReturned, 'Every row should be returned');
        System.assertEquals(25, collected.size(), 'No row should be returned twice');
    }

    @IsTest
    static void handlesManyRowsSharingOneTimestamp() {
        // A single metadata deployment writes many audit rows in the same second.
        // Date-only keyset paging would skip or duplicate these.
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < 12; i++) {
            rows.add(MockAuditTrailProvider.row(i + 1, BASE, 'Apex Class', 'changedApexClass', 'Deployed class ' + i));
        }
        AuditQueryService.provider = new MockAuditTrailProvider(rows);

        Set<String> collected = new Set<String>();
        AuditCursor cursor = null;
        Integer guard = 0;

        Test.startTest();
        while (guard++ < 20) {
            AuditSearchResult page = AuditQueryService.search(wideOpenFilter(), cursor, 5);
            for (AuditEventRow row : page.rows) {
                collected.add(row.recordId);
            }
            cursor = page.cursor;
            if (page.done) {
                break;
            }
        }
        Test.stopTest();

        System.assertEquals(12, collected.size(), 'All same-timestamp rows must be returned exactly once');
    }

    @IsTest
    static void filtersOnSectionWhichSoqlCannotDo() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(20));
        AuditFilter filter = wideOpenFilter();
        filter.sections = new List<String>{ 'Apex Class' };

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        System.assertEquals(10, result.rows.size(), 'Only Apex Class rows should match');
        for (AuditEventRow row : result.rows) {
            System.assertEquals('Apex Class', row.section, 'Section filter must be applied');
        }
        System.assertEquals(20, result.scannedCount, 'Non-matching rows are still scanned');
    }

    @IsTest
    static void searchTextRequiresAllTerms() {
        List<AuditEventRow> rows = new List<AuditEventRow>{
            MockAuditTrailProvider.row(1, BASE, 'Manage Users', 'permsetAssign', 'Assigned permission set Admin to Jane'),
            MockAuditTrailProvider.row(2, BASE.addMinutes(-1), 'Manage Users', 'permsetAssign', 'Assigned permission set Admin to Bob'),
            MockAuditTrailProvider.row(3, BASE.addMinutes(-2), 'Manage Users', 'deactivate', 'Deactivated user Jane')
        };
        AuditQueryService.provider = new MockAuditTrailProvider(rows);

        AuditFilter filter = wideOpenFilter();
        filter.searchText = 'permission jane';

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(filter, null, 50);
        Test.stopTest();

        System.assertEquals(1, result.rows.size(), 'Both terms must appear for a match');
        System.assertEquals(MockAuditTrailProvider.fakeId(1), result.rows[0].recordId);
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

        System.assertEquals(1, result.rows.size(), 'Search should ignore case');
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

        System.assertEquals(true, result.done, 'Empty range completes immediately');
        Datetime floorDate = Datetime.newInstance(result.scannedThroughMillis);
        System.assert(
            floorDate > Datetime.now().addDays(-(AuditQueryService.RETENTION_DAYS + 1)),
            'Scan must stop at the 180-day retention floor, not the requested start date'
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

        System.assertEquals(2, result.sectionFacets.size());
        System.assertEquals('Manage Users', result.sectionFacets[0].label, 'Largest facet first');
        System.assertEquals(3, result.sectionFacets[0].count);
        System.assertEquals('Apex Class', result.sectionFacets[1].label);
    }

    @IsTest
    static void reportsObservedValuesForFilterDiscovery() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(6));

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(wideOpenFilter(), null, 50);
        Test.stopTest();

        System.assertEquals(
            new List<String>{ 'Apex Class', 'Manage Users' },
            result.observedSections,
            'Observed sections populate the filter dropdown'
        );
    }

    @IsTest
    static void emptyResultIsDoneNotStuck() {
        AuditQueryService.provider = new MockAuditTrailProvider(new List<AuditEventRow>());

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(wideOpenFilter(), null, 50);
        Test.stopTest();

        System.assertEquals(0, result.rows.size());
        System.assertEquals(true, result.done, 'No data means the search is complete');
    }

    @IsTest
    static void nullFilterUsesSafeDefaults() {
        AuditQueryService.provider = new MockAuditTrailProvider(descendingRows(3));

        Test.startTest();
        AuditSearchResult result = AuditQueryService.search(null, null, null);
        Test.stopTest();

        System.assertEquals(true, result.done, 'Defaults should still complete');
    }
}
