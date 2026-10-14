# Architecture and Limitations

## Component diagram

```
Browser (Lightning Web Component: auditExplorer)
  |  imperative Apex (@AuraEnabled, all three methods cacheable=false)
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
  |                            Every catchable exception leaves as
  |                            AuraHandledException - see "Error contract".
  v
AuditQueryService             Progressive, time-sliced scan engine. Resolves
  |                            and pins the date range, pages by keyset on
  |                            (CreatedDate, Id), and applies the filters SOQL
  |                            cannot (Section, bounded free-text search).
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
reads, why, and its permission gate. Its results are never persisted or
logged, and they are not cached in either direction: the server keeps nothing
between calls, and `searchUsers` is declared `cacheable=false`
(`AuditQueryController.cls:59`), as are `search` and `getContext`
(`AuditQueryController.cls:21,40`), so the Lightning client-side action cache
is never used.

Supporting types: `AuditFilter` (request), `AuditCursor` (keyset position plus
the pinned date range), `AuditEventRow` (one flattened result row),
`AuditSearchResult` (one page of results + facets + cursor),
`AuditPermissionService` (the authorization gate), `MockAuditTrailProvider`
(test double — `SetupAuditTrail` rows cannot be inserted by Apex tests).

There is no trigger, scheduled job, batch job, platform event, custom object,
custom setting or cache partition anywhere in the package, and the Apex uses
no Platform Cache: nothing is kept server-side between calls.

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
bounded batches (`scanBatch` = 1,000 rows per query, up to
`maxBatchesPerCall` = 10 queries per call; `AuditQueryService.cls:34-37`),
pushes what SOQL _can_ filter (date range, `Action`, `CreatedById` and the
keyset position) into the query, applies the `Section` and free-text filters
in Apex over each batch, and returns as soon as a page is filled or the range
is exhausted — handing back a cursor (`AuditCursor`) so the browser can resume
where the server left off. Each call is a fresh transaction with its own
governor limits, so the total scan depth is bounded only by how many times
the client chooses to call `search()` again (bounded client-side by
`MAX_CALLS_PER_ACTION` = 25 calls per user action, `auditExplorer.js:43`).
Tests shrink both scan values through `@TestVisible` to exercise the
multi-batch and per-call-ceiling paths with a few hundred mock rows
(`AuditQueryServiceTest.multiBatchScanFindsAMatchInTheLastShortBatch`,
`ceilingStopsACallWithoutLosingProgress`).

### The date range is resolved on the server and pinned

The browser sends either `lastDays` (the preset ranges) or explicit
`startDateMillis`/`endDateMillis` (a custom range) — never both in effect
(`AuditFilter.cls:10-22`, `auditExplorer.js:198-218`). On the first call of a
search, `pinRange()` resolves the window from the server clock: a positive
`lastDays` gives end = now and start = now minus min(`lastDays`, 180);
otherwise the explicit dates apply, a null end meaning now, and the start is
clamped to the retention floor (`AuditQueryService.cls:200-211`). The result
is written into the cursor as `rangeStartMillis`/`rangeEndMillis`, and every
continuation pages over exactly that window, so a stale or skewed browser
clock cannot widen it and the lower bound cannot drift between pages. Pinned
by `lastDaysUsesServerClockAndPinsRange`, `lastDaysIsCappedAtTheRetentionWindow`
and `exhaustedScanReportsRangeBoundary`. Independently, the browser snapshots
the filter when a search starts and reuses it verbatim for every "Search
further back" call (`activeFilterJson`, `auditExplorer.js:72-76,268-273`),
showing a "Filters changed" hint while edits are pending.

### Keyset paging on (CreatedDate, Id)

A single metadata deployment or permission-set assignment can write many
`SetupAuditTrail` rows sharing the exact same `CreatedDate` (down to the
second). Paging by date alone would skip or duplicate rows at that boundary.
Rows are therefore read in `ORDER BY CreatedDate DESC, Id DESC`
(`SetupAuditTrailProvider.cls:35`) and the cursor records the last consumed
(`lastDateMillis`, `lastId`) pair (`AuditCursor.cls:40-44`). A continuation
query sets its upper bound to that timestamp and adds
`AND (CreatedDate < :upperBound OR Id < :lastId)`
(`SetupAuditTrailProvider.cls:26-28`), so it resumes strictly after the pair:
rows older than the timestamp, plus rows at the same timestamp with a smaller
id. Because the id is part of the sort key there is no list of already-seen
ids to carry, no cap on how many rows one timestamp may hold, and the cursor
stays a fixed size. Within one call the service advances between batches the
same way (`AuditQueryService.cls:162-166`). This is pinned by
`AuditQueryServiceTest.handlesManyRowsSharingOneTimestamp` and
`sameTimestampRowsPageByIdAcrossBatches` (the mock provider sorts and resumes
by the same contract), and
`SetupAuditTrailProviderTest.realQueryExecutesWithEveryOptionalFilter`
executes the `Id < :lastId` predicate against the real object.

### The cursor is untrusted input

The cursor is not opaque. It is plain JSON (`lastDateMillis`, `lastId`,
`rangeStartMillis`, `rangeEndMillis`, `exhausted`; `AuditCursor.cls:21-30`)
that the browser keeps between calls and sends back as-is
(`auditExplorer.js:293,311`), so the client can read and modify it. The server
therefore validates it on every call (`AuditQueryService.cls:67-93`):

- A cursor with no position, or a positioned cursor missing either pinned
  bound (only a hand-built payload looks like that; the client always
  round-trips the whole cursor), starts the search afresh instead of resuming
  (`AuditQueryService.cls:67-72`;
  `continuationCursorMissingRangeRestartsTheSearch`).
- The pinned bounds are re-clamped rather than trusted: the lower bound is
  raised to the retention floor computed on the server, and the upper bound
  is the lower of the cursor position and the pinned range end
  (`AuditQueryService.cls:84-93`;
  `continuationBoundsAreReclampedFromAnUntrustedCursor`).
- A positioned cursor whose `lastId` is blank, not a well-formed `Id`, or not
  a `SetupAuditTrail` id is rejected before any query runs:
  `AuditCursor.lastIdValue()` throws (`AuditCursor.cls:53-65`) and the
  controller turns that into the generic client error with no internal detail
  (`malformedContinuationCursorIsRejected`,
  `blankIdOnPositionedCursorIsRejected`, `cursorIdOfAnotherObjectIsRejected`,
  `AuditQueryControllerTest.searchHidesInternalErrorDetail`).

A modified cursor can therefore change only where the caller's own next query
starts, within at most the window a fresh search could already request and
never below the retention floor; that query still runs under `USER_MODE` for
the running user, and every call is still gated by `assertCanViewSetup()`
first.

### Filters applied in Apex

`Section` is a case-insensitive set match (`AuditQueryService.cls:275`). The
free-text filter is bounded on purpose, because it runs once per scanned row
and a call may scan up to 10,000 rows: only the first 200 characters of
`searchText` and the first 10 whitespace-separated terms are honoured
(`MAX_SEARCH_TEXT_LENGTH`, `MAX_SEARCH_TERMS`;
`AuditQueryService.cls:47-48,260-271`). All terms must appear in the row's
description, section, action or user name; null fields are dropped before the
haystack is built, so the term "null" cannot match an empty field
(`AuditQueryService.cls:287-289`). Pinned by
`searchTextIsTruncatedToTwoHundredCharacters`,
`searchTextHonoursOnlyTheFirstTenTerms` and
`blankFieldDoesNotMatchTheWordNull`.

## Error contract

Every `@AuraEnabled` entry point — `search`, `getContext` and `searchUsers` —
is wrapped in a try/catch, and every catchable exception leaves it as an
`AuraHandledException` (`AuditQueryController.cls:21-95`); a governor-limit
`System.LimitException` cannot be caught in Apex, which is one reason each call's
work is bounded. The permission failure
(`AuditPermissionService.AuditPermissionException`) passes its user-facing
text through, so the browser can say which permission is missing; every other
exception — including a JSON deserialization failure and the malformed-cursor
rejection above — is collapsed to one fixed generic message, with the
exception type and message written only to the server-side debug log
(`AuditQueryController.cls:101-117`). Both paths call `setMessage()`, without
which the client would see only "Script-thrown exception". `getContext` is
ungated and answers `canViewSetup` false for an unprivileged user rather than
throwing, but its body is wrapped the same way
(`AuditQueryController.cls:40-56`). Pinned by
`AuditPermissionServiceTest.blocksControllerEntryPointsForUnprivilegedUser`
(which asserts that the message names View Setup and Configuration),
`restrictedUserGetContextReportsNoAccessWithoutThrowing`,
`AuditQueryControllerTest.searchHidesInternalErrorDetail` and
`searchHidesDeserializationFailureDetail`.

## Known limitations

- **180-day retention.** Salesforce does not retain Setup Audit Trail data
  longer than 180 days; the app cannot show anything older and clamps every
  request to that floor. Longer retention would require an opt-in archiving
  add-on (not part of this package), because it would require storage this
  package deliberately does not use.
- **Lightning Experience only.** The UI is a Lightning web component; there is
  no Aura/Visualforce/Classic equivalent.
- **Supported editions** are Enterprise, Unlimited, Performance and Developer.
  **Professional** and **Group Edition** are not supported and have not been
  tested; a **Base Edition** install fails at `Missing feature: Apex Classes`.
- **No counts/aggregates from the platform.** Nothing is counted by SOQL.
  Apex tallies, per `search()` call, only the rows that matched the filter in
  that call (`AuditQueryService.cls:142-146`) and returns them as
  `sectionFacets`/`actionFacets`/`userFacets` (`AuditSearchResult.cls:25-31`).
  The browser does not use those server tallies: it recomputes "Top
  sections"/"Top users" over every matched row accumulated in the page so far,
  across all calls of the current search (`auditExplorer.js:316-323`). The
  facets therefore describe the result set on screen — matched rows within the
  range scanned so far — not every row examined and not the org's entire audit
  history: a search that has scanned back 30 days shows facets for its matches
  in those 30 days, not all 180. Separately, the "Sections" filter options are
  discovered from every row scanned, matched or not (`observedSections`,
  `AuditQueryService.cls:136,179-183`, merged at
  `auditExplorer.js:315,341-358`).
- **A single scan is not a single query.** For a sparse filter (for example,
  a rare search term) over a long date range, the client may need to make
  several sequential `search()` calls to fill one page, because the
  server-side scan ceiling per call is intentionally bounded to protect
  governor limits. The UI's progress indicator ("examined N events back to
  &lt;date&gt;") reflects this.
- **Free-text search is bounded.** Only the first 200 characters and the first
  10 terms of the search text take part in matching (see "Filters applied in
  Apex"); anything beyond those bounds is ignored without a warning.
- **Type-ahead user search (`searchUsers`) is capped at 20 results** and
  requires at least 2 characters, to bound both the query and the risk of
  using the endpoint as a general user-enumeration tool.

## Packaging

This package is distributed as a **released managed (2GP) version** under the
`atexplorer` namespace (`sfdx-project.json` → `"namespace": "atexplorer"`,
package `0Hohm0000000NHZCA2`, current version `1.0.1.4` /
`04thm000002tWirAAE`, promoted 2026-10-12; the previous released version
`1.0.0.2` / `04thm000002OtQPAA0` was promoted 2026-09-09). "Released" is the
Salesforce packaging state — the version installs into any org type including
production. No version of the package has completed AppExchange Security
Review; its AppExchange listing is an unpublished draft.

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
install and test evidence.
