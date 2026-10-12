/**
 * Filter criteria for an audit search.
 *
 * Only the date range, `actions` and `userIds` can be pushed down into SOQL.
 * `sections` and `searchText` target fields that Salesforce does not allow in a
 * WHERE clause (Section and Display are not filterable), so they are applied in
 * Apex by AuditQueryService.
 */
public with sharing class AuditFilter {
    @AuraEnabled
    public Long startDateMillis;
    @AuraEnabled
    public Long endDateMillis;
    /**
     * Preset "last N days" range. When positive, the server derives the range
     * from its own clock (end = now, start = now minus min(N, retention days))
     * and ignores startDateMillis/endDateMillis, so a stale or skewed browser
     * clock cannot widen the window. Null or non-positive means the explicit
     * start/end values apply.
     */
    @AuraEnabled
    public Integer lastDays;
    @AuraEnabled
    public List<String> actions;
    @AuraEnabled
    public List<String> userIds;
    @AuraEnabled
    public List<String> sections;
    @AuraEnabled
    public String searchText;
}
