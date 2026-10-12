/**
 * Production AuditTrailProvider backed by SOQL against SetupAuditTrail.
 *
 * Only CreatedDate, Id, Action and CreatedById are pushed into the WHERE clause -
 * Section and Display are not filterable on this object (verified against the
 * describe), so they are handled downstream by AuditQueryService.
 */
public with sharing class SetupAuditTrailProvider implements AuditTrailProvider {
    public List<AuditEventRow> fetch(
        Datetime upperBound,
        Datetime lowerBound,
        List<String> actions,
        List<String> userIds,
        Id lastId,
        Integer rowLimit
    ) {
        String soql =
            'SELECT Id, CreatedDate, Section, Action, Display, CreatedById, CreatedBy.Name, ' +
            'DelegateUser, ResponsibleNamespacePrefix, CreatedByContext, CreatedByIssuer ' +
            'FROM SetupAuditTrail WHERE CreatedDate >= :lowerBound AND CreatedDate <= :upperBound';

        // Keyset continuation: rows at the boundary timestamp with an id at or
        // above the last consumed one were already returned, so resume strictly
        // after that (CreatedDate, Id) position. This guarantees forward
        // progress even when a single timestamp holds more rows than one batch.
        if (lastId != null) {
            soql += ' AND (CreatedDate < :upperBound OR Id < :lastId)';
        }
        if (actions != null && !actions.isEmpty()) {
            soql += ' AND Action IN :actions';
        }
        if (userIds != null && !userIds.isEmpty()) {
            soql += ' AND CreatedById IN :userIds';
        }
        soql += ' ORDER BY CreatedDate DESC, Id DESC LIMIT :rowLimit';

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
