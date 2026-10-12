# Architecture and Limitations

## Component diagram

```
Browser (Lightning Web Component: auditExplorer)
  |  imperative Apex (@AuraEnabled)
  v
AuditQueryController          Single external surface. The two data-returning
  |                            methods, search and searchUsers, call
  |                            AuditPermissionService before doing anything
  |                            else. getContext is ungated by design: it returns
  |                            retention constants, the server time, the default
  |                            page size and the caller's own canViewSetup
  |                            flag - no audit or user data.
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
exhausted — handing back a cursor (`AuditCursor`) so the browser can resume
where the server left off. Each call is a fresh transaction with its own
governor limits, so the total scan depth is bounded only by how many times
the client chooses to call `search()` again (bounded client-side by
`MAX_CALLS_PER_ACTION` = 25 calls per user action).

The cursor is not opaque. It is plain JSON (`lastDateMillis`,
`seenIdsAtLastDate`, `exhausted`) that the browser keeps between calls and
sends back as-is (`auditExplorer.js:219,237`), so the client can read and
modify it. The server therefore treats it as untrusted input: at most
`MAX_SEEN_IDS` = 5,000 ids are copied into the query bind, and any entry that
is not a well-formed `Id` is skipped rather than allowed to throw
(`AuditCursor.cls:11-17,45-61`). A modified cursor changes only where the
caller's own next query starts and which ids it excludes; that query still
runs under `USER_MODE` for the running user, and every call is still gated by
`assertCanViewSetup()` first.

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
- **Editions without custom Apex are not supported**, because this package
  requires it. That covers **Professional Edition** and **Base Edition**; a
  Base Edition install fails at `Missing feature: Apex Classes`.
- **No counts/aggregates from the platform.** Nothing is counted by SOQL.
  Apex tallies, per `search()` call, only the rows that matched the filter in
  that call (`AuditQueryService.cls:98-102`) and returns them as
  `sectionFacets`/`actionFacets`/`userFacets` (`AuditSearchResult.cls:25-31`).
  The browser does not use those server tallies: it recomputes "Top
  sections"/"Top users" over every matched row accumulated in the page so far,
  across all calls of the current search (`auditExplorer.js:242-249`). The
  facets therefore describe the result set on screen — matched rows within the
  range scanned so far — not every row examined and not the org's entire audit
  history: a search that has scanned back 30 days shows facets for its matches
  in those 30 days, not all 180. Separately, the "Sections" filter options are
  discovered from every row scanned, matched or not (`observedSections`,
  `AuditQueryService.cls:88-90`, merged at `auditExplorer.js:241,267-284`).
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

This package is distributed as a **released managed (2GP) version** under the
`atexplorer` namespace (`sfdx-project.json` → `"namespace": "atexplorer"`,
package `0Hohm0000000NHZCA2`, current version `1.0.0.2` /
`04thm000002OtQPAA0`, promoted 2026-09-09). "Released" is the Salesforce
packaging state — the version installs into any org type including
production. The package has not been submitted for or passed AppExchange
Security Review and has no AppExchange listing.

The earlier **unlocked** lineage (`0Hobm0000005681CAA`) is superseded. An
unlocked package cannot be converted in place into a namespaced managed
package, so the managed lineage was created fresh from the same source once
the `atexplorer` namespace was linked to the packaging Dev Hub. The managed
lineage is permanently bound to that Dev Hub.

### Managed packaging strips system permissions

Salesforce removes system permissions from a managed package's permission
sets on install, as an anti-privilege-escalation measure. The shipped
`Audit_Trail_Viewer` permission set therefore **cannot** grant `ViewSetup` to
subscribers of the managed package, even though the source declares it; it
still grants the app, its tab, and its Apex classes. Subscriber
administrators must grant **View Setup and Configuration** separately. The
same permission set remains self-sufficient for source deploys and the
unlocked package, so this constraint is specific to managed installs. See
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for the verified
install/test evidence and the exact steps remaining before
an AppExchange managed-package listing can be created.
