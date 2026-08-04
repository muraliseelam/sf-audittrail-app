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

const DATE_PRESETS = [
    { label: 'Today', value: '1' },
    { label: 'Last 7 days', value: '7' },
    { label: 'Last 30 days', value: '30' },
    { label: 'Last 90 days', value: '90' },
    { label: 'Last 180 days (maximum)', value: '180' },
    { label: 'Custom range', value: 'custom' }
];

const PAGE_SIZE = 50;
// Bounds one user-initiated search so a rare term can't spin forever.
const MAX_CALLS_PER_ACTION = 25;

export default class AuditExplorer extends LightningElement {
    columns = COLUMNS;
    rowActions = ROW_ACTIONS;
    datePresets = DATE_PRESETS;

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

    scannedTotal = 0;
    scannedThroughMillis;
    retentionDays = 180;
    retentionFloorMillis;
    canViewSetup = true;
    error;

    sectionFacets = [];
    userFacets = [];
    selectedRow;
    userSearchTerm = '';

    connectedCallback() {
        getContext()
            .then((context) => {
                this.retentionDays = context.retentionDays;
                this.retentionFloorMillis = context.retentionFloorMillis;
                this.canViewSetup = context.canViewSetup;
                if (this.canViewSetup) {
                    this.runSearch(true);
                }
            })
            .catch((e) => {
                this.error = this.toMessage(e);
            });
    }

    // ---------- filter state ----------

    get isCustomRange() {
        return this.preset === 'custom';
    }

    get columnsWithActions() {
        return [...COLUMNS, { type: 'action', typeAttributes: { rowActions: ROW_ACTIONS } }];
    }

    handlePresetChange(event) {
        this.preset = event.detail.value;
    }

    handleCustomStart(event) {
        this.customStart = event.target.value;
    }

    handleCustomEnd(event) {
        this.customEnd = event.target.value;
    }

    handleSearchTextChange(event) {
        this.searchText = event.target.value;
    }

    handleSectionChange(event) {
        this.selectedSections = event.detail.value;
    }

    handleSearchKeyUp(event) {
        if (event.key === 'Enter') {
            this.handleSearch();
        }
    }

    buildFilter() {
        const now = Date.now();
        let startMillis;
        let endMillis = now;

        if (this.preset === 'custom') {
            startMillis = this.customStart ? new Date(this.customStart).getTime() : now - 7 * 86400000;
            endMillis = this.customEnd ? new Date(this.customEnd).getTime() : now;
        } else {
            startMillis = now - parseInt(this.preset, 10) * 86400000;
        }
        // Never ask for data older than Salesforce keeps.
        if (this.retentionFloorMillis && startMillis < this.retentionFloorMillis) {
            startMillis = this.retentionFloorMillis;
        }

        return {
            startDateMillis: startMillis,
            endDateMillis: endMillis,
            sections: this.selectedSections,
            actions: [],
            userIds: this.selectedUsers.map((u) => u.id),
            searchText: this.searchText
        };
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
        if (this.loading) {
            return;
        }
        this.loading = true;
        this.stopRequested = false;
        this.error = undefined;
        this.hasSearched = true;

        if (isNewSearch) {
            this.rows = [];
            this.cursor = null;
            this.done = false;
            this.scannedTotal = 0;
            this.scannedThroughMillis = undefined;
            this.selectedRow = undefined;
            this.sectionFacets = [];
            this.userFacets = [];
        }

        const filterJson = JSON.stringify(this.buildFilter());
        const targetCount = this.rows.length + PAGE_SIZE;
        let calls = 0;

        try {
            // Keep asking for the next time-slice until the page is filled, the
            // range is exhausted, or the user stops it.
            while (!this.done && !this.stopRequested && this.rows.length < targetCount && calls < MAX_CALLS_PER_ACTION) {
                calls++;
                // Sequential by necessity: each call needs the cursor returned
                // by the previous one, so these cannot be parallelised.
                // eslint-disable-next-line no-await-in-loop
                const result = await search({
                    filterJson,
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
        this.sectionFacets = this.toChartRows(result.sectionFacets);
        this.userFacets = this.toChartRows(result.userFacets);
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
        this.userSearchTerm = event.target.value;
        if (!this.userSearchTerm || this.userSearchTerm.length < 2) {
            this.userResults = [];
            return;
        }
        searchUsers({ term: this.userSearchTerm })
            .then((results) => {
                const chosen = new Set(this.selectedUsers.map((u) => u.id));
                this.userResults = results.filter((u) => !chosen.has(u.id));
            })
            .catch(() => {
                this.userResults = [];
            });
    }

    handleUserSelect(event) {
        const id = event.currentTarget.dataset.id;
        const picked = this.userResults.find((u) => u.id === id);
        if (picked) {
            this.selectedUsers = [...this.selectedUsers, picked];
            this.userResults = this.userResults.filter((u) => u.id !== id);
            this.userSearchTerm = '';
        }
    }

    handleUserRemove(event) {
        const id = event.detail.name;
        this.selectedUsers = this.selectedUsers.filter((u) => u.id !== id);
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
        if (!this.rows.length) {
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
        const blob = new Blob([lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
        const link = document.createElement('a');
        link.href = URL.createObjectURL(blob);
        link.download = `audit-trail-${new Date().toISOString().slice(0, 10)}.csv`;
        link.click();
        URL.revokeObjectURL(link.href);
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
        return this.rows.length === 0;
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
