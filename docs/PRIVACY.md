# Privacy and Data Handling

Audit Trail Explorer is a **read-only viewer** over data your org already has.
It does not collect, store, or transmit any data of its own.

## What the app reads

The standard Salesforce `SetupAuditTrail` object — the same setup/configuration
change history visible (in a much less usable form) under
**Setup → Audit Trail** in every org. This can include the display names and
usernames of users who made setup changes, and human-readable descriptions of
those changes (for example, "Changed profile Sales User").

**Fields the audit query selects.** The production query
(`force-app/main/default/classes/SetupAuditTrailProvider.cls:18-19`) selects
eleven fields. Every selected field is copied into the row object sent to the
browser (`AuditEventRow.cls:37-49`); the table shows which of them the UI
renders and which the CSV export writes.

| Field selected               | What it holds (as recorded by Salesforce)                | Results table | Detail panel  | CSV export      |
| ---------------------------- | -------------------------------------------------------- | ------------- | ------------- | --------------- |
| `Id`                         | Record id of the audit row                               | Row key only  | No            | No              |
| `CreatedDate`                | When the change was made                                 | Date          | Date          | Date (ISO 8601) |
| `Section`                    | Setup area the change belongs to                         | Section       | Section       | Section         |
| `Action`                     | Salesforce's action code for the change                  | Action        | Action        | Action          |
| `Display`                    | Human-readable description of the change                 | Description   | Description   | Description     |
| `CreatedById`                | Id of the user who made the change                       | No            | No            | No              |
| `CreatedBy.Name`             | Display name of that user                                | User          | User          | User            |
| `DelegateUser`               | Login-As user who acted on another user's behalf, if any | No            | Delegate user | Delegate User   |
| `ResponsibleNamespacePrefix` | Namespace of the managed package responsible, if any     | No            | Namespace     | Namespace       |
| `CreatedByContext`           | Context Salesforce recorded for the change, if any       | No            | No            | No              |
| `CreatedByIssuer`            | Issuer Salesforce recorded for that context, if any      | No            | No            | No              |

Three of the selected fields — `CreatedById`, `CreatedByContext` and
`CreatedByIssuer` — are returned to the browser in every row but are never
displayed or exported; nothing in the component reads them. `Id` is used only
as the row key of the results table (`auditExplorer.html:190`). The rendered
columns are defined at `auditExplorer.js:7-26`, the detail panel at
`auditExplorer.html:212-254` and the export columns at
`auditExplorer.js:454-466`.

**User type-ahead.** The "Filter by user" field also queries the standard
`User` object — `Id`, `Name`, and `Username` only, for **active users**
matching what the caller typed (`AuditQueryController.searchUsers`, backed by
a `SELECT ... FROM User ... WITH USER_MODE` query). This exists solely so the
caller can pick a person to filter the audit search by, without needing to
already know that user's Id. It is gated behind the same "View Setup and
Configuration" check as the audit data itself (so it cannot be used as a
general user-directory lookup by someone who shouldn't have access to the
audit trail in the first place), runs under `USER_MODE` so field-level
security on `User` is enforced for the running user, requires at least 2
characters of input, returns at most 20 matches, and — like everything else
in this app — the results are used only to render the UI and are never
stored or logged. They are not cached in either direction: the server
performs no caching of its own (no Platform Cache, no custom object, nothing
kept between calls), and `searchUsers` is declared
`@AuraEnabled(cacheable=false)` (`AuditQueryController.cls:59`), as are
`search` and `getContext` (`AuditQueryController.cls:21,40`), so the Lightning
client-side action cache is not used and no result is ever served from it.
The list lives only in the component's in-memory state while the page is
open.

## What the app does _not_ do

| Question                                                                                                   | Answer                                                                                                                                                                                                                                                                                                                                                                    |
| ---------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Does it create a custom object, Big Object, or file to store data?                                         | No.                                                                                                                                                                                                                                                                                                                                                                       |
| Does it write, cache, or log audit data server-side beyond the standard debug log?                         | No. Nothing is cached on the server, and none of the three `@AuraEnabled` methods is cacheable (`AuditQueryController.cls:21,40,59`), so the Lightning client-side action cache holds no audit or user data either. Only an unexpected _exception_'s type and message are written to the debug log (`AuditQueryController.cls:110`); no audit row content is ever logged. |
| Does it make an external HTTP callout, or is it configured with a named credential or remote site setting? | No.                                                                                                                                                                                                                                                                                                                                                                       |
| Does it send data to Salesforce, the package publisher, or any third party for analytics/telemetry?        | No. The package contains no telemetry of any kind.                                                                                                                                                                                                                                                                                                                        |
| Does it use browser storage (`localStorage`, cookies, IndexedDB) to persist audit data?                    | No. All state lives in the component's in-memory JavaScript for the duration of the page view and is discarded on navigation/reload.                                                                                                                                                                                                                                      |
| Does uninstalling the package leave data behind?                                                           | No. Because nothing is stored, there is nothing to clean up.                                                                                                                                                                                                                                                                                                              |

## CSV export

The **Export CSV** button builds a file entirely in the browser from the rows
already loaded into the page (`Blob` + `URL.createObjectURL`); the file is
never uploaded anywhere. It is written to the location your browser saves
downloads to, under your organization's normal device and browser security
policies — the app has no visibility into or control over that file once it
is downloaded. The file starts with the UTF-8 byte-order mark so that Excel on
Windows decodes it as UTF-8 (`auditExplorer.js:45-46,471`); the mark is an
encoding signal ahead of the quoted header cell, not data, and no cell content
depends on it.

Exported cells are escaped to prevent spreadsheet formula/CSV injection when
the file is opened in Excel, Google Sheets, or similar tools (see
`force-app/main/default/lwc/auditExplorer/csv.js`). This is a security
control, not a data-handling one, and it changes the exported text in exactly
one way. Every cell is wrapped in double quotes with any embedded double quote
doubled, which is standard CSV quoting and loses nothing. In addition, a cell
whose first character is a formula trigger (`=`, `+`, `-`, `@`, or their
full-width forms), a whitespace character, a C0 control character or a
zero-width space gets a single apostrophe (`'`) prepended (`csv.js:25-47`).
That apostrophe is the only modification. It is there because spreadsheets
treat such a leading character as the start of a formula, and audit
descriptions echo text an administrator controls (for example a renamed field
label), so without the prefix an exported cell could execute on the auditor's
machine when the file is opened. The prefix is visible in the exported file;
no value is removed, truncated or reordered, and the data shown in the page
is untouched.

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
