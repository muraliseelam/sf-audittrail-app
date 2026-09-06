# Privacy and Data Handling

Audit Trail Explorer is a **read-only viewer** over data your org already has.
It does not collect, store, or transmit any data of its own.

## What the app reads

The standard Salesforce `SetupAuditTrail` object — the same setup/configuration
change history visible (in a much less usable form) under
**Setup → Audit Trail** in every org. This can include the display names and
usernames of users who made setup changes, and human-readable descriptions of
those changes (for example, "Changed profile Sales User").

## What the app does _not_ do

| Question                                                                                                   | Answer                                                                                                                               |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Does it create a custom object, Big Object, or file to store data?                                         | No.                                                                                                                                  |
| Does it write, cache, or log audit data server-side beyond the standard debug log?                         | No. Only unexpected _exception_ type/message is written to the debug log (see below); no audit row content is ever logged.           |
| Does it make an external HTTP callout, or is it configured with a named credential or remote site setting? | No.                                                                                                                                  |
| Does it send data to Salesforce, the package publisher, or any third party for analytics/telemetry?        | No. The package contains no telemetry of any kind.                                                                                   |
| Does it use browser storage (`localStorage`, cookies, IndexedDB) to persist audit data?                    | No. All state lives in the component's in-memory JavaScript for the duration of the page view and is discarded on navigation/reload. |
| Does uninstalling the package leave data behind?                                                           | No. Because nothing is stored, there is nothing to clean up.                                                                         |

## CSV export

The **Export CSV** button builds a file entirely in the browser from the rows
already loaded into the page (`Blob` + `URL.createObjectURL`); the file is
never uploaded anywhere. It is written to the location your browser saves
downloads to, under your organization's normal device and browser security
policies — the app has no visibility into or control over that file once it
is downloaded.

Exported cells are escaped to prevent spreadsheet formula/CSV injection when
the file is opened in Excel, Google Sheets, or similar tools (see
`force-app/main/default/lwc/auditExplorer/csv.js`), which is a security
control, not a data-handling one — no data is altered or removed, only quoted
so it cannot be interpreted as an executable formula.

## Access control

Nothing above changes who can _see_ the data. The app enforces the same
"View Setup and Configuration" permission Salesforce itself requires to view
the Setup Audit Trail (see `AuditPermissionService`), and every SOQL query
runs in `USER_MODE`/`WITH USER_MODE`, so field- and object-level security are
enforced by the platform for the running user. The app cannot show a user
audit data they could not already see via Setup.

## Retention

Salesforce retains Setup Audit Trail entries for 180 days; the app cannot
show, and does not attempt to reconstruct, anything older. See
[`docs/ARCHITECTURE.md`](ARCHITECTURE.md) for how retention is enforced.

## Opt-in future analytics

Any future adoption/usage analytics for this package (for example, via
AppExchange/License Management App analytics rather than custom telemetry)
will be **opt-in**, will not include audit row content, and will be documented
here before being enabled.

## Questions

Open a GitHub issue for general privacy questions, or see
[SECURITY.md](../SECURITY.md) for how to report a security concern privately.
