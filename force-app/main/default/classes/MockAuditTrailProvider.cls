@IsTest
public with sharing class MockAuditTrailProvider implements AuditTrailProvider {
    public List<AuditEventRow> allRows = new List<AuditEventRow>();
    public Integer fetchCount = 0;

    public MockAuditTrailProvider(List<AuditEventRow> rows) {
        this.allRows = rows;
    }

    /** Mirrors the real provider's contract: descending, bounded, exclusions applied. */
    public List<AuditEventRow> fetch(
        Datetime upperBound,
        Datetime lowerBound,
        List<String> actions,
        List<String> userIds,
        Set<Id> excludeIds,
        Integer rowLimit
    ) {
        fetchCount++;
        Set<String> actionSet = actions == null ? new Set<String>() : new Set<String>(actions);
        Set<String> userSet = userIds == null ? new Set<String>() : new Set<String>(userIds);

        List<AuditEventRow> matched = new List<AuditEventRow>();
        for (AuditEventRow row : allRows) {
            Datetime eventDate = row.eventDate();
            if (eventDate > upperBound || eventDate < lowerBound) {
                continue;
            }
            if (excludeIds != null && !excludeIds.isEmpty() && excludeIds.contains((Id) row.recordId)) {
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

    /** Builds a descending-by-date row, as the real provider always returns. */
    public static AuditEventRow row(
        Integer index,
        Datetime occurredAt,
        String section,
        String action,
        String display
    ) {
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
        String suffix = String.valueOf(index);
        return Id.valueOf('0Ym000000000001'.substring(0, 15 - suffix.length()) + suffix);
    }
}
