# Audit Trail Explorer

A Salesforce app that gives admins and auditors a fast, filterable UI over the
**Setup Audit Trail** — with **zero storage footprint**.

## What it does

- Search 180 days of setup/config changes by **description text, section, user and date range**
- Streaming results with live progress ("examined 4,300 events back to 12 May")
- Top sections / top users breakdown over the matched results
- Row detail (delegate user, namespace, context, issuer)
- One-click CSV export of the current result set

## Why it costs nothing to run

The app reads Salesforce's own `SetupAuditTrail` object directly. There is:

- no custom object, Big Object or file storage
- no scheduled job, trigger or background process
- nothing that counts against any org allocation

It is entirely read-only.

## The constraints this works around

`SetupAuditTrail` is unusually limited, which is why a plain SOQL-backed list view
isn't enough. Verified against a live org:

| Field | Filterable in SOQL |
| --- | --- |
| `CreatedDate`, `Action`, `CreatedById` | yes |
| **`Section`** | **no** |
| **`Display`** (description) | **no** |

It also supports **no aggregate functions** — `COUNT(Id)`, `MIN(CreatedDate)` and
`GROUP BY` all fail.

So the two fields users most want to search on cannot be filtered by the database,
and no counts can be computed by the database. Naively loading six months of audit
data into Apex to filter it would exceed the 50,000 SOQL row and heap limits in any
large org.

**Solution: progressive, time-sliced search.** `AuditQueryService` walks backwards
through time in bounded batches, pushes what it can into SOQL (date, action, user),
applies the rest in Apex, and returns as soon as a page is filled — handing back a
cursor so the client can resume. Each call is its own transaction with a hard scan
ceiling, so governor limits never bind no matter how much history the org has.

The cursor tracks both the timestamp **and** the ids already consumed at that
timestamp, because a single metadata deployment writes many audit rows sharing one
timestamp — date-only paging would skip or duplicate them.

## Retention

Salesforce keeps Setup Audit Trail for **180 days**; older data is permanently gone.
The app clamps every request to that floor and states the limit in the UI. Retention
beyond 180 days requires archiving, which is planned as an **opt-in** add-on so orgs
that don't need it never pay for storage.

## Install

```bash
sf org login web --alias my-org
sf project deploy start --source-dir force-app --target-org my-org
sf org assign permset --name Audit_Trail_Viewer --target-org my-org
```

Then open the **Audit Trail Explorer** app from the App Launcher.

The `Audit Trail Viewer` permission set grants "View Setup and Configuration"
(and its `ViewRoles` dependency), which Salesforce requires to read the audit trail.

## Development

```bash
npm install
npm run test:unit                                   # LWC Jest tests
sf project deploy start --source-dir force-app --test-level RunLocalTests
```

### Layout

| Path | Purpose |
| --- | --- |
| `classes/AuditQueryService.cls` | Progressive search engine |
| `classes/AuditQueryController.cls` | `@AuraEnabled` facade |
| `classes/AuditTrailProvider.cls` | Data-source seam (`SetupAuditTrail` rows can't be inserted in tests) |
| `classes/AuditPermissionService.cls` | "View Setup and Configuration" check |
| `lwc/auditExplorer` | The UI |
