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

        // USER_MODE enforces the running user's object and field permissions on
        // this query. The SOQL text itself is assembled only from the string
        // literals above - every caller-supplied value arrives as a bind
        // variable - so there is no injection path into Database.query.
        List<AuditEventRow> rows = new List<AuditEventRow>();
        for (SetupAuditTrail record : Database.query(soql, AccessLevel.USER_MODE)) {
            rows.add(new AuditEventRow(record));
        }
        return rows;
    }
}
