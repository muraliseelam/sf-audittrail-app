/**
 * Keyset pagination cursor for progressive audit search.
 *
 * Paging by CreatedDate alone is unsafe because a single metadata deployment can
 * write hundreds of audit rows sharing the same timestamp. The cursor therefore
 * carries the timestamp of the last consumed row *and* the ids already consumed
 * at exactly that timestamp, so the next query can exclude them precisely -
 * no skipped rows and no duplicates.
 */
public class AuditCursor {
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
        if (seenIdsAtLastDate != null) {
            for (String value : seenIdsAtLastDate) {
                if (String.isNotBlank(value)) {
                    ids.add((Id) value);
                }
            }
        }
        return ids;
    }
}
