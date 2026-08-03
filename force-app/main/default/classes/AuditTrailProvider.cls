/**
 * Source of audit rows.
 *
 * SetupAuditTrail records cannot be inserted by tests, so the query service
 * depends on this interface rather than on SOQL directly. Production uses
 * SetupAuditTrailProvider; tests supply an in-memory implementation.
 */
public interface AuditTrailProvider {
    /**
     * Returns rows ordered by event date descending.
     *
     * @param upperBound  inclusive newest timestamp to return
     * @param lowerBound  inclusive oldest timestamp to return
     * @param actions     optional Action values to restrict to
     * @param userIds     optional CreatedById values to restrict to
     * @param excludeIds  ids already consumed at upperBound; must be excluded
     * @param rowLimit    maximum rows to return
     */
    List<AuditEventRow> fetch(
        Datetime upperBound,
        Datetime lowerBound,
        List<String> actions,
        List<String> userIds,
        Set<Id> excludeIds,
        Integer rowLimit
    );
}
