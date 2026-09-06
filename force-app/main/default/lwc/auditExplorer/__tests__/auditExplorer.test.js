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
            '\ufeff=1+1'
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
