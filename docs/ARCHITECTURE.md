# Architecture and Limitations

## Component diagram

```
Browser (Lightning Web Component: auditExplorer)
  |  imperative Apex (@AuraEnabled)
  v
AuditQueryController          Single external surface. Every method calls
  |                            AuditPermissionService before doing anything else.
  |                            Also issues one SOQL query directly, against the
  |                            standard User object, for the "changed by"
  |                            type-ahead (searchUsers) - see below.
  v
AuditQueryService             Progressive, time-sliced scan engine. Applies
  |                            filters SOQL cannot (Section, free-text search).
  v
AuditTrailProvider (interface)
  |
  v
SetupAuditTrailProvider       The only class that queries SetupAuditTrail.
  |
  v
SetupAuditTrail (standard, read-only Salesforce object)
```

`SetupAuditTrailProvider` is the only class that queries `SetupAuditTrail`,
but it is not the only class in the package that issues SOQL:
`AuditQueryController.searchUsers` runs a second, independent query directly
against the standard `User` object (`Id`, `Name`, `Username` only, for active
users, under `WITH USER_MODE`) to power the "changed by" filter's type-ahead.
See [`docs/PRIVACY.md`](PRIVACY.md#what-the-app-reads) for what that query
reads, why, and its permission gate; it is never persisted, cached, or
logged, same as everything else in this app.

Supporting types: `AuditFilter` (request), `AuditCursor` (keyset pagination
state), `AuditEventRow` (one flattened result row), `AuditSearchResult`
(one page of results + facets + cursor), `AuditPermissionService` (the
authorization gate), `MockAuditTrailProvider` (test double — `SetupAuditTrail`
rows cannot be inserted by Apex tests).

There is no trigger, scheduled job, batch job, platform event, custom object,
or custom setting anywhere in the package.

## Why progressive, time-sliced search

`SetupAuditTrail` is unusually restricted:

- `Section` and `Display` (the description) are **not filterable** in a SOQL
  `WHERE` clause, even though they are exactly what users want to search on.
- The object supports **no aggregate functions** — `COUNT()`, `GROUP BY`,
  `MIN(CreatedDate)`, etc. all fail.
- A large org can have a very long history within the 180-day retention
  window; naively pulling it all into Apex to filter would exceed the 50,000
  row SOQL limit and Apex heap limits.

`AuditQueryService.search()` therefore walks backwards through time in
bounded batches (`SCAN_BATCH` = 1,000 rows/query, up to `MAX_BATCHES_PER_CALL`
= 10 per call), pushes what SOQL _can_ filter (date range, `Action`,
`CreatedById`) into the query, applies `Section`/free-text filtering in Apex
over each batch, and returns as soon as a page is filled or the range is
exhausted — handing back an opaque cursor (`AuditCursor`) so the browser can
resume exactly where the server left off. Each call is a fresh transaction
with its own governor limits, so the total scan depth is bounded only by how
many times the client chooses to call `search()` again (bounded client-side
by `MAX_CALLS_PER_ACTION` = 25 calls per user action).

### Why the cursor tracks ids, not just a timestamp

A single metadata deployment or permission-set assignment can write many
`SetupAuditTrail` rows sharing the exact same `CreatedDate` (down to the
second). Paging by date alone would either skip or duplicate rows at that
boundary. `AuditCursor` therefore carries both the last timestamp seen and
the set of ids already consumed at that exact timestamp, and the query
excludes those ids explicitly (`AND Id NOT IN :excludeIds`). This is pinned by
`AuditQueryServiceTest.handlesManyRowsSharingOneTimestamp` and was additionally
validated against real data (122 records over 18 pages, 0 duplicates/skips).

## Known limitations

- **180-day retention.** Salesforce does not retain Setup Audit Trail data
  longer than 180 days; the app cannot show anything older and clamps every
  request to that floor. Longer retention would require an opt-in archiving
  add-on (not part of this package), because it would require storage this
  package deliberately does not use.
- **Lightning Experience only.** The UI is a Lightning web component; there is
  no Aura/Visualforce/Classic equivalent.
- **Professional Edition is not supported**, because it cannot run custom
  Apex, which this package requires.
- **No counts/aggregates from the platform.** "Top sections"/"Top users" are
  computed in Apex over the rows scanned so far in the current search, not
  over the org's entire audit history — a search that has only scanned back
  30 days shows facets for those 30 days, not all 180.
- **A single scan is not a single query.** For a sparse filter (for example,
  a rare search term) over a long date range, the client may need to make
  several sequential `search()` calls to fill one page, because the
  server-side scan ceiling per call is intentionally bounded to protect
  governor limits. The UI's progress indicator ("examined N events back to
  &lt;date&gt;") reflects this.
- **Type-ahead user search (`searchUsers`) is capped at 20 results** and
  requires at least 2 characters, to bound both the query and the risk of
  using the endpoint as a general user-enumeration tool.

## Packaging

This package is currently distributed as an **unlocked beta package** with no
namespace (`sfdx-project.json` → `"namespace": ""`). An unlocked package
cannot be converted in place into a namespaced managed (2GP) package — that
requires linking a namespace to the Dev Hub used to create a _new_ managed
package, which is an org/Dev Hub configuration step outside this repository.

A namespace (`atexplorer`) has been registered, but is not yet linked to the
Dev Hub used for packaging. Linkage is currently blocked by a platform-level
defect in the SalesforceDX Namespace Registry's OAuth/PKCE flow (not a
configuration error in this org or repository), which is the current blocker
for creating that new managed package. See
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for the verified
install/test evidence and the exact steps remaining before
an AppExchange managed-package listing can be created.
