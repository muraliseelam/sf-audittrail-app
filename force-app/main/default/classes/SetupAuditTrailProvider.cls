/**
 * Production AuditTrailProvider backed by SOQL against SetupAuditTrail.
 *
 * Only CreatedDate, Action and CreatedById are pushed into the WHERE clause -
 * Section and Display are not filterable on this object (verified against the
 * describe), so they are handled downstream by AuditQueryService.
 */
public with sharing class SetupAuditTrailProvider implements AuditTrailProvider {
    public List<AuditEventRow> fetch(
        Datetime upperBound,
        Datetime lowerBound,
        List<String> actions,
        List<String> userIds,
        Set<Id> excludeIds,
        Integer rowLimit
    ) {
        String soql =
            'SELECT Id, CreatedDate, Section, Action, Display, CreatedById, CreatedBy.Name, ' +
            'DelegateUser, ResponsibleNamespacePrefix, CreatedByContext, CreatedByIssuer ' +
            'FROM SetupAuditTrail WHERE CreatedDate <= :upperBound AND CreatedDate >= :lowerBound';

        if (actions != null && !actions.isEmpty()) {
            soql += ' AND Action IN :actions';
        }
        if (userIds != null && !userIds.isEmpty()) {
            soql += ' AND CreatedById IN :userIds';
        }
        // Excluding already-consumed ids guarantees forward progress even when a
        // single timestamp holds more rows than one batch can return.
        if (excludeIds != null && !excludeIds.isEmpty()) {
            soql += ' AND Id NOT IN :excludeIds';
        }
        soql += ' ORDER BY CreatedDate DESC LIMIT :rowLimit';

        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (SetupAuditTrail record : Database.query(soql)) {
            rows.add(new AuditEventRow(record));
        }
        return rows;
    }
}
