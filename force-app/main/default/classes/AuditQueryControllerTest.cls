@IsTest
private class AuditQueryControllerTest {
    /**
     * A last name no real user carries, so user searches are deterministic. It
     * starts with "Aa" so it sorts first under ORDER BY Name: if a wildcard
     * were ever left unescaped and matched every user, this user would still be
     * inside the 20-row LIMIT and the wildcard tests below would fail honestly.
     */
    private static final String DISTINCTIVE_LAST_NAME = 'Aazyxwvutsrq';

    private static User insertDistinctiveUser() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Minimum Access - Salesforce' LIMIT 1];
        User u = new User(
            ProfileId = p.Id,
            LastName = DISTINCTIVE_LAST_NAME,
            Email = 'audit.lookup@example.com',
            Username = 'audit.lookup.' + Datetime.now().getTime() + '@example.com.invalid',
            Alias = 'alookup',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
        insert u;
        return u;
    }

    private static String lastSevenDaysFilter() {
        AuditFilter filter = new AuditFilter();
        filter.lastDays = 7;
        return JSON.serialize(filter);
    }

    private static List<AuditEventRow> recentRows(Integer count) {
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < count; i++) {
            rows.add(MockAuditTrailProvider.row(i + 1, Datetime.now().addMinutes(-i), 'Apex Class', 'a', 'row ' + i));
        }
        return rows;
    }

    @IsTest
    static void searchReturnsRowsForPermittedUser() {
        AuditQueryService.provider = new MockAuditTrailProvider(
            new List<AuditEventRow>{
                MockAuditTrailProvider.row(
                    1,
                    Datetime.now().addDays(-1),
                    'Manage Users',
                    'deactivate',
                    'Deactivated user Jane'
                )
            }
        );

        AuditFilter filter = new AuditFilter();
        filter.startDateMillis = Datetime.now().addDays(-30).getTime();
        filter.endDateMillis = Datetime.now().getTime();

        Test.startTest();
        AuditSearchResult result = AuditQueryController.search(JSON.serialize(filter), null, 10);
        Test.stopTest();

        Assert.areEqual(1, result.rows.size(), 'The mock row inside the range must be returned.');
    }

    @IsTest
    static void searchRoundTripsCursorJson() {
        AuditQueryService.provider = new MockAuditTrailProvider(recentRows(6));

        AuditFilter filter = new AuditFilter();
        filter.startDateMillis = Datetime.now().addDays(-30).getTime();
        filter.endDateMillis = Datetime.now().addMinutes(1).getTime();

        Test.startTest();
        AuditSearchResult first = AuditQueryController.search(JSON.serialize(filter), null, 3);
        AuditSearchResult second = AuditQueryController.search(JSON.serialize(filter), JSON.serialize(first.cursor), 3);
        Test.stopTest();

        Assert.areEqual(3, first.rows.size(), 'First page must be full.');
        Assert.areEqual(3, second.rows.size(), 'Second page must be full.');
        Assert.areNotEqual(
            first.rows[0].recordId,
            second.rows[0].recordId,
            'Cursor must advance across serialized calls.'
        );
        Assert.isTrue(first.cursor.lastId instanceof Id, 'The keyset id must be a well-formed Id.');
        Assert.isNotNull(first.cursor.rangeStartMillis, 'The first call must pin the range start.');
        Assert.isNotNull(first.cursor.rangeEndMillis, 'The first call must pin the range end.');
        Assert.areEqual(
            first.cursor.rangeStartMillis,
            second.cursor.rangeStartMillis,
            'The pinned range start must survive the JSON round trip unchanged.'
        );
        Assert.areEqual(
            first.cursor.rangeEndMillis,
            second.cursor.rangeEndMillis,
            'The pinned range end must survive the JSON round trip unchanged.'
        );
    }

    @IsTest
    static void searchHidesInternalErrorDetail() {
        // A continuation cursor whose id is not well formed is rejected inside
        // the service. The client must get the generic message rather than the
        // exception text, which could carry query and limit internals.
        Test.startTest();
        try {
            // A complete continuation cursor (position and pinned bounds) whose
            // id is not well formed; a cursor without bounds would simply be
            // treated as a fresh search.
            AuditQueryController.search(
                null,
                '{"lastDateMillis": 1700000000000, "lastId": "not-an-id", ' +
                '"rangeStartMillis": 1690000000000, "rangeEndMillis": 1700000000000}',
                10
            );
            Assert.fail('Expected the malformed cursor to fail.');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('could not be completed'),
                'Expected the generic message, got: ' + e.getMessage()
            );
            Assert.isFalse(
                e.getMessage().containsIgnoreCase('Malformed') ||
                    e.getMessage().containsIgnoreCase('SELECT') ||
                    e.getMessage().containsIgnoreCase('SetupAuditTrail'),
                'Internal detail must not reach the client: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void searchHidesDeserializationFailureDetail() {
        // A cursor that does not even deserialize fails inside the controller
        // itself, before the service runs; it must be masked the same way.
        Test.startTest();
        try {
            AuditQueryController.search(null, '{"lastDateMillis":"not-a-number"}', 10);
            Assert.fail('Expected the undeserializable cursor to fail.');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('could not be completed'),
                'Expected the generic message, got: ' + e.getMessage()
            );
            Assert.isFalse(
                e.getMessage().containsIgnoreCase('JSON') || e.getMessage().containsIgnoreCase('lastDateMillis'),
                'Internal detail must not reach the client: ' + e.getMessage()
            );
        }
        Test.stopTest();
    }

    @IsTest
    static void contextExposesRetentionWindow() {
        Test.startTest();
        Map<String, Object> context = AuditQueryController.getContext();
        Test.stopTest();

        Assert.areEqual(180, context.get('retentionDays'), 'Retention window drives the date pickers.');
        Assert.isNotNull(context.get('retentionFloorMillis'), 'The retention floor must be reported.');
        Assert.isNotNull(context.get('nowMillis'), 'The server clock must be reported.');
        Assert.areEqual(true, context.get('canViewSetup'), 'The running administrator must be reported as permitted.');
        Assert.areEqual(AuditQueryService.DEFAULT_PAGE_SIZE, context.get('defaultPageSize'));
    }

    @IsTest
    static void searchUsersIgnoresShortTerms() {
        Test.startTest();
        List<Map<String, String>> results = AuditQueryController.searchUsers('a');
        Test.stopTest();

        Assert.areEqual(0, results.size(), 'Single characters should not trigger a query.');
    }

    @IsTest
    static void searchUsersFindsActiveUsers() {
        User target = insertDistinctiveUser();

        Test.startTest();
        List<Map<String, String>> results = AuditQueryController.searchUsers(DISTINCTIVE_LAST_NAME);
        Test.stopTest();

        Assert.isFalse(results.isEmpty(), 'Should find the inserted user by name.');
        Boolean found = false;
        for (Map<String, String> result : results) {
            if (result.get('id') == String.valueOf(target.Id)) {
                found = true;
            }
        }
        Assert.isTrue(found, 'The result list must contain the inserted user.');
    }

    @IsTest
    static void searchUsersTreatsPercentAsLiteral() {
        // Without escaping, "%%" would be LIKE '%%%%' and match every user.
        insertDistinctiveUser();

        Test.startTest();
        List<Map<String, String>> results = AuditQueryController.searchUsers('%%');
        Test.stopTest();

        Assert.isTrue(
            results.isEmpty(),
            'A percent sign must match only a literal percent sign, got ' + results.size() + ' result(s).'
        );
    }

    @IsTest
    static void searchUsersTreatsUnderscoreAsLiteral() {
        // Without escaping, "__" would match any two characters, i.e. everyone,
        // including the inserted user. An escaped "__" matches only names and
        // usernames that contain two literal underscores; the inserted user
        // ('Zyxwvutsrq' / 'audit.lookup.<ts>@example.com.invalid') has none,
        // so it must be absent. The result set is deliberately NOT asserted to
        // be empty: a real org may legitimately have an active user with an
        // underscore in its name, which would be a false failure.
        User target = insertDistinctiveUser();

        Test.startTest();
        List<Map<String, String>> results = AuditQueryController.searchUsers('__');
        Test.stopTest();

        for (Map<String, String> result : results) {
            Assert.areNotEqual(
                String.valueOf(target.Id),
                result.get('id'),
                'An underscore must match only a literal underscore; the inserted user has none and must not match.'
            );
        }
    }

    @IsTest
    static void searchUsersTreatsEscapedPercentAsLiteral() {
        // A backslash followed by a percent sign: the escape character itself
        // must be escaped first, or the user-supplied backslash would neutralise
        // the escaping of the percent sign and turn it back into a wildcard.
        insertDistinctiveUser();

        Test.startTest();
        List<Map<String, String>> results = AuditQueryController.searchUsers('\\%');
        Test.stopTest();

        Assert.isTrue(
            results.isEmpty(),
            'A backslash-percent must match only that literal text, got ' + results.size() + ' result(s).'
        );
    }

    @IsTest
    static void pageSizeIsClampedToTheMaximumAndDefaulted() {
        AuditQueryService.provider = new MockAuditTrailProvider(recentRows(250));
        String filterJson = lastSevenDaysFilter();

        Test.startTest();
        AuditSearchResult oversized = AuditQueryController.search(filterJson, null, 999);
        AuditSearchResult nullSize = AuditQueryController.search(filterJson, null, null);
        AuditSearchResult zeroSize = AuditQueryController.search(filterJson, null, 0);
        Test.stopTest();

        Assert.isTrue(oversized.rows.size() <= 200, 'A page can never exceed the maximum page size.');
        Assert.areEqual(200, oversized.rows.size(), 'An oversized request is clamped to the maximum, not rejected.');
        Assert.areEqual(
            AuditQueryService.DEFAULT_PAGE_SIZE,
            nullSize.rows.size(),
            'A null page size falls back to the default.'
        );
        Assert.areEqual(
            AuditQueryService.DEFAULT_PAGE_SIZE,
            zeroSize.rows.size(),
            'A zero page size falls back to the default.'
        );
    }
}
