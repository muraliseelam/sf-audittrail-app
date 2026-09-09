/**
 * Proves the access gate actually denies a user who lacks "View Setup and
 * Configuration".
 *
 * This is the security control the whole app rests on, so it is tested against
 * a real user on a real profile rather than a mocked flag. "Minimum Access -
 * Salesforce" is used because it is a stock profile that does not grant
 * ViewSetup, so the assertion stays meaningful in any org.
 */
@IsTest
private class AuditPermissionServiceTest {
    private static User buildUser(String profileName) {
        Profile p = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
        return new User(
            ProfileId = p.Id,
            LastName = 'Audit Gate',
            Email = 'audit.gate@example.com',
            Username = 'audit.gate.' + Datetime.now().getTime() + '@example.com.invalid',
            Alias = 'agate',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US'
        );
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
            try {
                AuditQueryController.search(null, null, 10);
                Assert.fail('search should be gated by the ViewSetup permission.');
            } catch (Exception e) {
                Assert.isInstanceOfType(e, AuraHandledException.class, 'Expected a handled Aura exception.');
            }

            try {
                AuditQueryController.searchUsers('ab');
                Assert.fail('searchUsers should be gated by the ViewSetup permission.');
            } catch (AuditPermissionService.AuditPermissionException e) {
                Assert.isNotNull(e.getMessage());
            }
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

        PermissionSet ps = [
            SELECT Id, PermissionsViewSetup
            FROM PermissionSet
            WHERE Name = 'Audit_Trail_Viewer' AND IsOwnedByProfile = FALSE
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
                AuditQueryController.search(null, null, 5);
            }
        }
        Test.stopTest();
    }

    @IsTest
    static void packagedPermissionSetGrantsApexAccessRegardlessOfPackaging() {
        // Apex class access, unlike system permissions, survives managed
        // packaging. If this regressed, subscribers would hit a bare "class
        // not visible" failure before ever reaching our permission message.
        PermissionSet ps = [
            SELECT Id
            FROM PermissionSet
            WHERE Name = 'Audit_Trail_Viewer' AND IsOwnedByProfile = FALSE
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

        for (ApexClass cls : [
            SELECT Id, Name
            FROM ApexClass
            WHERE Name IN ('AuditQueryController', 'AuditQueryService', 'AuditPermissionService')
        ]) {
            Assert.isTrue(
                granted.contains(cls.Id),
                'The shipped permission set must grant access to ' + cls.Name + '.'
            );
        }
    }
}
