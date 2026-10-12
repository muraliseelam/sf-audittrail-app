/**
 * Source of audit rows.
 *
 * SetupAuditTrail records cannot be inserted by tests, so the query service
 * depends on this interface rather than on SOQL directly. Production uses
 * SetupAuditTrailProvider; tests supply an in-memory implementation.
 *
 * Paging is keyset-based on (CreatedDate, Id): the caller passes the newest
 * timestamp still of interest plus the id of the last row it consumed at that
 * timestamp, and the provider resumes strictly after that position.
 */
public interface AuditTrailProvider {
    /**
     * Returns rows ordered by CreatedDate descending, then Id descending.
     *
     * @param upperBound  inclusive newest timestamp to return
     * @param lowerBound  inclusive oldest timestamp to return
     * @param actions     optional Action values to restrict to
     * @param userIds     optional CreatedById values to restrict to
     * @param lastId      when non-null, rows at exactly upperBound whose Id is
     *                    greater than or equal to it were already consumed and
     *                    must be excluded
     * @param rowLimit    maximum rows to return
     */
    List<AuditEventRow> fetch(
        Datetime upperBound,
        Datetime lowerBound,
        List<String> actions,
        List<String> userIds,
        Id lastId,
        Integer rowLimit
    );
}
