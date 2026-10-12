@IsTest
public with sharing class MockAuditTrailProvider implements AuditTrailProvider {
    public List<AuditEventRow> allRows = new List<AuditEventRow>();
    public Integer fetchCount = 0;

    public MockAuditTrailProvider(List<AuditEventRow> rows) {
        // Sorted once, the way the real query orders rows: CreatedDate DESC,
        // Id DESC. recordId values are 18-character Ids built from a
        // zero-padded index (see fakeId), so String ordering matches Id order.
        this.allRows = rows == null ? new List<AuditEventRow>() : new List<AuditEventRow>(rows);
        this.allRows.sort(new DescendingKeyset());
    }

    /**
     * Mirrors the real provider's contract: (CreatedDate DESC, Id DESC) order,
     * inclusive date bounds, keyset exclusion at the upper bound, optional
     * action/user predicates, row limit.
     */
    public List<AuditEventRow> fetch(
        Datetime upperBound,
        Datetime lowerBound,
        List<String> actions,
        List<String> userIds,
        Id lastId,
        Integer rowLimit
    ) {
        fetchCount++;
        Long upper = upperBound.getTime();
        Long lower = lowerBound.getTime();
        String lastIdText = lastId == null ? null : String.valueOf(lastId);
        Set<String> actionSet = actions == null ? new Set<String>() : new Set<String>(actions);
        Set<String> userSet = userIds == null ? new Set<String>() : new Set<String>(userIds);

        List<AuditEventRow> matched = new List<AuditEventRow>();
        for (AuditEventRow row : allRows) {
            if (row.eventDateMillis > upper || row.eventDateMillis < lower) {
                continue;
            }
            // Rows at exactly the upper bound with an id at or above the last
            // consumed one were already returned on an earlier fetch.
            if (lastIdText != null && row.eventDateMillis == upper && row.recordId.compareTo(lastIdText) >= 0) {
                continue;
            }
            if (!actionSet.isEmpty() && !actionSet.contains(row.action)) {
                continue;
            }
            if (!userSet.isEmpty() && !userSet.contains(row.userId)) {
                continue;
            }
            matched.add(row);
            if (matched.size() >= rowLimit) {
                break;
            }
        }
        return matched;
    }

    /** Orders rows newest first, then by id descending, like the real query. */
    private class DescendingKeyset implements Comparator<AuditEventRow> {
        public Integer compare(AuditEventRow a, AuditEventRow b) {
            if (a.eventDateMillis != b.eventDateMillis) {
                return a.eventDateMillis > b.eventDateMillis ? -1 : 1;
            }
            return b.recordId.compareTo(a.recordId);
        }
    }

    /** Builds a row for the in-memory provider; the constructor sorts them. */
    public static AuditEventRow row(Integer index, Datetime occurredAt, String section, String action, String display) {
        AuditEventRow r = new AuditEventRow();
        r.recordId = fakeId(index);
        r.eventDateMillis = occurredAt.getTime();
        r.section = section;
        r.action = action;
        r.display = display;
        r.userId = UserInfo.getUserId();
        r.userName = UserInfo.getName();
        return r;
    }

    public static Id fakeId(Integer index) {
        // Built from the SetupAuditTrail key prefix rather than a literal
        // record id, so the value is synthetic by construction.
        // DEFERRED avoids eagerly loading every child relationship just to read
        // the key prefix - this runs in a loop in the paging tests.
        String prefix = SetupAuditTrail.SObjectType.getDescribe(SObjectDescribeOptions.DEFERRED).getKeyPrefix();
        String body = String.valueOf(index).leftPad(15 - prefix.length(), '0');
        return Id.valueOf(prefix + body);
    }
}
