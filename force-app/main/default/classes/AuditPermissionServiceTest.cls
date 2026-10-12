/**
 * Proves the access gate actually denies a user who lacks "View Setup and
 * Configuration", and opens for one who has it.
 *
 * This is the security control the whole app rests on, so it is tested against
 * real users on a real profile rather than a mocked flag. "Minimum Access -
 * Salesforce" is used because it is a stock profile that does not grant
 * ViewSetup, so the assertions stay meaningful in any org.
 */
@IsTest
private class AuditPermissionServiceTest {
    private static Integer userSequence = 0;

    private static User buildUser(String profileName) {
        return buildUser(profileName, 'Audit Gate');
    }

    private static User buildUser(String profileName, String lastName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        userSequence++;
        String stamp = String.valueOf(Datetime.now().getTime()) + '.' + userSequence;
        return new User(
            ProfileId = p.Id,
            LastName = lastName,
            Email = 'audit.gate@example.com',
            Username = 'audit.gate.' + stamp + '@example.com.invalid',
            Alias = ('ag' + userSequence).left(8),
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
    }

    /**
     * Namespace of the running code: null for a source deploy, the package
     * namespace once installed as a managed package. Needed so the PermissionSet
     * and ApexClass lookups below find the packaged copies and not a
     * same-named local one.
     */
    private static String packageNamespace() {
        String qualified = AuditPermissionServiceTest.class.getName();
        return qualified.contains('.') ? qualified.substringBefore('.') : null;
    }

    @IsTest
    static void deniesUserWithoutViewSetup() {
        User restricted = buildUser('Minimum Access - Salesforce');
        insert restricted;

        Test.startTest();
        System.runAs(restricted) {
            Assert.isFalse(
                AuditPermissionService.canViewSetup(),
                'A user without View Setup and Configuration must not pass the gate.'
            );

            try {
                AuditPermissionService.assertCanViewSetup();
                Assert.fail('assertCanViewSetup should have thrown for an unprivileged user.');
            } catch (AuditPermissionService.AuditPermissionException e) {
                Assert.isTrue(
                    e.getMessage().contains('View Setup and Configuration'),
                    'The error should name the permission the user is missing.'
                );
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void blocksControllerEntryPointsForUnprivilegedUser() {
        User restricted = buildUser('Minimum Access - Salesforce');
        insert restricted;

        Test.startTest();
        System.runAs(restricted) {
            // Both entry points that expose audit data must be gated, not just
            // the search - searchUsers would otherwise leak the org's user list.
            // Each must surface as an AuraHandledException whose message names
            // the missing permission: that proves setMessage() was called, as
            // the constructor argument alone reads "Script-thrown exception".
            try {
                AuditQueryController.search(null, null, 10);
                Assert.fail('search should be gated by the ViewSetup permission.');
            } catch (AuraHandledException e) {
                Assert.isTrue(
                    e.getMessage().contains('View Setup and Configuration'),
                    'search must tell the user which permission is missing, got: ' + e.getMessage()
                );
            }

            try {
                AuditQueryController.searchUsers('ab');
                Assert.fail('searchUsers should be gated by the ViewSetup permission.');
            } catch (AuraHandledException e) {
                Assert.isTrue(
                    e.getMessage().contains('View Setup and Configuration'),
                    'searchUsers must tell the user which permission is missing, got: ' + e.getMessage()
                );
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void restrictedUserGetContextReportsNoAccessWithoutThrowing() {
        // getContext is ungated by design: the UI needs it to decide whether to
        // show the search or the "ask your administrator" message, so for an
        // unprivileged user it must answer false rather than throw.
        User restricted = buildUser('Minimum Access - Salesforce');
        insert restricted;

        Test.startTest();
        System.runAs(restricted) {
            Map<String, Object> context = AuditQueryController.getContext();
            Assert.areEqual(false, context.get('canViewSetup'), 'An unprivileged user must be told they lack access.');
            Assert.areEqual(AuditQueryService.RETENTION_DAYS, context.get('retentionDays'));
        }
        Test.stopTest();
    }

    @IsTest
    static void allowsUserWithViewSetup() {
        // The running test user is an administrator, so the gate must open.
        Assert.isTrue(AuditPermissionService.canViewSetup(), 'An admin should pass the gate.');
        AuditPermissionService.assertCanViewSetup();
    }

    @IsTest
    static void restrictedUserWithLocalViewSetupPermissionSetCanUseEveryEntryPoint() {
        // The deterministic positive case: a Minimum Access user granted View
        // Setup through a permission set created in this org (which is exactly
        // what a managed-package subscriber's administrator has to do) must be
        // able to use every entry point. Unlike the shipped permission set,
        // this one is never stripped by packaging, so the assertions hold in
        // source, unlocked and managed contexts alike.
        //
        // The restricted user carries the distinctive last name itself: a user
        // can always read their own User record, so the searchUsers assertion
        // below does not depend on the org's User sharing default (an org with
        // User OWD = Private would hide any other user from a Minimum Access
        // user and fail the test for a reason unrelated to the code under test).
        User restricted = buildUser('Minimum Access - Salesforce', 'Zyxwvutsrq');
        insert restricted;

        PermissionSet local = new PermissionSet(
            Name = 'ATE_Test_View_Setup_' + Datetime.now().getTime(),
            Label = 'ATE Test View Setup',
            PermissionsViewSetup = true,
            PermissionsViewRoles = true
        );
        insert local;
        insert new PermissionSetAssignment(AssigneeId = restricted.Id, PermissionSetId = local.Id);

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
        filter.lastDays = 7;
        String filterJson = JSON.serialize(filter);

        Test.startTest();
        System.runAs(restricted) {
            Assert.isTrue(
                AuditPermissionService.canViewSetup(),
                'A local permission set carrying View Setup must open the gate.'
            );

            AuditSearchResult result = AuditQueryController.search(filterJson, null, 10);
            Assert.areEqual(1, result.rows.size(), 'search must return the mock row to a permitted user.');

            Map<String, Object> context = AuditQueryController.getContext();
            Assert.areEqual(true, context.get('canViewSetup'), 'getContext must report access for a permitted user.');

            List<Map<String, String>> users = AuditQueryController.searchUsers('Zyxwvutsrq');
            Assert.isFalse(users.isEmpty(), 'searchUsers must work for a permitted user.');
            Boolean foundSelf = false;
            for (Map<String, String> u : users) {
                if (u.get('id') == String.valueOf(restricted.Id)) {
                    foundSelf = true;
                }
            }
            Assert.isTrue(foundSelf, 'The permitted user must at least find their own record.');
        }
        Test.stopTest();
    }

    @IsTest
    static void packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup() {
        // A customer installs the package and assigns only the permission set
        // we ship. What that permission set can actually grant depends on the
        // packaging model: Salesforce strips system permissions such as
        // ViewSetup from a MANAGED package's permission set on install, as an
        // anti-privilege-escalation measure, but keeps them for source and
        // unlocked deploys.
        //
        // So the invariant worth pinning is the equivalence itself: the gate
        // must open exactly when the assigned permission set really carries
        // ViewSetup, and stay shut when the platform stripped it. Asserting
        // unconditionally that the permission set alone is sufficient would be
        // asserting something the managed platform forbids.
        User restricted = buildUser('Minimum Access - Salesforce');
        insert restricted;

        String ns = packageNamespace();
        PermissionSet ps = [
            SELECT Id, PermissionsViewSetup
            FROM PermissionSet
            WHERE Name = 'Audit_Trail_Viewer' AND IsOwnedByProfile = FALSE AND NamespacePrefix = :ns
            LIMIT 1
        ];
        insert new PermissionSetAssignment(AssigneeId = restricted.Id, PermissionSetId = ps.Id);

        Boolean grantsViewSetup = ps.PermissionsViewSetup;

        Test.startTest();
        System.runAs(restricted) {
            Assert.areEqual(
                grantsViewSetup,
                AuditPermissionService.canViewSetup(),
                'The gate must open exactly when the shipped permission set grants View Setup and Configuration.'
            );

            if (grantsViewSetup) {
                // The data path must genuinely open, not just the gate.
                AuditSearchResult result = AuditQueryController.search(null, null, 5);
                Assert.isNotNull(result.cursor, 'A permitted search must return a positioned result.');
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void packagedPermissionSetGrantsApexAccessRegardlessOfPackaging() {
        // Apex class access, unlike system permissions, survives managed
        // packaging. If this regressed, subscribers would hit a bare "class
        // not visible" failure before ever reaching our permission message.
        String ns = packageNamespace();
        PermissionSet ps = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Audit_Trail_Viewer' AND IsOwnedByProfile = FALSE AND NamespacePrefix = :ns
            LIMIT 1
        ];

        Set<String> granted = new Set<String>();
        for (SetupEntityAccess access : [
            SELECT SetupEntityId
            FROM SetupEntityAccess
            WHERE ParentId = :ps.Id AND SetupEntityType = 'ApexClass'
        ]) {
            granted.add(access.SetupEntityId);
        }

        List<ApexClass> classes = [
            SELECT Id, Name
            FROM ApexClass
            WHERE
                Name IN ('AuditQueryController', 'AuditQueryService', 'AuditPermissionService')
                AND NamespacePrefix = :ns
        ];
        Assert.areEqual(3, classes.size(), 'All three runtime classes must exist in this namespace.');
        for (ApexClass cls : classes) {
            Assert.isTrue(
                granted.contains(cls.Id),
                'The shipped permission set must grant access to ' + cls.Name + '.'
            );
        }
    }
}
