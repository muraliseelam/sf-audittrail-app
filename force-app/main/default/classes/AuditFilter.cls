/**
 * Filter criteria for an audit search.
 *
 * Only `startDateMillis`, `endDateMillis`, `actions` and `userIds` can be pushed
 * down into SOQL. `sections` and `searchText` target fields that Salesforce does
 * not allow in a WHERE clause (Section and Display are not filterable), so they
 * are applied in Apex by AuditQueryService.
 */
public with sharing class AuditFilter {
    @AuraEnabled
    public Long startDateMillis;
    @AuraEnabled
    public Long endDateMillis;
    @AuraEnabled
    public List<String> actions;
    @AuraEnabled
    public List<String> userIds;
    @AuraEnabled
    public List<String> sections;
    @AuraEnabled
    public String searchText;

    public Datetime startDate() {
        return startDateMillis == null ? null : Datetime.newInstance(startDateMillis);
    }

    public Datetime endDate() {
        return endDateMillis == null ? null : Datetime.newInstance(endDateMillis);
    }
}
