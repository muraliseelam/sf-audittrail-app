/**
 * A single Setup Audit Trail event, flattened for transport to the UI.
 *
 * Dates are carried as epoch milliseconds so the client can render them in the
 * running user's timezone without any server-side timezone assumptions.
 */
public with sharing class AuditEventRow {
    @AuraEnabled
    public String recordId;
    @AuraEnabled
    public Long eventDateMillis;
    @AuraEnabled
    public String section;
    @AuraEnabled
    public String action;
    @AuraEnabled
    public String display;
    @AuraEnabled
    public String userId;
    @AuraEnabled
    public String userName;
    @AuraEnabled
    public String delegateUser;
    @AuraEnabled
    public String namespacePrefix;
    @AuraEnabled
    public String createdByContext;
    @AuraEnabled
    public String createdByIssuer;

    // Required so JSON.deserialize can construct instances; declaring the
    // SetupAuditTrail constructor below would otherwise hide the default one.
    public AuditEventRow() {
        return;
    }

    public AuditEventRow(SetupAuditTrail record) {
        this.recordId = record.Id;
        this.eventDateMillis = record.CreatedDate == null ? null : record.CreatedDate.getTime();
        this.section = record.Section;
        this.action = record.Action;
        this.display = record.Display;
        this.userId = record.CreatedById;
        this.userName = record.CreatedBy == null ? null : record.CreatedBy.Name;
        this.delegateUser = record.DelegateUser;
        this.namespacePrefix = record.ResponsibleNamespacePrefix;
        this.createdByContext = record.CreatedByContext;
        this.createdByIssuer = record.CreatedByIssuer;
    }

    public Datetime eventDate() {
        return eventDateMillis == null ? null : Datetime.newInstance(eventDateMillis);
    }
}
