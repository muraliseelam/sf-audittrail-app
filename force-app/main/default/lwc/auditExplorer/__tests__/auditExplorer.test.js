import { createElement } from 'lwc';
import AuditExplorer from 'c/auditExplorer';
import { csvCell, csvRow } from '../csv';
import getContext from '@salesforce/apex/AuditQueryController.getContext';
import search from '@salesforce/apex/AuditQueryController.search';

jest.mock('@salesforce/apex/AuditQueryController.getContext', () => ({ default: jest.fn() }), { virtual: true });
jest.mock('@salesforce/apex/AuditQueryController.search', () => ({ default: jest.fn() }), {
    virtual: true
});
jest.mock('@salesforce/apex/AuditQueryController.searchUsers', () => ({ default: jest.fn() }), {
    virtual: true
});

const CONTEXT = {
    retentionDays: 180,
    retentionFloorMillis: Date.now() - 180 * 86400000,
    nowMillis: Date.now(),
    canViewSetup: true,
    defaultPageSize: 50
};

function buildRow(index) {
    return {
        recordId: `0Ym00000000000${index}`,
        eventDateMillis: Date.now() - index * 60000,
        section: 'Manage Users',
        action: 'changedpassword',
        display: `Event ${index}`,
        userName: 'Test User'
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
            cursor: { lastDateMillis: Date.now(), seenIdsAtLastDate: [] },
            scannedCount: 2,
            scannedThroughMillis: Date.now(),
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
                cursor: { lastDateMillis: Date.now() - call * 1000, seenIdsAtLastDate: [] },
                scannedCount: 1000,
                scannedThroughMillis: Date.now() - call * 1000,
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
    });

    it('accumulates section and user facets across progressive load-more calls', async () => {
        getContext.mockResolvedValue(CONTEXT);

        // First call fills the page exactly (50 rows, matching PAGE_SIZE), so
        // the component's internal loop stops after one call even though
        // done is false - "Search further back" becomes available.
        const firstPage = Array.from({ length: 50 }, (_, i) => buildRow(i + 1));
        search.mockResolvedValueOnce({
            rows: firstPage,
            cursor: { lastDateMillis: Date.now() - 50 * 60000, seenIdsAtLastDate: [] },
            scannedCount: 50,
            scannedThroughMillis: Date.now() - 50 * 60000,
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

        const loadMoreButton = Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(
            (button) => button.label === 'Search further back'
        );
        expect(loadMoreButton).toBeTruthy();

        // Second call (triggered by clicking "Search further back") returns a
        // single row in a different section/user and finishes the search.
        search.mockResolvedValueOnce({
            rows: [{ ...buildRow(51), section: 'Apex Class', userName: 'Other User' }],
            cursor: { lastDateMillis: Date.now() - 51 * 60000, seenIdsAtLastDate: [] },
            scannedCount: 1,
            scannedThroughMillis: Date.now() - 51 * 60000,
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
            cursor: { lastDateMillis: Date.now(), seenIdsAtLastDate: [] },
            scannedCount: 1,
            scannedThroughMillis: Date.now(),
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
            cursor: { lastDateMillis: Date.now(), seenIdsAtLastDate: [] },
            scannedCount: 1,
            scannedThroughMillis: Date.now(),
            done: true,
            observedSections: ['Apex Class'],
            observedActions: [],
            sectionFacets: [{ label: 'Apex Class', count: 1 }],
            actionFacets: [],
            userFacets: [{ label: 'Other User', count: 1 }]
        });

        const resetButton = Array.from(element.shadowRoot.querySelectorAll('lightning-button')).find(
            (button) => button.label === 'Reset'
        );
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
        expect(search).not.toHaveBeenCalled();
        expect(element.shadowRoot.textContent).toContain('View Setup and Configuration');
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
});
