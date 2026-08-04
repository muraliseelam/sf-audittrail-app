/**
 * Guards access to Setup Audit Trail data.
 *
 * Reading SetupAuditTrail requires the "View Setup and Configuration"
 * permission. Rather than inspecting permission assignments, this asks the
 * platform directly whether the running user can read the object.
 *
 * That equivalence was verified empirically in a scratch org: a user whose
 * profile grants ViewSetup sees isAccessible() == true, and a user on
 * "Minimum Access - Salesforce" (which lacks it) sees false.
 * AuditPermissionServiceTest pins the negative case down so the gate cannot
 * silently open up.
 *
 * Using the describe beats querying PermissionSetAssignment on three counts:
 * it is the object-level access check a security review expects to see, it
 * costs no SOQL query, and it removes the need for a system-mode query against
 * the permission tables.
 */
public with sharing class AuditPermissionService {
    public class AuditPermissionException extends Exception {
    }

    @TestVisible
    private static Boolean overrideHasPermission = null;

    public static Boolean canViewSetup() {
        if (overrideHasPermission != null) {
            return overrideHasPermission;
        }
        return Schema.SObjectType.SetupAuditTrail.isAccessible();
    }

    public static void assertCanViewSetup() {
        if (!canViewSetup()) {
            throw new AuditPermissionException(
                'You need the "View Setup and Configuration" permission to read the Setup Audit Trail. ' +
                'Ask your administrator to assign the Audit Trail Viewer permission set.'
            );
        }
    }
}
