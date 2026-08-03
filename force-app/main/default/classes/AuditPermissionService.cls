/**
 * Guards access to Setup Audit Trail data.
 *
 * Querying SetupAuditTrail requires the "View Setup and Configuration" permission.
 * That permission is not expressed as normal object CRUD, so it is checked
 * explicitly here to produce a clear message instead of an opaque SOQL failure.
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
        // A profile's permissions are also exposed as a PermissionSet row
        // (IsOwnedByProfile = true), so this single query covers both profile
        // and permission-set grants.
        return ![
            SELECT Id
            FROM PermissionSetAssignment
            WHERE
                AssigneeId = :UserInfo.getUserId()
                AND PermissionSet.PermissionsViewSetup = TRUE
            LIMIT 1
        ].isEmpty();
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
