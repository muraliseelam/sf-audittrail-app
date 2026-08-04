/**
 * Result of one progressive-search call: the matches found, how far back the
 * scan reached, and the cursor needed to continue.
 */
public with sharing class AuditSearchResult {
    @AuraEnabled
    public List<AuditEventRow> rows = new List<AuditEventRow>();
    @AuraEnabled
    public AuditCursor cursor;
    /** Rows examined in this call (not rows matched). Drives the progress UI. */
    @AuraEnabled
    public Integer scannedCount = 0;
    /** Oldest timestamp reached, so the UI can say "searched back to <date>". */
    @AuraEnabled
    public Long scannedThroughMillis;
    /** True when the whole requested range has been searched. */
    @AuraEnabled
    public Boolean done = false;
    /** Distinct Section values observed while scanning, for filter discovery. */
    @AuraEnabled
    public List<String> observedSections = new List<String>();
    /** Distinct Action values observed while scanning, for filter discovery. */
    @AuraEnabled
    public List<String> observedActions = new List<String>();
    /** Counts over matched rows, used by the Insights charts. */
    @AuraEnabled
    public List<AuditFacet> sectionFacets = new List<AuditFacet>();
    @AuraEnabled
    public List<AuditFacet> actionFacets = new List<AuditFacet>();
    @AuraEnabled
    public List<AuditFacet> userFacets = new List<AuditFacet>();

    public with sharing class AuditFacet implements Comparable {
        @AuraEnabled
        public String label;
        @AuraEnabled
        public Integer count;

        public AuditFacet(String label, Integer count) {
            this.label = label;
            this.count = count;
        }

        /** Highest count first, then alphabetical, so charts are stable. */
        public Integer compareTo(Object other) {
            AuditFacet that = (AuditFacet) other;
            if (this.count != that.count) {
                return that.count - this.count;
            }
            return this.label.compareTo(that.label);
        }
    }
}
