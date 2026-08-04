@IsTest
private class SetupAuditTrailProviderTest {
    /**
     * Runs the real SOQL against SetupAuditTrail. Test context returns no rows,
     * but the query still executes - so this fails loudly in any org where the
     * query shape is invalid, which makes installation self-validating.
     */
    @IsTest
    static void realQueryExecutesInThisOrg() {
        SetupAuditTrailProvider provider = new SetupAuditTrailProvider();

        Test.startTest();
        List<AuditEventRow> rows = provider.fetch(
            Datetime.now(),
            Datetime.now().addDays(-30),
            null,
            null,
            null,
            10
        );
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Query must execute without error');
    }

    /** The optional predicates change the SOQL string, so each must be valid too. */
    @IsTest
    static void realQueryExecutesWithEveryOptionalFilter() {
        SetupAuditTrailProvider provider = new SetupAuditTrailProvider();

        Test.startTest();
        List<AuditEventRow> rows = provider.fetch(
            Datetime.now(),
            Datetime.now().addDays(-30),
            new List<String>{ 'changedpassword' },
            new List<String>{ UserInfo.getUserId() },
            new Set<Id>{ UserInfo.getUserId() },
            10
        );
        Test.stopTest();

        System.assertNotEquals(null, rows, 'Filtered query must also be valid');
    }

    @IsTest
    static void mapsAllFieldsFromSetupAuditTrail() {
        // SetupAuditTrail cannot be inserted, so build one by deserialization.
        SetupAuditTrail record = buildRecord('Jane Admin');

        Test.startTest();
        AuditEventRow row = new AuditEventRow(record);
        Test.stopTest();

        System.assertEquals('Manage Users', row.section);
        System.assertEquals('PermSetAssign', row.action);
        System.assertEquals('Assigned permission set', row.display);
        System.assertEquals('Jane Admin', row.userName);
        System.assertEquals('delegate@example.com', row.delegateUser);
        System.assertEquals('acme', row.namespacePrefix);
        System.assertNotEquals(null, row.eventDateMillis, 'Date must convert to epoch millis');
        System.assertEquals(row.eventDateMillis, row.eventDate().getTime(), 'Round trip must be lossless');
    }

    @IsTest
    static void toleratesMissingCreatedByRelationship() {
        SetupAuditTrail record = buildRecord(null);

        Test.startTest();
        AuditEventRow row = new AuditEventRow(record);
        Test.stopTest();

        System.assertEquals(null, row.userName, 'A missing CreatedBy must not throw');
    }

    private static SetupAuditTrail buildRecord(String userName) {
        Map<String, Object> raw = new Map<String, Object>{
            'attributes' => new Map<String, Object>{ 'type' => 'SetupAuditTrail' },
            'Id' => MockAuditTrailProvider.fakeId(1),
            'CreatedDate' => '2026-01-01T10:00:00.000+0000',
            'Section' => 'Manage Users',
            'Action' => 'PermSetAssign',
            'Display' => 'Assigned permission set',
            'CreatedById' => UserInfo.getUserId(),
            'DelegateUser' => 'delegate@example.com',
            'ResponsibleNamespacePrefix' => 'acme',
            'CreatedByContext' => 'Setup',
            'CreatedByIssuer' => 'issuer'
        };
        if (userName != null) {
            raw.put(
                'CreatedBy',
                new Map<String, Object>{
                    'attributes' => new Map<String, Object>{ 'type' => 'User' },
                    'Name' => userName
                }
            );
        }
        return (SetupAuditTrail) JSON.deserialize(JSON.serialize(raw), SetupAuditTrail.class);
    }
}
