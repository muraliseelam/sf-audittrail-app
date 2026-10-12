/**
 * Keyset pagination cursor for progressive audit search.
 *
 * Rows are read in (CreatedDate DESC, Id DESC) order and the cursor records the
 * last consumed (timestamp, id) pair. The next query resumes strictly after that
 * pair - rows older than the timestamp, plus rows at the same timestamp with a
 * smaller id - so a single metadata deployment that writes hundreds of audit
 * rows in the same second is paged through precisely, with no skipped rows and
 * no duplicates. Because the id is part of the sort key there is no need to
 * carry a list of already-seen ids, so the cursor stays a fixed size however
 * many rows share a timestamp.
 *
 * The cursor also pins the date range resolved on the first call of a search
 * (rangeStartMillis/rangeEndMillis), so continuation calls page over exactly
 * the same window regardless of what the client sends later.
 *
 * The cursor round-trips through the browser, so it is untrusted input:
 * lastIdValue() rejects a continuation cursor whose id is not well formed.
 */
public with sharing class AuditCursor {
    @AuraEnabled
    public Long lastDateMillis;
    @AuraEnabled
    public String lastId;
    @AuraEnabled
    public Long rangeStartMillis;
    @AuraEnabled
    public Long rangeEndMillis;
    @AuraEnabled
    public Boolean exhausted;

    public AuditCursor() {
        this.exhausted = false;
    }

    public Datetime lastDate() {
        return lastDateMillis == null ? null : Datetime.newInstance(lastDateMillis);
    }

    /** Records a consumed row as the new keyset position. */
    public void consume(AuditEventRow row) {
        lastDateMillis = row.eventDateMillis;
        lastId = row.recordId;
    }

    /**
     * The keyset id as an Id, or null when the cursor has no position yet.
     *
     * @throws IllegalArgumentException when the cursor claims a position but its
     *         id is blank, not a well-formed Id, or not a SetupAuditTrail Id -
     *         the controller turns this into the generic client error.
     */
    public Id lastIdValue() {
        if (lastDateMillis == null) {
            return null;
        }
        if (String.isBlank(lastId) || !(lastId instanceof Id)) {
            throw new IllegalArgumentException('Malformed cursor');
        }
        Id value = (Id) lastId;
        if (value.getSObjectType() != SetupAuditTrail.SObjectType) {
            throw new IllegalArgumentException('Malformed cursor');
        }
        return value;
    }
}
