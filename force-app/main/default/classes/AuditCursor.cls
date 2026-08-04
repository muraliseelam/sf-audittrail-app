/**
 * Keyset pagination cursor for progressive audit search.
 *
 * Paging by CreatedDate alone is unsafe because a single metadata deployment can
 * write hundreds of audit rows sharing the same timestamp. The cursor therefore
 * carries the timestamp of the last consumed row *and* the ids already consumed
 * at exactly that timestamp, so the next query can exclude them precisely -
 * no skipped rows and no duplicates.
 */
public with sharing class AuditCursor {
    /**
     * Upper bound on ids carried for one timestamp. The cursor arrives from the
     * client, so it is untrusted input: without a cap a crafted cursor could
     * push an arbitrarily large bind into the query. Well beyond any real
     * timestamp collision, so legitimate paging is unaffected.
     */
    private static final Integer MAX_SEEN_IDS = 5000;

    @AuraEnabled
    public Long lastDateMillis;
    @AuraEnabled
    public List<String> seenIdsAtLastDate;
    @AuraEnabled
    public Boolean exhausted;

    public AuditCursor() {
        this.seenIdsAtLastDate = new List<String>();
        this.exhausted = false;
    }

    public Datetime lastDate() {
        return lastDateMillis == null ? null : Datetime.newInstance(lastDateMillis);
    }

    /** Records a consumed row, resetting the seen-id set when the timestamp moves. */
    public void consume(AuditEventRow row) {
        if (lastDateMillis != null && lastDateMillis.equals(row.eventDateMillis)) {
            seenIdsAtLastDate.add(row.recordId);
        } else {
            lastDateMillis = row.eventDateMillis;
            seenIdsAtLastDate = new List<String>{ row.recordId };
        }
    }

    public Set<Id> seenIdSet() {
        Set<Id> ids = new Set<Id>();
        if (seenIdsAtLastDate == null) {
            return ids;
        }
        for (String value : seenIdsAtLastDate) {
            if (ids.size() >= MAX_SEEN_IDS) {
                break;
            }
            // Silently skip anything that is not a well-formed id rather than
            // letting a malformed client cursor throw a cast exception.
            if (String.isNotBlank(value) && value instanceof Id) {
                ids.add((Id) value);
            }
        }
        return ids;
    }
}
