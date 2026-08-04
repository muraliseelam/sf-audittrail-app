/**
 * @AuraEnabled facade for the Audit Trail Explorer UI.
 *
 * The LWC drives a progressive search: it calls `search` repeatedly, passing back
 * the cursor from the previous response, until `done` is true or the user stops.
 */
public with sharing class AuditQueryController {
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
        } catch (Exception e) {
            throw new AuraHandledException(e.getMessage());
        }
    }

    /** Metadata the UI needs on load: retention window and the user's access. */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getContext() {
        return new Map<String, Object>{
            'retentionDays' => AuditQueryService.RETENTION_DAYS,
            'retentionFloorMillis' => Datetime.now().addDays(-AuditQueryService.RETENTION_DAYS).getTime(),
            'nowMillis' => Datetime.now().getTime(),
            'canViewSetup' => AuditPermissionService.canViewSetup(),
            'defaultPageSize' => AuditQueryService.DEFAULT_PAGE_SIZE
        };
    }

    /** Type-ahead for the user filter. Audit rows carry no user list of their own. */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> searchUsers(String term) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(term) || term.length() < 2) {
            return results;
        }
        // Bind variables are already injection-safe, so the term must NOT be
        // escaped for quotes - doing so would bind a literal backslash and break
        // searches for names like O'Brien. Only the LIKE wildcards need escaping,
        // so a user typing "%" doesn't match everyone.
        String sanitized = term.trim().replace('\\', '\\\\').replace('%', '\\%').replace('_', '\\_');
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
    }
}
