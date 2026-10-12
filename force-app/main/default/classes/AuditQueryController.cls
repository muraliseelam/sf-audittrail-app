/**
 * @AuraEnabled facade for the Audit Trail Explorer UI.
 *
 * The LWC drives a progressive search: it calls `search` repeatedly, passing back
 * the cursor from the previous response, until `done` is true or the user stops.
 *
 * Error contract: every entry point throws only AuraHandledException. The
 * permission failure passes its user-facing text through; every other failure
 * is collapsed to GENERIC_ERROR so no internal detail reaches the browser.
 */
public with sharing class AuditQueryController {
    /**
     * Client-facing text for an unexpected failure.
     *
     * Platform exception messages can carry query fragments and limit details,
     * so they are not returned verbatim - that is treated as information
     * disclosure. The real detail stays in the server-side debug log.
     */
    private static final String GENERIC_ERROR = 'The audit search could not be completed. Please try again, or contact your administrator if the problem persists.';

    @AuraEnabled(cacheable=false)
    public static AuditSearchResult search(String filterJson, String cursorJson, Integer pageSize) {
        try {
            AuditPermissionService.assertCanViewSetup();
            AuditFilter filter = String.isBlank(filterJson)
                ? new AuditFilter()
                : (AuditFilter) JSON.deserialize(filterJson, AuditFilter.class);
            AuditCursor cursor = String.isBlank(cursorJson)
                ? null
                : (AuditCursor) JSON.deserialize(cursorJson, AuditCursor.class);
            return AuditQueryService.search(filter, cursor, pageSize);
        } catch (AuditPermissionService.AuditPermissionException e) {
            throw permissionFailure(e);
        } catch (Exception e) {
            throw genericFailure(e);
        }
    }

    /** Metadata the UI needs on load: retention window and the user's access. */
    @AuraEnabled(cacheable=false)
    public static Map<String, Object> getContext() {
        try {
            // Deliberately ungated: the UI uses canViewSetup to decide whether
            // to show the search or the "ask your administrator" message, so
            // this must answer false for an unprivileged user rather than throw.
            return new Map<String, Object>{
                'retentionDays' => AuditQueryService.RETENTION_DAYS,
                'retentionFloorMillis' => Datetime.now().addDays(-AuditQueryService.RETENTION_DAYS).getTime(),
                'nowMillis' => Datetime.now().getTime(),
                'canViewSetup' => AuditPermissionService.canViewSetup(),
                'defaultPageSize' => AuditQueryService.DEFAULT_PAGE_SIZE
            };
        } catch (Exception e) {
            throw genericFailure(e);
        }
    }

    /** Type-ahead for the user filter. Audit rows carry no user list of their own. */
    @AuraEnabled(cacheable=false)
    public static List<Map<String, String>> searchUsers(String term) {
        try {
            // Gated on the same permission as the audit data itself: this method
            // exists only to build a filter over that data, so it must not be a
            // way for an unprivileged user to enumerate the org's user list.
            AuditPermissionService.assertCanViewSetup();
            List<Map<String, String>> results = new List<Map<String, String>>();
            String trimmed = term == null ? '' : term.trim();
            if (trimmed.length() < 2) {
                return results;
            }
            // Bind variables are already injection-safe, so the term must NOT be
            // escaped for quotes - doing so would bind a literal backslash and
            // break searches for names like O'Brien. Only the LIKE wildcards need
            // escaping, so a user typing "%" doesn't match everyone. The escape
            // character itself must be doubled first, or the later replacements
            // would be escaped by it.
            String sanitized = trimmed.replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
            String pattern = '%' + sanitized + '%';
            for (User u : [
                SELECT Id, Name, Username
                FROM User
                WHERE (Name LIKE :pattern OR Username LIKE :pattern) AND IsActive = TRUE
                WITH USER_MODE
                ORDER BY Name
                LIMIT 20
            ]) {
                results.add(new Map<String, String>{ 'id' => u.Id, 'name' => u.Name, 'username' => u.Username });
            }
            return results;
        } catch (AuditPermissionService.AuditPermissionException e) {
            throw permissionFailure(e);
        } catch (Exception e) {
            throw genericFailure(e);
        }
    }

    /**
     * The permission message is written for the user and names the permission
     * they need, so it is deliberately passed through unchanged.
     */
    private static AuraHandledException permissionFailure(AuditPermissionService.AuditPermissionException e) {
        AuraHandledException handled = new AuraHandledException(e.getMessage());
        // See genericFailure: without setMessage the client sees only
        // "Script-thrown exception" and never learns which permission it lacks.
        handled.setMessage(e.getMessage());
        return handled;
    }

    private static AuraHandledException genericFailure(Exception e) {
        System.debug(LoggingLevel.ERROR, 'Audit search failed: ' + e.getTypeName() + ': ' + e.getMessage());
        AuraHandledException safe = new AuraHandledException(GENERIC_ERROR);
        // AuraHandledException exposes its message to the client only through
        // setMessage(); the constructor argument alone yields the opaque
        // "Script-thrown exception" text on the client (and in tests).
        safe.setMessage(GENERIC_ERROR);
        return safe;
    }
}
