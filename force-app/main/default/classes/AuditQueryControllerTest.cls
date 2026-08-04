@IsTest
private class AuditQueryControllerTest {
    @IsTest
    static void searchReturnsRowsForPermittedUser() {
        AuditQueryService.provider = new MockAuditTrailProvider(
            new List<AuditEventRow>{
                MockAuditTrailProvider.row(1, Datetime.now().addDays(-1), 'Manage Users', 'deactivate', 'Deactivated user Jane')
            }
        );

        AuditFilter filter = new AuditFilter();
        filter.startDateMillis = Datetime.now().addDays(-30).getTime();
        filter.endDateMillis = Datetime.now().getTime();

        Test.startTest();
        AuditSearchResult result = AuditQueryController.search(JSON.serialize(filter), null, 10);
        Test.stopTest();

        System.assertEquals(1, result.rows.size());
    }

    @IsTest
    static void searchRoundTripsCursorJson() {
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (Integer i = 0; i < 6; i++) {
            rows.add(MockAuditTrailProvider.row(i + 1, Datetime.now().addMinutes(-i), 'Apex Class', 'a', 'row ' + i));
        }
        AuditQueryService.provider = new MockAuditTrailProvider(rows);

        AuditFilter filter = new AuditFilter();
        filter.startDateMillis = Datetime.now().addDays(-30).getTime();
        filter.endDateMillis = Datetime.now().addMinutes(1).getTime();

        Test.startTest();
        AuditSearchResult first = AuditQueryController.search(JSON.serialize(filter), null, 3);
        AuditSearchResult second = AuditQueryController.search(
            JSON.serialize(filter),
            JSON.serialize(first.cursor),
            3
        );
        Test.stopTest();

        System.assertEquals(3, first.rows.size());
        System.assertEquals(3, second.rows.size());
        System.assertNotEquals(
            first.rows[0].recordId,
            second.rows[0].recordId,
            'Cursor must advance across serialized calls'
        );
    }

    @IsTest
    static void searchHidesInternalErrorDetail() {
        // A malformed cursor triggers a deserialization failure inside the
        // controller. The client must get the generic message rather than the
        // platform's exception text, which can carry query and limit internals.
        Test.startTest();
        try {
            AuditQueryController.search(null, '{"lastDateMillis":"not-a-number"}', 10);
            Assert.fail('Expected the malformed cursor to fail.');
        } catch (AuraHandledException e) {
            Assert.isTrue(
                e.getMessage().contains('could not be completed'),
                'Expected the generic message, got: ' + e.getMessage()
            );
            Assert.isFalse(
                e.getMessage().containsIgnoreCase('SELECT') ||
                e.getMessage().containsIgnoreCase('SetupAuditTrail'),
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

        System.assertEquals(180, context.get('retentionDays'), 'Retention window drives the date pickers');
        System.assertNotEquals(null, context.get('retentionFloorMillis'));
        System.assertNotEquals(null, context.get('canViewSetup'));
    }

    @IsTest
    static void searchUsersIgnoresShortTerms() {
        Test.startTest();
        List<Map<String, String>> results = AuditQueryController.searchUsers('a');
        Test.stopTest();

        System.assertEquals(0, results.size(), 'Single characters should not trigger a query');
    }

    @IsTest
    static void searchUsersFindsActiveUsers() {
        String name = UserInfo.getLastName();

        Test.startTest();
        List<Map<String, String>> results = AuditQueryController.searchUsers(name);
        Test.stopTest();

        System.assert(results.size() > 0, 'Should find the running user by name');
    }

    @IsTest
    static void permissionCheckRunsRealQuery() {
        Test.startTest();
        Boolean canView = AuditPermissionService.canViewSetup();
        Test.stopTest();

        System.assertNotEquals(null, canView, 'Permission check must resolve to a boolean');
    }
}
