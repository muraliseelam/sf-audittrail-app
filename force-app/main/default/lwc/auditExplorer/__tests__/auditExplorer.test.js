import { createElement } from 'lwc';
import AuditExplorer from 'c/auditExplorer';
import { csvCell, csvRow } from '../csv';
import getContext from '@salesforce/apex/AuditQueryController.getContext';
import search from '@salesforce/apex/AuditQueryController.search';
import searchUsers from '@salesforce/apex/AuditQueryController.searchUsers';

jest.mock('@salesforce/apex/AuditQueryController.getContext', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/AuditQueryController.search', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/AuditQueryController.searchUsers', () => ({ default: jest.fn() }), {
    virtual: true
});

const NOW = Date.now();

const CONTEXT = {
    retentionDays: 180,
    retentionFloorMillis: NOW - 180 * 86400000,
    nowMillis: NOW,
    canViewSetup: true,
    defaultPageSize: 50
};

const USER_ID = '005000000000001AAA';
const USER = { id: USER_ID, name: 'Jane Admin', username: 'jane@example.com' };

function buildRow(index) {
    return {
        recordId: `0Ym00000000000${index}`,
        eventDateMillis: NOW - index * 60000,
        section: 'Manage Users',
        action: 'changedpassword',
        display: `Event ${index}`,
        userName: 'Test User'
    };
}

/** The keyset cursor the server returns; the client treats it as opaque. */
function buildCursor(index, exhausted) {
    return {
        lastDateMillis: NOW - index * 60000,
        lastId: `0Ym00000000000${index}`,
        rangeStartMillis: NOW - 7 * 86400000,
        rangeEndMillis: NOW,
        exhausted: exhausted === true
    };
}

function buildResult(rows, done, lastIndex) {
    return {
        rows,
        cursor: buildCursor(lastIndex === undefined ? rows.length : lastIndex, done),
        scannedCount: rows.length,
        scannedThroughMillis: NOW - (lastIndex === undefined ? rows.length : lastIndex) * 60000,
        done,
        observedSections: [],
        observedActions: [],
        sectionFacets: [],
        actionFacets: [],
        userFacets: []
    };
}

function createComponent() {
    const element = createElement('c-audit-explorer', { is: AuditExplorer });
    document.body.appendChild(element);
    return element;
}

async function flush() {
    await Promise.resolve();
    await Promise.resolve();
    await Promise.resolve();
}

/** Drains a longer chain of sequential awaits (one search call ~ one flush). */
async function settle(times) {
    for (let i = 0; i < times; i++) {
        // eslint-disable-next-line no-await-in-loop
        await flush();
    }
}

function findButton(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find((button) => button.label === label);
}

function findInput(element, label) {
    return Array.from(element.shadowRoot.querySelectorAll('lightning-input')).find((input) => input.label === label);
}

function setInputValue(input, value) {
    input.value = value;
    input.dispatchEvent(new CustomEvent('change'));
}

function parsedFilter(callIndex) {
    return JSON.parse(search.mock.calls[callIndex][0].filterJson);
}

async function addUserViaTypeAhead(element) {
    searchUsers.mockResolvedValue([USER]);
    setInputValue(findInput(element, 'Filter by user'), 'ja');
    await flush();
    const result = element.shadowRoot.querySelector('.audit-user-result');
    expect(result).not.toBeNull();
    result.click();
    await flush();
}

describe('c-audit-explorer', () => {
    afterEach(() => {
        while (document.body.firstChild) {
            document.body.removeChild(document.body.firstChild);
        }
        jest.clearAllMocks();
    });

    it('renders results returned by the search', async () => {
        getContext.mockResolvedValue(CONTEXT);
        search.mockResolvedValue({
            rows: [buildRow(1), buildRow(2)],
            cursor: buildCursor(2, true),
            scannedCount: 2,
            scannedThroughMillis: NOW,
            done: true,
            observedSections: ['Manage Users'],
            observedActions: ['changedpassword'],
            sectionFacets: [{ label: 'Manage Users', count: 2 }],
            actionFacets: [],
            userFacets: [{ label: 'Test User', count: 2 }]
        });

        const element = createComponent();
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table).not.toBeNull();
        expect(table.data.length).toBe(2);
    });

    it('keeps requesting further time slices until the page is filled', async () => {
        getContext.mockResolvedValue(CONTEXT);
        // Each call returns a single match, so the component must keep going
        // rather than stopping after the first sparse slice.
        let call = 0;
        search.mockImplementation(() => {
            call++;
            return Promise.resolve({
                rows: [buildRow(call)],
                cursor: buildCursor(call, call >= 3),
                scannedCount: 1000,
                scannedThroughMillis: NOW - call * 1000,
                done: call >= 3,
                observedSections: [],
                observedActions: [],
                sectionFacets: [],
                actionFacets: [],
                userFacets: []
            });
        });

        const element = createComponent();
        await flush();
        await flush();

        expect(search).toHaveBeenCalledTimes(3);
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data.length).toBe(3);
        // The cursor is opaque: the second call must echo the first one's
        // cursor exactly as the server returned it.
        expect(JSON.parse(search.mock.calls[1][0].cursorJson)).toEqual(buildCursor(1, false));
    });

    it('accumulates section and user facets across progressive load-more calls', async () => {
        getContext.mockResolvedValue(CONTEXT);

        // First call fills the page exactly (50 rows, matching PAGE_SIZE), so
        // the component's internal loop stops after one call even though
        // done is false - "Search further back" becomes available.
        const firstPage = Array.from({ length: 50 }, (_, i) => buildRow(i + 1));
        search.mockResolvedValueOnce({
            rows: firstPage,
            cursor: buildCursor(50, false),
            scannedCount: 50,
            scannedThroughMillis: NOW - 50 * 60000,
            done: false,
            observedSections: ['Manage Users'],
            observedActions: ['changedpassword'],
            // The server only computes facets over rows scanned in this one
            // call - the regression this test guards against is the client
            // blindly replacing its facets with only this.
            sectionFacets: [{ label: 'Manage Users', count: 50 }],
            actionFacets: [],
            userFacets: [{ label: 'Test User', count: 50 }]
        });

        const element = createComponent();
        await flush();

        const loadMoreButton = findButton(element, 'Search further back');
        expect(loadMoreButton).toBeTruthy();

        // Second call (triggered by clicking "Search further back") returns a
        // single row in a different section/user and finishes the search.
        search.mockResolvedValueOnce({
            rows: [{ ...buildRow(51), section: 'Apex Class', userName: 'Other User' }],
            cursor: buildCursor(51, true),
            scannedCount: 1,
            scannedThroughMillis: NOW - 51 * 60000,
            done: true,
            observedSections: ['Apex Class'],
            observedActions: [],
            sectionFacets: [{ label: 'Apex Class', count: 1 }],
            actionFacets: [],
            userFacets: [{ label: 'Other User', count: 1 }]
        });

        loadMoreButton.click();
        await flush();

        expect(search).toHaveBeenCalledTimes(2);
        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data.length).toBe(51);

        // Facets must reflect the entire accumulated 51-row result set, not
        // just the 1 row from the second call - both sections/users must be
        // present, ordered by count descending (the first call's 50 before
        // the second call's 1).
        const labels = Array.from(element.shadowRoot.querySelectorAll('.audit-facet-label')).map(
            (el) => el.textContent
        );
        expect(labels.slice(0, 2)).toEqual(['Manage Users', 'Apex Class']);
        expect(labels.slice(2, 4)).toEqual(['Test User', 'Other User']);
    });

    it('resets facets to only the new search results, not the previous search', async () => {
        getContext.mockResolvedValue(CONTEXT);
        search.mockResolvedValueOnce({
            rows: [buildRow(1)],
            cursor: buildCursor(1, true),
            scannedCount: 1,
            scannedThroughMillis: NOW,
            done: true,
            observedSections: ['Manage Users'],
            observedActions: [],
            sectionFacets: [{ label: 'Manage Users', count: 1 }],
            actionFacets: [],
            userFacets: [{ label: 'Test User', count: 1 }]
        });

        const element = createComponent();
        await flush();
        expect(element.shadowRoot.textContent).toContain('Manage Users');

        // A brand-new search (e.g. Reset) must not carry over facets from
        // the previous search's accumulated rows.
        search.mockResolvedValueOnce({
            rows: [{ ...buildRow(2), section: 'Apex Class', userName: 'Other User' }],
            cursor: buildCursor(2, true),
            scannedCount: 1,
            scannedThroughMillis: NOW,
            done: true,
            observedSections: ['Apex Class'],
            observedActions: [],
            sectionFacets: [{ label: 'Apex Class', count: 1 }],
            actionFacets: [],
            userFacets: [{ label: 'Other User', count: 1 }]
        });

        const resetButton = findButton(element, 'Reset');
        expect(resetButton).toBeTruthy();
        resetButton.click();
        await flush();

        const table = element.shadowRoot.querySelector('lightning-datatable');
        expect(table.data.length).toBe(1);
        const labels = Array.from(element.shadowRoot.querySelectorAll('.audit-facet-label')).map(
            (el) => el.textContent
        );
        expect(labels).toEqual(['Apex Class', 'Other User']);
        expect(element.shadowRoot.textContent).not.toContain('Manage Users');
    });

    it('hides the explorer when the user lacks View Setup', async () => {
        getContext.mockResolvedValue({ ...CONTEXT, canViewSetup: false });

        const element = createComponent();
        await flush();

        expect(element.shadowRoot.querySelector('lightning-datatable')).toBeNull();
        expect(element.shadowRoot.querySelector('lightning-input')).toBeNull();
        expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
        expect(search).not.toHaveBeenCalled();
        expect(element.shadowRoot.textContent).toContain('View Setup and Configuration');
        expect(findButton(element, 'Export CSV').disabled).toBe(true);
    });

    it('surfaces server errors instead of failing silently', async () => {
        getContext.mockResolvedValue(CONTEXT);
        search.mockRejectedValue({ body: { message: 'Permission required' } });

        const element = createComponent();
        await flush();

        expect(element.shadowRoot.textContent).toContain('Permission required');
    });

    it('neutralises formula injection in exported CSV cells', () => {
        // Audit descriptions echo admin-controlled text, so a value starting
        // with a formula trigger must not stay executable in Excel or Sheets.
        [
            '=1+1',
            '+1',
            '-1',
            '@SUM(A1)',
            '\tcmd',
            ' =1+1',
            '\u00a0=1+1',
            '\n=1+1',
            '\u200b=1+1',
            '\u0001=1+1',
            '\ufeff=1+1',
            // Full-width variants of the same four trigger characters
            // (some spreadsheet/IME environments normalize these to their
            // ASCII equivalents on paste/import), both bare and preceded by
            // a leading whitespace/control/zero-width character.
            '\uFF1D1+1',
            '\uFF0B1',
            '\uFF0D1',
            '\uFF20SUM(A1)',
            ' \uFF1D1+1',
            '\u200b\uFF1D1+1',
            '\u0001\uFF0B1'
        ].forEach((payload) => {
            expect(csvCell(payload)).toBe(`"'${payload}"`);
        });

        // Ordinary values must be left untouched, and quotes still escaped.
        expect(csvCell('Manage Users')).toBe('"Manage Users"');
        expect(csvCell('a "b" c')).toBe('"a ""b"" c"');
        expect(csvCell('')).toBe('""');
        expect(csvCell(null)).toBe('""');
        expect(csvRow(['a', '=b'])).toBe('"a","\'=b"');
    });

    // ---------- 1.0.1 fixes ----------

    describe('user filter pills', () => {
        it('removes a user when its pill is removed and drops it from the next search', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));

            const element = createComponent();
            await flush();
            expect(search).toHaveBeenCalledTimes(1);

            await addUserViaTypeAhead(element);
            let pills = element.shadowRoot.querySelector('lightning-pill-container');
            expect(pills).not.toBeNull();
            expect(pills.items).toEqual([{ label: USER.name, name: USER_ID }]);

            findButton(element, 'Search').click();
            await flush();
            expect(search).toHaveBeenCalledTimes(2);
            expect(parsedFilter(1).userIds).toEqual([USER_ID]);

            // lightning-pill-container's itemremove carries { item, index }.
            pills.dispatchEvent(new CustomEvent('itemremove', { detail: { item: { name: USER_ID }, index: 0 } }));
            await flush();

            pills = element.shadowRoot.querySelector('lightning-pill-container');
            expect(pills).toBeNull();
            expect(element.shadowRoot.textContent).toContain('Filters changed.');

            findButton(element, 'Search').click();
            await flush();
            expect(search).toHaveBeenCalledTimes(3);
            expect(parsedFilter(2).userIds).toEqual([]);
        });

        it('falls back to the pill index when the event has no item name', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));

            const element = createComponent();
            await flush();
            await addUserViaTypeAhead(element);

            const pills = element.shadowRoot.querySelector('lightning-pill-container');
            pills.dispatchEvent(new CustomEvent('itemremove', { detail: { index: 0 } }));
            await flush();

            expect(element.shadowRoot.querySelector('lightning-pill-container')).toBeNull();
        });
    });

    describe('filter snapshot', () => {
        it('reuses the filter of the running search for "Search further back"', async () => {
            getContext.mockResolvedValue(CONTEXT);
            const firstPage = Array.from({ length: 50 }, (_, i) => buildRow(i + 1));
            search.mockResolvedValueOnce(buildResult(firstPage, false, 50));

            const element = createComponent();
            await flush();
            expect(search).toHaveBeenCalledTimes(1);
            expect(element.shadowRoot.textContent).not.toContain('Filters changed.');

            // Edit a filter after the search has started.
            setInputValue(findInput(element, 'Search description, section or action'), 'permission');
            await flush();
            expect(element.shadowRoot.textContent).toContain('Filters changed.');
            const loadMore = findButton(element, 'Search further back');
            expect(loadMore).toBeTruthy();
            expect(loadMore.disabled).toBeFalsy();

            search.mockResolvedValueOnce(buildResult([buildRow(51)], true, 51));
            loadMore.click();
            await flush();

            expect(search).toHaveBeenCalledTimes(2);
            expect(search.mock.calls[1][0].filterJson).toBe(search.mock.calls[0][0].filterJson);
            expect(parsedFilter(1).searchText).toBe('');
            // The hint stays until a new search picks the edits up.
            expect(element.shadowRoot.textContent).toContain('Filters changed.');

            search.mockResolvedValueOnce(buildResult([buildRow(1)], true));
            findButton(element, 'Search').click();
            await flush();

            expect(search).toHaveBeenCalledTimes(3);
            expect(parsedFilter(2).searchText).toBe('permission');
            expect(element.shadowRoot.textContent).not.toContain('Filters changed.');
        });

        it('marks the filters dirty when sections change and applies them on the next Search', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue({
                ...buildResult([buildRow(1)], true),
                observedSections: ['Manage Users']
            });

            const element = createComponent();
            await flush();
            expect(search).toHaveBeenCalledTimes(1);
            expect(parsedFilter(0).sections).toEqual([]);

            const listbox = element.shadowRoot.querySelector('lightning-dual-listbox');
            expect(listbox).not.toBeNull();
            expect(listbox.options).toEqual([{ label: 'Manage Users', value: 'Manage Users' }]);
            expect(element.shadowRoot.textContent).not.toContain('Filters changed.');

            listbox.dispatchEvent(new CustomEvent('change', { detail: { value: ['Manage Users'] } }));
            await flush();
            expect(element.shadowRoot.textContent).toContain('Filters changed.');

            findButton(element, 'Search').click();
            await flush();

            expect(search).toHaveBeenCalledTimes(2);
            expect(parsedFilter(1).sections).toEqual(['Manage Users']);
            expect(element.shadowRoot.textContent).not.toContain('Filters changed.');
        });

        it('starts a new search when Enter is pressed in the search box', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));

            const element = createComponent();
            await flush();
            expect(search).toHaveBeenCalledTimes(1);

            const input = findInput(element, 'Search description, section or action');
            setInputValue(input, 'profile');
            await flush();

            // Any other key must not trigger a search.
            input.dispatchEvent(new KeyboardEvent('keyup', { key: 'a' }));
            await flush();
            expect(search).toHaveBeenCalledTimes(1);

            input.dispatchEvent(new KeyboardEvent('keyup', { key: 'Enter' }));
            await flush();
            expect(search).toHaveBeenCalledTimes(2);
            expect(parsedFilter(1).searchText).toBe('profile');
            expect(element.shadowRoot.textContent).not.toContain('Filters changed.');
        });
    });

    describe('filter payload', () => {
        it('sends lastDays and no explicit bounds for a preset range', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));

            createComponent();
            await flush();

            const filter = parsedFilter(0);
            expect(filter.lastDays).toBe(7);
            expect(filter).not.toHaveProperty('startDateMillis');
            expect(filter).not.toHaveProperty('endDateMillis');
            expect(filter.actions).toEqual([]);
            expect(filter.userIds).toEqual([]);
            expect(filter.sections).toEqual([]);
            expect(filter.searchText).toBe('');
        });

        it('sends explicit bounds for a custom range', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));

            const element = createComponent();
            await flush();

            const combobox = element.shadowRoot.querySelector('lightning-combobox');
            expect(combobox.options.find((o) => o.value === '1').label).toBe('Last 24 hours');
            combobox.value = 'custom';
            combobox.dispatchEvent(new CustomEvent('change', { detail: { value: 'custom' } }));
            await flush();

            const from = new Date(NOW - 3 * 86400000).toISOString();
            const to = new Date(NOW - 86400000).toISOString();
            setInputValue(findInput(element, 'From'), from);
            setInputValue(findInput(element, 'To'), to);
            findButton(element, 'Search').click();
            await flush();

            const filter = parsedFilter(1);
            expect(filter).not.toHaveProperty('lastDays');
            expect(filter.startDateMillis).toBe(new Date(from).getTime());
            expect(filter.endDateMillis).toBe(new Date(to).getTime());
        });

        it('sends a null end and a clamped default start when custom fields are blank', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));

            const element = createComponent();
            await flush();

            const combobox = element.shadowRoot.querySelector('lightning-combobox');
            combobox.dispatchEvent(new CustomEvent('change', { detail: { value: 'custom' } }));
            await flush();
            findButton(element, 'Search').click();
            await flush();

            let filter = parsedFilter(1);
            expect(filter.endDateMillis).toBeNull();
            expect(filter.startDateMillis).toBeGreaterThanOrEqual(NOW - 7 * 86400000);
            expect(filter.startDateMillis).toBeLessThanOrEqual(Date.now() - 7 * 86400000);

            // A start before the retention floor is clamped to the floor.
            setInputValue(findInput(element, 'From'), new Date(NOW - 400 * 86400000).toISOString());
            findButton(element, 'Search').click();
            await flush();
            filter = parsedFilter(2);
            expect(filter.startDateMillis).toBe(CONTEXT.retentionFloorMillis);
        });
    });

    describe('user type-ahead', () => {
        it('lists matching users that are not already selected', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));
            const other = { id: '005000000000002AAA', name: 'Bob Ops', username: 'bob@example.com' };

            const element = createComponent();
            await flush();
            await addUserViaTypeAhead(element);

            searchUsers.mockResolvedValue([USER, other]);
            setInputValue(findInput(element, 'Filter by user'), 'example');
            await flush();

            const results = Array.from(element.shadowRoot.querySelectorAll('.audit-user-result'));
            expect(results.map((r) => r.dataset.id)).toEqual([other.id]);
            expect(searchUsers).toHaveBeenLastCalledWith({ term: 'example' });
        });

        it('does not query for fewer than two characters', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));

            const element = createComponent();
            await flush();
            setInputValue(findInput(element, 'Filter by user'), 'j');
            await flush();

            expect(searchUsers).not.toHaveBeenCalled();
            expect(element.shadowRoot.querySelector('.audit-user-result')).toBeNull();
        });

        it('drops a stale response that arrives after the term changed', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));
            const stale = { id: '005000000000009AAA', name: 'Stale Match', username: 'stale@example.com' };

            let resolveFirst;
            searchUsers.mockImplementationOnce(
                () =>
                    new Promise((resolve) => {
                        resolveFirst = resolve;
                    })
            );
            searchUsers.mockResolvedValueOnce([USER]);

            const element = createComponent();
            await flush();
            const input = findInput(element, 'Filter by user');
            setInputValue(input, 'st');
            setInputValue(input, 'ja');
            await flush();

            expect(searchUsers).toHaveBeenCalledTimes(2);
            let results = Array.from(element.shadowRoot.querySelectorAll('.audit-user-result'));
            expect(results.map((r) => r.dataset.id)).toEqual([USER_ID]);

            // The first (older) request answers last; it must be ignored.
            resolveFirst([stale]);
            await flush();
            results = Array.from(element.shadowRoot.querySelectorAll('.audit-user-result'));
            expect(results.map((r) => r.dataset.id)).toEqual([USER_ID]);
        });

        it('surfaces a type-ahead failure', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([buildRow(1)], true));
            searchUsers.mockRejectedValue({ body: { message: 'User lookup failed' } });

            const element = createComponent();
            await flush();
            setInputValue(findInput(element, 'Filter by user'), 'ja');
            await flush();

            expect(element.shadowRoot.querySelector('.audit-user-result')).toBeNull();
            expect(element.shadowRoot.textContent).toContain('User lookup failed');
        });
    });

    describe('access tri-state', () => {
        it('shows a spinner and no form until getContext answers', async () => {
            getContext.mockReturnValue(new Promise(() => {}));

            const element = createComponent();
            await flush();

            const spinner = element.shadowRoot.querySelector('lightning-spinner');
            expect(spinner).not.toBeNull();
            expect(spinner.alternativeText).toBe('Loading');
            expect(element.shadowRoot.querySelector('lightning-input')).toBeNull();
            expect(element.shadowRoot.textContent).not.toContain('View Setup and Configuration');
            expect(findButton(element, 'Export CSV').disabled).toBe(true);
            expect(search).not.toHaveBeenCalled();
        });

        it('shows only the error, no form and no search, when getContext rejects', async () => {
            getContext.mockRejectedValue({ body: { message: 'Context unavailable' } });

            const element = createComponent();
            await flush();

            expect(element.shadowRoot.querySelector('[role="alert"]').textContent).toContain('Context unavailable');
            expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
            expect(element.shadowRoot.querySelector('lightning-input')).toBeNull();
            expect(element.shadowRoot.querySelector('lightning-combobox')).toBeNull();
            expect(findButton(element, 'Search')).toBeUndefined();
            expect(element.shadowRoot.textContent).not.toContain('View Setup and Configuration');
            expect(findButton(element, 'Export CSV').disabled).toBe(true);
            expect(search).not.toHaveBeenCalled();
        });

        it('enables Export CSV only once rows exist', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([], true));

            const element = createComponent();
            await flush();
            expect(findButton(element, 'Export CSV').disabled).toBe(true);

            search.mockResolvedValue(buildResult([buildRow(1)], true));
            findButton(element, 'Search').click();
            await flush();
            expect(findButton(element, 'Export CSV').disabled).toBe(false);
        });
    });

    describe('CSV export', () => {
        const OriginalBlob = global.Blob;
        let blobParts;
        let clickSpy;

        beforeEach(() => {
            blobParts = [];
            global.Blob = class CapturingBlob extends OriginalBlob {
                constructor(parts, options) {
                    super(parts, options);
                    blobParts.push(parts);
                }
            };
            let counter = 0;
            URL.createObjectURL = jest.fn(() => `blob:audit-${++counter}`);
            URL.revokeObjectURL = jest.fn();
            clickSpy = jest.spyOn(HTMLAnchorElement.prototype, 'click').mockImplementation(() => {});
        });

        afterEach(() => {
            // Detach first so disconnectedCallback runs against the mocks.
            while (document.body.firstChild) {
                document.body.removeChild(document.body.firstChild);
            }
            global.Blob = OriginalBlob;
            delete URL.createObjectURL;
            delete URL.revokeObjectURL;
            clickSpy.mockRestore();
        });

        it('prefixes the BOM and defers revoking the object URL', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([{ ...buildRow(1), display: 'Renamed field Prénom' }], true));

            const element = createComponent();
            await flush();
            const exportButton = findButton(element, 'Export CSV');
            expect(exportButton.disabled).toBe(false);

            exportButton.click();

            expect(clickSpy).toHaveBeenCalledTimes(1);
            expect(URL.createObjectURL).toHaveBeenCalledTimes(1);
            expect(blobParts).toHaveLength(1);
            const text = blobParts[0].join('');
            expect(text.startsWith('\uFEFF"Date",')).toBe(true);
            expect(text).toContain('Renamed field Prénom');
            // Revoking synchronously after click() can cancel the download.
            expect(URL.revokeObjectURL).not.toHaveBeenCalled();

            // The previous URL is released at the start of the next export...
            exportButton.click();
            expect(URL.createObjectURL).toHaveBeenCalledTimes(2);
            expect(URL.revokeObjectURL).toHaveBeenCalledTimes(1);
            expect(URL.revokeObjectURL).toHaveBeenCalledWith('blob:audit-1');

            // ...and the last one when the component leaves the page.
            document.body.removeChild(element);
            expect(URL.revokeObjectURL).toHaveBeenCalledTimes(2);
            expect(URL.revokeObjectURL).toHaveBeenLastCalledWith('blob:audit-2');
        });

        it('does nothing when there are no rows to export', async () => {
            getContext.mockResolvedValue(CONTEXT);
            search.mockResolvedValue(buildResult([], true));

            const element = createComponent();
            await flush();
            findButton(element, 'Export CSV').click();

            expect(URL.createObjectURL).not.toHaveBeenCalled();
            expect(clickSpy).not.toHaveBeenCalled();
        });
    });

    describe('search loop bounds', () => {
        it('stops after 25 calls and reports that more history remains', async () => {
            getContext.mockResolvedValue(CONTEXT);
            let call = 0;
            search.mockImplementation(() => {
                call++;
                return Promise.resolve(buildResult([buildRow(call)], false, call));
            });

            const element = createComponent();
            await settle(40);

            expect(search).toHaveBeenCalledTimes(25);
            expect(element.shadowRoot.querySelector('lightning-datatable').data.length).toBe(25);
            expect(element.shadowRoot.textContent).toContain('More history remains');
            expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
            expect(findButton(element, 'Search further back')).toBeTruthy();
            // Progress shows the loop examined one event per call.
            expect(element.shadowRoot.textContent).toContain('examined 25 events');
        });

        it('shows a Searching spinner while loading and ends the loop after Stop', async () => {
            getContext.mockResolvedValue(CONTEXT);
            let resolveFirst;
            search.mockImplementationOnce(
                () =>
                    new Promise((resolve) => {
                        resolveFirst = resolve;
                    })
            );
            search.mockImplementation(() => Promise.resolve(buildResult([buildRow(2)], false, 2)));

            const element = createComponent();
            await flush();

            expect(search).toHaveBeenCalledTimes(1);
            const spinner = element.shadowRoot.querySelector('lightning-spinner');
            expect(spinner).not.toBeNull();
            expect(spinner.alternativeText).toBe('Searching');
            expect(element.shadowRoot.querySelector('lightning-progress-bar')).toBeNull();
            expect(findButton(element, 'Search').disabled).toBe(true);

            const stopButton = findButton(element, 'Stop');
            expect(stopButton).toBeTruthy();
            stopButton.click();

            // The in-flight call completes, but no further call is made.
            resolveFirst(buildResult([buildRow(1)], false, 1));
            await settle(5);

            expect(search).toHaveBeenCalledTimes(1);
            expect(element.shadowRoot.querySelector('lightning-spinner')).toBeNull();
            expect(findButton(element, 'Stop')).toBeUndefined();
            expect(element.shadowRoot.textContent).toContain('More history remains');
            expect(findButton(element, 'Search further back')).toBeTruthy();
        });
    });
});
