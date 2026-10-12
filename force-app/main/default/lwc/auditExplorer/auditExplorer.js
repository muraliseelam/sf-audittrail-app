import { LightningElement, track } from 'lwc';
import search from '@salesforce/apex/AuditQueryController.search';
import getContext from '@salesforce/apex/AuditQueryController.getContext';
import searchUsers from '@salesforce/apex/AuditQueryController.searchUsers';
import { csvRow } from './csv';

const COLUMNS = [
    {
        label: 'Date',
        fieldName: 'eventDate',
        type: 'date',
        initialWidth: 190,
        typeAttributes: {
            year: 'numeric',
            month: 'short',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        }
    },
    { label: 'User', fieldName: 'userName', type: 'text', initialWidth: 150 },
    { label: 'Section', fieldName: 'section', type: 'text', initialWidth: 170 },
    { label: 'Action', fieldName: 'action', type: 'text', initialWidth: 190 },
    { label: 'Description', fieldName: 'display', type: 'text', wrapText: true }
];

const ROW_ACTIONS = [{ label: 'View details', name: 'details' }];

// Preset values are the number of days the SERVER subtracts from its own
// clock (AuditFilter.lastDays); the client never computes the upper bound.
const DATE_PRESETS = [
    { label: 'Last 24 hours', value: '1' },
    { label: 'Last 7 days', value: '7' },
    { label: 'Last 30 days', value: '30' },
    { label: 'Last 90 days', value: '90' },
    { label: 'Last 180 days (maximum)', value: '180' },
    { label: 'Custom range', value: 'custom' }
];

const PAGE_SIZE = 50;
// Bounds one user-initiated search so a rare term can't spin forever.
const MAX_CALLS_PER_ACTION = 25;
const DAY_MILLIS = 86400000;
// Excel on Windows only decodes a CSV as UTF-8 when it starts with the BOM.
const UTF8_BOM = '\uFEFF';
const FILTERS_DIRTY_HINT =
    'Filters changed. Click Search to apply them; Search further back continues the current search.';

export default class AuditExplorer extends LightningElement {
    columns = COLUMNS;
    rowActions = ROW_ACTIONS;
    datePresets = DATE_PRESETS;
    filtersDirtyHint = FILTERS_DIRTY_HINT;

    @track rows = [];
    @track selectedUsers = [];
    @track userResults = [];
    @track sectionOptions = [];

    preset = '7';
    customStart;
    customEnd;
    searchText = '';
    selectedSections = [];

    cursor = null;
    done = false;
    loading = false;
    stopRequested = false;
    hasSearched = false;
    // The filter the current search was started with. Every "Search further
    // back" call reuses it, so edits made since do not change the range or
    // the terms of a search that is already in progress.
    activeFilterJson;
    filtersDirty = false;

    scannedTotal = 0;
    scannedThroughMillis;
    retentionDays = 180;
    retentionFloorMillis;
    // Tri-state: undefined until getContext answers, then true/false.
    canViewSetup;
    error;

    sectionFacets = [];
    userFacets = [];
    selectedRow;
    userSearchTerm = '';

    // Object URL of the most recent CSV download. Revoking it synchronously
    // after click() races the browser's download, so it is kept until the
    // next export or until the component leaves the page.
    lastExportUrl;

    connectedCallback() {
        getContext()
            .then((context) => {
                this.retentionDays = context.retentionDays;
                this.retentionFloorMillis = context.retentionFloorMillis;
                this.canViewSetup = context.canViewSetup === true;
                if (this.canViewSetup) {
                    this.runSearch(true);
                }
            })
            .catch((e) => {
                // Access stays unresolved: no form, no search, only the error.
                this.error = this.toMessage(e);
            });
    }

    disconnectedCallback() {
        this.revokeLastExportUrl();
    }

    // ---------- access state ----------

    get isAccessResolved() {
        return this.canViewSetup !== undefined;
    }

    get showForm() {
        return this.canViewSetup === true;
    }

    get showAccessDenied() {
        return this.canViewSetup === false;
    }

    get showAccessSpinner() {
        return !this.isAccessResolved && !this.error;
    }

    // ---------- filter state ----------

    get isCustomRange() {
        return this.preset === 'custom';
    }

    get columnsWithActions() {
        return [...COLUMNS, { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }];
    }

    markFiltersDirty() {
        if (this.hasSearched) {
            this.filtersDirty = true;
        }
    }

    handlePresetChange(event) {
        this.preset = event.detail.value;
        this.markFiltersDirty();
    }

    handleCustomStart(event) {
        this.customStart = event.target.value;
        this.markFiltersDirty();
    }

    handleCustomEnd(event) {
        this.customEnd = event.target.value;
        this.markFiltersDirty();
    }

    handleSearchTextChange(event) {
        this.searchText = event.target.value;
        this.markFiltersDirty();
    }

    handleSectionChange(event) {
        this.selectedSections = event.detail.value;
        this.markFiltersDirty();
    }

    handleSearchKeyUp(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    /** Parses a datetime input value; blank or unparseable values yield null. */
    toMillis(value) {
        if (!value) {
            return null;
        }
        const millis = new Date(value).getTime();
        return Number.isNaN(millis) ? null : millis;
    }

    buildFilter() {
        const filter = {
            sections: this.selectedSections,
            actions: [],
            userIds: this.selectedUsers.map((u) => u.id),
            searchText: this.searchText
        };

        if (this.preset !== 'custom') {
            // The server derives the range from its own clock and pins it in
            // the cursor, so the client sends only the number of days.
            filter.lastDays = parseInt(this.preset, 10);
            return filter;
        }

        // Custom range: explicit bounds. A blank "To" means "up to now", which
        // the server resolves (endDateMillis null), not the browser clock.
        const endMillis = this.toMillis(this.customEnd);
        let startMillis = this.toMillis(this.customStart);
        if (startMillis === null) {
            startMillis = Date.now() - 7 * DAY_MILLIS;
        }
        // Never ask for data older than Salesforce keeps.
        if (this.retentionFloorMillis && startMillis < this.retentionFloorMillis) {
            startMillis = this.retentionFloorMillis;
        }
        filter.startDateMillis = startMillis;
        filter.endDateMillis = endMillis;
        return filter;
    }

    // ---------- progressive search ----------

    handleSearch() {
        this.runSearch(true);
    }

    handleLoadMore() {
        this.runSearch(false);
    }

    handleStop() {
        this.stopRequested = true;
    }

    handleClear() {
        this.preset = '7';
        this.customStart = undefined;
        this.customEnd = undefined;
        this.searchText = '';
        this.selectedSections = [];
        this.selectedUsers = [];
        this.userResults = [];
        this.userSearchTerm = '';
        this.runSearch(true);
    }

    async runSearch(isNewSearch) {
        if (this.loading || this.canViewSetup !== true) {
            return;
        }
        // A continuation without a snapshot (should not happen) is a new search.
        const startFresh = isNewSearch || !this.activeFilterJson;

        this.loading = true;
        this.stopRequested = false;
        this.error = undefined;
        this.hasSearched = true;

        if (startFresh) {
            this.rows = [];
            this.cursor = null;
            this.done = false;
            this.scannedTotal = 0;
            this.scannedThroughMillis = undefined;
            this.selectedRow = undefined;
            this.sectionFacets = [];
            this.userFacets = [];
            // Snapshot the filter once; continuation calls reuse it verbatim.
            this.activeFilterJson = JSON.stringify(this.buildFilter());
            this.filtersDirty = false;
        }

        const filterJson = this.activeFilterJson;
        const targetCount = this.rows.length + PAGE_SIZE;
        let calls = 0;

        try {
            // Keep asking for the next time-slice until the page is filled, the
            // range is exhausted, or the user stops it.
            while (
                !this.done &&
                !this.stopRequested &&
                this.rows.length < targetCount &&
                calls < MAX_CALLS_PER_ACTION
            ) {
                calls++;
                // Sequential by necessity: each call needs the cursor returned
                // by the previous one, so these cannot be parallelised.
                // eslint-disable-next-line no-await-in-loop
                const result = await search({
                    filterJson,
                    // The cursor is opaque to the client: round-trip it as is.
                    cursorJson: this.cursor ? JSON.stringify(this.cursor) : null,
                    pageSize: PAGE_SIZE
                });
                this.applyResult(result);
            }
        } catch (e) {
            this.error = this.toMessage(e);
        } finally {
            this.loading = false;
        }
    }

    applyResult(result) {
        const mapped = (result.rows || []).map((row) => ({
            ...row,
            eventDate: row.eventDateMillis
        }));
        this.rows = this.rows.concat(mapped);
        this.cursor = result.cursor;
        this.done = result.done;
        this.scannedTotal += result.scannedCount || 0;
        this.scannedThroughMillis = result.scannedThroughMillis;
        this.mergeSectionOptions(result.observedSections);
        // The server computes facets only over the rows scanned in this one
        // call, so using result.sectionFacets/userFacets directly would make
        // "Top sections"/"Top users" reset to the latest page instead of
        // reflecting everything displayed so far. Recompute from the full
        // accumulated row set instead, so a "Search further back" call adds
        // to the picture rather than replacing it.
        this.sectionFacets = this.toChartRows(this.computeFacets(this.rows, (row) => row.section));
        this.userFacets = this.toChartRows(this.computeFacets(this.rows, (row) => row.userName));
    }

    /** Counts occurrences of keyFn(row) across rows, highest count first (ties broken alphabetically). */
    computeFacets(rows, keyFn) {
        const counts = new Map();
        rows.forEach((row) => {
            const key = keyFn(row);
            if (!key) {
                return;
            }
            counts.set(key, (counts.get(key) || 0) + 1);
        });
        return Array.from(counts.entries())
            .map(([label, count]) => ({ label, count }))
            .sort((a, b) => (b.count !== a.count ? b.count - a.count : a.label.localeCompare(b.label)));
    }

    mergeSectionOptions(observed) {
        if (!observed || !observed.length) {
            return;
        }
        const known = new Set(this.sectionOptions.map((o) => o.value));
        let changed = false;
        observed.forEach((section) => {
            if (!known.has(section)) {
                known.add(section);
                changed = true;
            }
        });
        if (changed) {
            this.sectionOptions = Array.from(known)
                .sort()
                .map((s) => ({ label: s, value: s }));
        }
    }

    toChartRows(facets) {
        if (!facets || !facets.length) {
            return [];
        }
        const max = facets[0].count || 1;
        return facets.slice(0, 8).map((f) => ({
            label: f.label,
            count: f.count,
            style: `width: ${Math.max(4, Math.round((f.count / max) * 100))}%`
        }));
    }

    // ---------- user filter ----------

    handleUserTermChange(event) {
        const term = event.target.value;
        this.userSearchTerm = term;
        if (!term || term.length < 2) {
            this.userResults = [];
            return;
        }
        searchUsers({ term })
            .then((results) => {
                // The user has typed on (or picked someone) since this call
                // left: an older answer must not overwrite the newer list.
                if (this.userSearchTerm !== term) {
                    return;
                }
                const chosen = new Set(this.selectedUsers.map((u) => u.id));
                this.userResults = (results || []).filter((u) => !chosen.has(u.id));
            })
            .catch((e) => {
                if (this.userSearchTerm !== term) {
                    return;
                }
                this.userResults = [];
                this.error = this.toMessage(e);
            });
    }

    handleUserSelect(event) {
        const id = event.currentTarget.dataset.id;
        const picked = this.userResults.find((u) => u.id === id);
        if (picked) {
            this.selectedUsers = [...this.selectedUsers, picked];
            this.userResults = this.userResults.filter((u) => u.id !== id);
            this.userSearchTerm = '';
            this.markFiltersDirty();
        }
    }

    handleUserRemove(event) {
        // lightning-pill-container's itemremove carries { item, index }, not
        // the pill's name directly.
        const detail = event.detail || {};
        const item = detail.item;
        const id = (item && item.name) || (this.userPills[detail.index] || {}).name;
        if (!id) {
            return;
        }
        this.selectedUsers = this.selectedUsers.filter((u) => u.id !== id);
        this.markFiltersDirty();
    }

    get userPills() {
        return this.selectedUsers.map((u) => ({ label: u.name, name: u.id }));
    }

    get hasUserResults() {
        return this.userResults.length > 0;
    }

    // ---------- row detail ----------

    handleRowAction(event) {
        if (event.detail.action.name === 'details') {
            this.selectedRow = event.detail.row;
        }
    }

    handleCloseDetail() {
        this.selectedRow = undefined;
    }

    get selectedRowDate() {
        return this.selectedRow ? new Date(this.selectedRow.eventDateMillis).toLocaleString() : '';
    }

    // ---------- export ----------

    handleExport() {
        if (this.exportDisabled) {
            return;
        }
        const header = ['Date', 'User', 'Section', 'Action', 'Description', 'Delegate User', 'Namespace'];
        const lines = [csvRow(header)];
        this.rows.forEach((row) => {
            lines.push(
                csvRow([
                    new Date(row.eventDateMillis).toISOString(),
                    row.userName,
                    row.section,
                    row.action,
                    row.display,
                    row.delegateUser,
                    row.namespacePrefix
                ])
            );
        });
        // The BOM only affects decoding; the first cell is still the quoted
        // header "Date", so the formula guard in csv.js is unaffected.
        const blob = new Blob([UTF8_BOM + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });

        // Release the previous download's URL now that a new one replaces it.
        this.revokeLastExportUrl();
        const url = URL.createObjectURL(blob);
        this.lastExportUrl = url;

        const link = document.createElement('a');
        link.href = url;
        link.download = `audit-trail-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
    }

    revokeLastExportUrl() {
        if (this.lastExportUrl) {
            URL.revokeObjectURL(this.lastExportUrl);
            this.lastExportUrl = undefined;
        }
    }

    // ---------- display helpers ----------

    get resultCount() {
        return this.rows.length;
    }

    get hasRows() {
        return this.rows.length > 0;
    }

    get showEmptyState() {
        return this.hasSearched && !this.loading && this.rows.length === 0 && !this.error;
    }

    get canLoadMore() {
        return !this.done && !this.loading && this.hasSearched;
    }

    get progressText() {
        if (!this.hasSearched) {
            return '';
        }
        const scannedThrough = this.scannedThroughMillis
            ? new Date(this.scannedThroughMillis).toLocaleString()
            : 'the start of the range';
        if (this.done) {
            return `Search complete - examined ${this.scannedTotal} events back to ${scannedThrough}.`;
        }
        if (this.loading) {
            return `Searching... examined ${this.scannedTotal} events, currently at ${scannedThrough}.`;
        }
        return `Paused - examined ${this.scannedTotal} events back to ${scannedThrough}. More history remains.`;
    }

    get retentionMessage() {
        const floor = this.retentionFloorMillis ? new Date(this.retentionFloorMillis).toLocaleDateString() : '';
        return `Salesforce retains Setup Audit Trail for ${this.retentionDays} days. History before ${floor} is no longer available.`;
    }

    get hasFacets() {
        return this.sectionFacets.length > 0 || this.userFacets.length > 0;
    }

    get exportDisabled() {
        return !(this.hasRows && this.canViewSetup === true);
    }

    toMessage(e) {
        if (e && e.body && e.body.message) {
            return e.body.message;
        }
        if (e && e.message) {
            return e.message;
        }
        return 'Unexpected error loading audit data.';
    }
}
