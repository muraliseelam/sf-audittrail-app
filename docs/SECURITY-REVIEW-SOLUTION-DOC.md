# Audit Trail Explorer — Solution Documentation

Prepared ahead of an AppExchange/AgentExchange security review submission.
**This package has not yet been submitted for, or passed, that review.** It
describes managed 2GP version `1.0.1.4` (`04thm000002tWirAAE`, built 2026-10-12
from commit `f0ad675`), which was promoted on 2026-10-12 and is the current
released version in the Salesforce packaging sense only: it has not been
submitted for or reviewed under AppExchange Security Review and no AppExchange
listing exists. The previous released version is `1.0.0.2`
(`04thm000002OtQPAA0`). Versions `1.0.1.1` to `1.0.1.3` are unreleased betas that
were superseded during the release's static-analysis work (section 10). Current
status is tracked in [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).

## 1. What the solution does

Audit Trail Explorer is a read-only UI over the standard Salesforce `SetupAuditTrail`
object. Salesforce retains setup audit records for 180 days and exposes them in Setup
only as a flat, barely filterable list with a 20-row page and a CSV download. This app
provides search, filtering, faceting, paging and export over that same data.

It adds no new data. It is a viewer.

## 2. Architecture

```
Browser (Lightning Web Component)
  |  imperative Apex
  v
AuditQueryController          @AuraEnabled facade - the ONLY external surface
  |  (search and searchUsers call AuditPermissionService first; getContext
  |   returns no audit data and is not gated - see section 4. The controller
  |   also issues one SOQL query directly, against the standard User object,
  |   for the "changed by" type-ahead - see section 6)
  v
AuditQueryService             progressive, time-sliced scan; Apex-side filtering
  |
  v
SetupAuditTrailProvider       the only class that queries SetupAuditTrail
  |
  v
SetupAuditTrail (standard object, read-only)
```

There is no trigger, no scheduled job, no batch job, no platform event, no custom object,
and no custom setting.

## 3. Data handling

| Question                                         | Answer                                                                                                                                                                                                                                                                       |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Does the solution store data outside Salesforce? | **No.**                                                                                                                                                                                                                                                                      |
| Does the solution make external callouts?        | **No.** There is no `HttpRequest`, no named credential, and no remote site setting in the package.                                                                                                                                                                           |
| Does the solution create or modify any record?   | **No.** The runtime code performs no DML. The packaged test classes insert `User`, `PermissionSet` and `PermissionSetAssignment` records (`AuditPermissionServiceTest.cls`, `AuditQueryControllerTest.cls`), but only inside Apex tests, where the platform rolls them back. |
| Does the solution include a custom object?       | **No.**                                                                                                                                                                                                                                                                      |
| Where is data persisted?                         | Nowhere. Every request reads `SetupAuditTrail` (and, for the user type-ahead described below, `User`) live and returns the rows to the browser. Nothing is cached server-side, and all three Apex entry points are `cacheable=false` (section 4).                            |
| Is any data sent to a third party?               | **No.**                                                                                                                                                                                                                                                                      |

Because nothing is stored, there is no data-retention, data-residency or data-deletion
surface. Uninstalling the package removes the code and leaves no residue.

## 4. Authentication and authorisation

The app has a single authorisation gate: the standard **View Setup and Configuration**
(`ViewSetup`) user permission, which is the same permission Salesforce itself requires to
view the Setup Audit Trail. The app grants no access that the user did not already have.

`AuditPermissionService.assertCanViewSetup()` enforces this by checking
`Schema.SObjectType.SetupAuditTrail.isAccessible()`. The equivalence between that
describe call and the ViewSetup permission was verified empirically in a scratch org
rather than assumed (`AuditPermissionService.cls:8-12`). `AuditPermissionServiceTest`
pins both directions under `System.runAs` as freshly inserted users on the stock
**Minimum Access - Salesforce** profile:

- Negative: `deniesUserWithoutViewSetup` (the gate returns `false` and
  `assertCanViewSetup` throws), `blocksControllerEntryPointsForUnprivilegedUser`
  (`search` and `searchUsers` each throw an `AuraHandledException` whose message
  names View Setup and Configuration) and
  `restrictedUserGetContextReportsNoAccessWithoutThrowing` (`getContext` answers
  `canViewSetup = false` rather than throwing).
- Positive, deterministic:
  `restrictedUserWithLocalViewSetupPermissionSetCanUseEveryEntryPoint`
  (`AuditPermissionServiceTest.cls:130-195`) inserts a `PermissionSet` with
  `PermissionsViewSetup = true` and `PermissionsViewRoles = true` inside the test,
  assigns it to the Minimum Access user, and under `runAs` asserts that the gate
  opens, that `search` returns the mock row, that `getContext` reports
  `canViewSetup = true` and that `searchUsers` finds the user's own record. A
  permission set created in the org is never stripped by packaging, so the test
  holds in source, unlocked and managed contexts alike; it is exactly the grant a
  subscriber administrator makes.
- Positive, running user: `allowsUserWithViewSetup` (no `runAs`; the test runner is
  an administrator who holds ViewSetup).
- Packaging equivalence: `packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup`
  asserts under `runAs` that the gate opens exactly when the shipped permission set
  genuinely carries ViewSetup, which it does on a source deploy and does not under a
  managed install (see below).

The controller exposes three `@AuraEnabled` methods, all declared `cacheable=false`
(`AuditQueryController.cls:21,40,59`), so neither the access answer nor the
type-ahead results are held in the Lightning client-side action cache: every call is
evaluated afresh against the caller's current permissions. The two that return data,
`search` and `searchUsers`, call the gate before doing any other work; `getContext` is
deliberately not gated because it returns no audit data:

| Method        | Gated                | Notes                                                                                                                                                                                                                                                                                                                   |
| ------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `search`      | Yes                  | `assertCanViewSetup()` is the first statement inside the `try` (`AuditQueryController.cls:24`).                                                                                                                                                                                                                         |
| `searchUsers` | Yes                  | Type-ahead over the User object for the "changed by" filter. Gated on the same permission as the audit data so it cannot be used to enumerate the org's user list (`:62-65`).                                                                                                                                           |
| `getContext`  | Not gated, by design | Returns only compile-time constants, `Datetime.now()`, and the calling user's own access boolean. It discloses nothing the caller does not already know about themselves, and the UI needs it to render the "you lack permission" state; the component shows no form until it has answered (`auditExplorer.js:96-132`). |

The shipped permission set `Audit_Trail_Viewer` declares `ViewSetup` and its
`ViewRoles` prerequisite (Salesforce requires `ViewRoles` to enable
`ViewSetup`), plus the app, the tab, and Apex class access - no object
CRUD/FLS grant and no other system permission. Its description states that the two
system permissions take effect for source deploys only
(`Audit_Trail_Viewer.permissionset-meta.xml:4-5`).

**Under managed packaging, the app grants no system permission at all.**
Salesforce strips system permissions from a managed package's permission sets
on install, so in a subscriber org `Audit_Trail_Viewer` carries
`PermissionsViewSetup = false` and grants only the app, its tab, and its Apex
classes. Subscriber administrators must grant "View Setup and Configuration"
themselves. This is verified empirically in
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md), and was re-confirmed
after each `1.0.1.x` install (`PermissionsViewSetup = false`,
`PermissionsViewRoles = false` every time). It means the managed package cannot
escalate any subscriber's privileges: every user who can see audit data through
this app could already see it natively in Setup.

## 5. CRUD/FLS and sharing enforcement

- Both production SOQL paths enforce CRUD/FLS at the platform level rather
  than via hand-written describe checks: the `SetupAuditTrail` query runs as
  `Database.query(soql, AccessLevel.USER_MODE)` (`SetupAuditTrailProvider.cls:42`),
  and the `User` type-ahead query (`AuditQueryController.searchUsers`) runs
  `WITH USER_MODE` (`AuditQueryController.cls:79-86`).
- Every production Apex class is declared `with sharing` (`AuditCursor`,
  `AuditEventRow`, `AuditFilter`, `AuditPermissionService`, `AuditQueryController`,
  `AuditQueryService`, `AuditSearchResult`, `SetupAuditTrailProvider`), as are the
  two inner classes that hold logic (`AuditQueryService.CompiledFilter`,
  `AuditQueryService.cls:246`, and `AuditSearchResult.AuditFacet`,
  `AuditSearchResult.cls:33`). `AuditTrailProvider` is an interface and cannot carry
  a sharing keyword; `AuditPermissionService.AuditPermissionException` is an empty
  inner exception type. The four `@IsTest` test classes carry no sharing keyword and
  run only in test context; the `@IsTest` mock provider is `with sharing` (its inner
  `DescendingKeyset` comparator sorts in-memory rows and issues no query).
- The Graph Engine's two security rules, `ApexFlsViolation` and
  `DatabaseOperationsMustUseWithSharing`, report 0 violations across the full
  6,537-path analysis of the `1.0.1` source (section 10), so the two points above
  are confirmed by path-sensitive analysis, not only by inspection.
- `SetupAuditTrail` is a read-only platform-owned object, so there is no DML to enforce.

## 6. Injection defences

**SOQL.** `SetupAuditTrailProvider` is the only class that builds the
`SetupAuditTrail` query string (`SetupAuditTrailProvider.cls:17-35`);
`AuditQueryController.searchUsers` is the only other method that issues SOQL,
against `User` (see section 3 and the LIKE-wildcards note below). In both
queries, every literal fragment is a compile-time string literal - there is no
path by which user input reaches the query text. Every caller-supplied value is
a bind variable: the date bounds (`:lowerBound`, `:upperBound`), the optional
`Action IN :actions` and `CreatedById IN :userIds` predicates, the keyset
position and the row limit. The keyset continuation predicate is appended only
when a position exists and reads `AND (CreatedDate < :upperBound OR Id < :lastId)`
(`:26-28`); `lastId` is typed `Id`, so a value that is not a well-formed Id cannot
reach it (see "Untrusted cursor"). The row limit is bound from the service's
private `scanBatch` field (1000; `@TestVisible` so tests can shrink it, assigned
nowhere outside tests, `AuditQueryService.cls:34-35`), not from the client. The
query carries no id list and no `NOT IN`.

**LIKE wildcards.** For the user type-ahead, the search term is bound (never
concatenated), and LIKE metacharacters are neutralised in the correct order: backslash
first, then `%`, then `_` (`AuditQueryController.cls:77`). `String.escapeSingleQuotes`
is deliberately **not** used on bind values, because it corrupts legitimate names such
as `O'Brien` without adding safety. The escaping is pinned by
`searchUsersTreatsPercentAsLiteral`, `searchUsersTreatsUnderscoreAsLiteral` and
`searchUsersTreatsEscapedPercentAsLiteral` (`AuditQueryControllerTest.cls:195-249`);
the test user's last name sorts first under `ORDER BY Name`, so an unescaped wildcard
would surface it inside the 20-row limit and fail the test honestly.

**Untrusted cursor.** The paging cursor round-trips through the browser and is therefore
treated as untrusted input. It is fixed-size - `lastDateMillis`, `lastId`,
`rangeStartMillis`, `rangeEndMillis`, `exhausted` (`AuditCursor.cls:21-30`) - because
paging is keyset-based on `(CreatedDate, Id)`: no list of already-seen ids exists, so
nothing in the cursor can grow a bind variable. Validation runs before any query:

- A cursor counts as a continuation only when it carries a position and both pinned
  bounds (`AuditQueryService.cls:67-73`). A cursor without a position, or with a
  position but no bounds (only a hand-built payload looks like that; the client
  round-trips the whole cursor), starts the search afresh
  (`continuationCursorMissingRangeRestartsTheSearch`).
- For a continuation, `AuditCursor.lastIdValue()` (`AuditCursor.cls:53-65`) rejects a
  blank id, a value that is not `instanceof Id`, and a well-formed Id of any object
  other than `SetupAuditTrail`, by throwing an `IllegalArgumentException` whose
  message is `Malformed cursor`; the controller converts that to the generic client
  message (section 7). `malformedContinuationCursorIsRejected`,
  `blankIdOnPositionedCursorIsRejected` and
  `cursorIdOfAnotherObjectIsRejected` assert that the provider's fetch count stays at
  0, i.e. that the rejection happens before any query.
- The pinned bounds are re-clamped rather than trusted (`AuditQueryService.cls:84-93`):
  the lower bound is `max(rangeStartMillis, retention floor)` and the upper bound
  `min(lastDateMillis, rangeEndMillis)`, so a tampered cursor cannot widen the scan
  below the 180-day floor or above the pinned end
  (`continuationBoundsAreReclampedFromAnUntrustedCursor`).
- A cursor that does not deserialize at all fails inside the controller and is masked
  the same way (`searchHidesDeserializationFailureDetail`).

**Client-controlled quantities.** Every number or string the client can send is
bounded on the server. `searchText` is cut to 200 characters and at most 10
whitespace-separated terms before it is matched against up to 10,000 rows per call
(`AuditQueryService.cls:47-48,266-270`; `searchTextIsTruncatedToTwoHundredCharacters`,
`searchTextHonoursOnlyTheFirstTenTerms`). `lastDays` is capped at `RETENTION_DAYS`
(180) and resolved against the server clock, never the browser's (`:200-211`;
`lastDaysIsCappedAtTheRetentionWindow`, `lastDaysUsesServerClockAndPinsRange`); an
explicit start date is clamped to the retention floor
(`clampsRequestsBelowTheRetentionFloor`). `pageSize` defaults to 50 when null or
non-positive and is clamped to 200 (`:213-218`;
`pageSizeIsClampedToTheMaximumAndDefaulted`). Each call issues at most
`maxBatchesPerCall` (10) queries of `scanBatch` (1000) rows (`:34-37,116`), so the
work one request can cause is fixed whatever the filter.

**XSS.** The LWC renders exclusively through `{}` template interpolation, which is
context-escaped by the framework. The package contains no `innerHTML`, no
`lwc:dom="manual"`, no `eval`, no `document.write`, and no Visualforce or Aura.

**CSV formula injection.** Audit descriptions echo admin-controlled text (renamed field
labels, for example), so an exported cell could otherwise carry a payload that executes
when the file is opened in Excel or Google Sheets. `csv.js` prefixes any cell beginning
with `=`, `+`, `-`, `@`, whitespace, a C0 control character or a zero-width space with a
single quote. The logic is isolated in its own module specifically so it can be unit
tested, and it is. Since `1.0.1` the file starts with the UTF-8 byte-order mark so that
Excel on Windows decodes it correctly; the mark precedes the quoted header cell
`"Date"`, so the guard applies to the data cells exactly as before
(`auditExplorer.js:469-471`).

## 7. Error handling

All three `@AuraEnabled` methods share one contract (`AuditQueryController.cls:7-9`):
each body is wrapped in `try/catch`, and the only exception type that leaves the
controller is `AuraHandledException`.

- The permission failure is passed to the client verbatim, because it is the
  actionable, user-facing case: `permissionFailure` (`:101-107`) builds the
  `AuraHandledException` from `AuditPermissionException.getMessage()` and calls
  `setMessage()` with the same text, so the browser receives the sentence naming
  View Setup and Configuration. Without `setMessage()` the client would see only
  "Script-thrown exception".
- Every other exception, from any of the three methods, goes through
  `genericFailure` (`:109-117`): the exception type and message are written to the
  debug log with `System.debug(LoggingLevel.ERROR, ...)`, and the client receives the
  fixed `GENERIC_ERROR` text via `setMessage()`. Platform exception text, which can
  carry query fragments and limit details, therefore never reaches the browser.
  `getContext` has no permission branch (it is ungated) and uses the generic path
  only.
- Tests: `blocksControllerEntryPointsForUnprivilegedUser` asserts the permission
  message on both gated entry points; `searchHidesInternalErrorDetail` (a continuation
  cursor with a malformed id) and `searchHidesDeserializationFailureDetail` (a cursor
  that does not deserialize) assert the generic message and that it contains none of
  `Malformed`, `SELECT`, `SetupAuditTrail`, `JSON` or the offending field name.
- The component shows whichever message arrives (`auditExplorer.js:538-546`): for
  `getContext` it shows the error and no form (`:106-109`), for the search loop it
  stops and shows the error (`:298-299`), and for the type-ahead it clears the list and
  shows the error, discarding any response that arrives after the term has changed
  (`:381-397`). Nothing is swallowed.

No secret, credential or personal data is logged: the single debug line carries the
exception type and message only.

## 8. Testing

- 50 Apex tests in four classes (29 in `1.0.0.2`); coverage **96%** at package
  build time for `1.0.1.4` (`HasPassedCodeCoverageCheck = true`; the
  managed-package requirement is 75%). On the source deploy of the same commit
  (`f0ad675`, deploy `0Afh1000000NfiTCAS`, 18/18 components, 50 run / 0 failed)
  the per-class figures were `AuditCursor` 100%, `AuditQueryController` 92%,
  `AuditSearchResult` 100%, `AuditQueryService` 96%, `AuditPermissionService`
  100%, `AuditEventRow` 100% and `SetupAuditTrailProvider` 100%; `AuditFilter`
  has no executable lines.
- Re-verified 2026-10-12 in a clean subscriber org: the **released managed
  version** `1.0.1.4` passes 50/50 as namespaced `atexplorer.*` classes
  (`RunAllTestsInOrg` run `707di0000LCKGo0`). Org-wide coverage reads 0% there
  because Salesforce does not expose managed-package coverage to subscribers, so
  the build-time 96% is the meaningful figure. Run ids are recorded in
  [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).
- The tests added or extended in `1.0.1` pin, by name:
    - the access gate (section 4):
      `restrictedUserWithLocalViewSetupPermissionSetCanUseEveryEntryPoint`,
      `restrictedUserGetContextReportsNoAccessWithoutThrowing`, and
      `blocksControllerEntryPointsForUnprivilegedUser`, which now asserts the
      `AuraHandledException` message rather than only the exception type;
    - the error contract (section 7): `searchHidesInternalErrorDetail`,
      `searchHidesDeserializationFailureDetail`;
    - the untrusted cursor (section 6): `malformedContinuationCursorIsRejected`,
      `blankIdOnPositionedCursorIsRejected`, `cursorIdOfAnotherObjectIsRejected`,
      `continuationBoundsAreReclampedFromAnUntrustedCursor`,
      `continuationCursorMissingRangeRestartsTheSearch`, `searchRoundTripsCursorJson`
      (the keyset id and the pinned range survive the JSON round trip);
    - the server-owned date range: `lastDaysUsesServerClockAndPinsRange` (a
      different filter on the continuation call does not move the pinned range),
      `lastDaysIsCappedAtTheRetentionWindow`, `lastDaysZeroMeansExplicitDatesApply`,
      `negativeLastDaysMeansExplicitDatesApply`, `exhaustedScanReportsRangeBoundary`,
      `exhaustedScanWithRowsReportsRangeBoundaryNotOldestRow`;
    - input bounds: `searchTextHonoursOnlyTheFirstTenTerms`,
      `searchTextIsTruncatedToTwoHundredCharacters`,
      `pageSizeIsClampedToTheMaximumAndDefaulted`, `blankFieldDoesNotMatchTheWordNull`
      (a blank field no longer matches the search term "null");
    - LIKE escaping: `searchUsersFindsActiveUsers`, `searchUsersTreatsPercentAsLiteral`,
      `searchUsersTreatsUnderscoreAsLiteral`, `searchUsersTreatsEscapedPercentAsLiteral`.
- The multi-batch scan and the per-call ceiling are exercised directly, not
  inferred: `useSmallBatches()` (`AuditQueryServiceTest.cls:48-52`) sets the
  `@TestVisible` fields to `scanBatch = 100` and `maxBatchesPerCall = 3`, and then
  `multiBatchScanFindsAMatchInTheLastShortBatch` (250 rows at distinct timestamps,
  three fetches, only the oldest row matches, the range is reported done),
  `sameTimestampRowsPageByIdAcrossBatches` (250 rows in one second, batches of 100,
  pages of 40: every row returned exactly once across batch and page boundaries) and
  `ceilingStopsACallWithoutLosingProgress` (350 non-matching rows: the first call
  stops at 300 scanned rows with the cursor positioned on the last of them, the
  second finishes the remaining 50 in one short batch) assert fetch counts, scanned
  counts and cursor positions.
- `SetupAuditTrail` cannot be inserted in a test, so the service takes an injectable
  provider interface; `MockAuditTrailProvider` implements the same keyset contract as
  the real query (`(CreatedDate DESC, Id DESC)` order, exclusion at the upper bound).
  `SetupAuditTrailProviderTest` nonetheless executes the real production query, so the
  SOQL is genuinely exercised rather than mocked away;
  `realQueryExecutesWithEveryOptionalFilter` passes a `lastId`, so the keyset predicate
  `Id < :lastId` runs against the real object.
- 26 Jest tests (7 in `1.0.0.2`) covering the component, including the CSV
  escaping, the BOM and object-URL handling, the access tri-state (spinner, denied,
  error-only), the filter snapshot behind "Search further back", the type-ahead
  stale-response guard, user-pill removal and the 25-call bound on one search
  action. Measured on the `1.0.1` source with the v8 coverage provider: `auditExplorer.js`
  **95.16% statements** / 79.34% branches / 95.65% functions / 94.84% lines, and
  `csv.js` - the formula-injection control - at **100%**. (The stock Babel coverage
  provider prints an empty table when Jest runs inside a git worktree on the
  maintainer's machine; that is a measurement quirk, not a code problem.)
  `npm run lint` and `npm run prettier:verify` are clean.
- Paging correctness on real data was validated for `1.0.0.2` in the installed
  managed package (`00DRK00000aOfV72AK`, 2026-09-13): 65 audit rows sharing one
  timestamp were seeded so that the 50-row page boundary fell inside the block, and
  paging to completion (50, 100, 118) exported **118 data rows against 118 rows in
  the org with 0 duplicate rows**. That run exercised the previous cursor design;
  the `1.0.1` keyset cursor is pinned by the unit tests named above. A manual smoke
  test of the `1.0.1` source on 2026-10-12 (no screenshots were kept) confirmed in a
  scratch org, as an administrator, that the tab loads with data, that the user
  type-ahead returns active users and a selected pill can be removed, that editing a
  filter shows the "Filters changed" hint, that "Search further back" continues the
  original search (rows 50 to 64) without applying a pending term, and that Enter in
  the search box applies it; and, via Login As, that a Minimum Access user holding
  only the packaged permission set sees the full app on a source deploy, sees the
  denied message with no form and Export disabled on a managed install, and sees the
  app once a locally created permission set carrying ViewSetup and ViewRoles is
  assigned.

## 9. Third-party code

**None.** The package contains no third-party JavaScript library, no static resource, and
no npm dependency shipped to the runtime. RetireJS reports zero findings.

## 10. Static analysis

Salesforce Code Analyzer v5 (`@salesforce/plugin-code-analyzer`), run from a checkout of
this repository, after `npm ci`, as:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector Security \
  --rule-selector AppExchange
```

This scan has been run four times. The three runs on the `1.0.0.2` source produced
an identical rule set and identical results; the fourth, on the `1.0.1` source,
used the same rule set and is the result this section reports. Every run is
recorded in [`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md);
the report Salesforce asks for, generated with its own command, is recorded under
"Official AppExchange command" at the end of this section.

| Date       | Plugin   | Host                                                                              | Source                                                     |
| ---------- | -------- | --------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| 2026-09-10 | `5.15.0` | Windows workstation, CLI 2.98.6, OpenJDK 21                                       | commit `934f200` (tag `v1.0.0`, the source of `1.0.0.2`)   |
| 2026-09-19 | `5.16.0` | GitHub Actions `ubuntu-latest`, CLI 2.150.6, run `35450675758`                    | commit `5c70c8c`; `force-app` identical to `934f200`       |
| 2026-10-11 | `5.16.0` | Windows workstation, CLI 2.153.5, OpenJDK 21.0.12.1                               | HEAD `f27a009`; `force-app` identical to `934f200`         |
| 2026-10-12 | `5.16.0` | Windows workstation, CLI 2.153.5, Node 24.20.0, OpenJDK 21.0.12.1, Python 3.12.10 | commit `f0ad675` (the source of `1.0.1.4`), after `npm ci` |

**Prerequisite.** Since commit `5c70c8c` the committed `code-analyzer.yml`, which the
plugin auto-loads from the current directory, sets `eslint_config_file` to
`eslint.config.js`, and that file requires the project's devDependencies. In a
checkout without `node_modules` the eslint engine fails to instantiate (Critical
`UninstantiableEngineError`, "Cannot find module 'eslint/config'"; verified on a
pristine checkout of `47bd65f`, which then reported 59 rules from 4 engines plus
that one engine error). That is an environment error, not a code finding, and it
applies to the official command below as well. Run `npm ci` first.

The 5.15.0 and 5.16.0 rule lists match rule for rule, not merely in total, and the 85
findings of the `1.0.0.2` baseline reproduced count for count on all three of its dates.
The 2026-10-11 run additionally printed one Critical `UninstantiableEngineError` from the
`flow` engine ("Could not locate a Python v3.10.0+ install"), because Python was not yet
installed on that workstation. That is an engine-instantiation error with no file, not a
code finding: the flow engine is not eligible for the `force-app` workspace anyway (no
Flow metadata), the six engines counted below all ran, and the Graph Engine completed its
full path space both inside that run and in the separate `--rule-selector sfge` run that
followed it. The 2026-10-12 run had Python installed and printed no engine error.

**This selector resolves to 310 rules across all six engines** (202 eslint, 94 pmd, 6
regex, 4 retire-js, 2 cpd, 2 sfge). Verify that count with `sf code-analyzer rules` using
the same flags before trusting any result: a selector that silently resolves to zero rules
reports "0 violations" while proving nothing, which is exactly the failure this repository
hit previously with the intersection selector `Recommended:AppExchange`.

The three tags are passed as three separate `--rule-selector` flags because a
colon-separated selector is an _intersection_. `Security` is included specifically to reach
`sfge:ApexFlsViolation` and `sfge:DatabaseOperationsMustUseWithSharing`, which are tagged
`DevPreview` and are therefore selected by neither `Recommended` nor `AppExchange` — yet
they are the two rules most directly relevant to this review.

### Result

Run of 2026-10-12 on `f0ad675` (`--severity-threshold 2`, exit 0, 11 minutes), with the
`1.0.0.2` baseline for comparison:

| Severity | `1.0.1.4` | `1.0.0.2` |
| -------- | --------- | --------- |
| Critical | **0**     | **0**     |
| High     | **0**     | **0**     |
| Moderate | 13        | 11        |
| Low      | 106       | 74        |
| Total    | 119       | 85        |

**No violation of any severity carries the `Security`, `AppExchange` or `ErrorProne` tag.**
Specifically clean: all 29 PMD AppExchange security rules, both Graph Engine security
rules, the regex secrets engine, and RetireJS. In this run the Graph Engine portion
embedded in the six-engine scan also completed ("analyzed 6537 path(s) from 3 entry
point(s)", 0 violations for the two Security-tagged rules), which the trimmed `1.0.1`
search path made possible; the standalone Graph Engine run described below remains the
authoritative evidence for it.

### Items not fixed, and why

Every remaining violation is a code-quality or style rule. None is suppressed by
configuration; all 119 are reported on every run and dispositioned individually in
[`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md).
Against the `1.0.0.2` baseline the growth is +19 `ApexUnitTestClassShouldHaveRunAs`
(new tests), +9 `ApexDoc` (new methods), +4 `no-hardcoded-values-slds2` (new CSS), +1
`CyclomaticComplexity` (the `AuditQueryServiceTest` class total, test code) and +1
`no-inline-disable` (the sequential-await loop in the Jest file); `CognitiveComplexity`
is unchanged at 3. In summary:

| Rule                                   | Severity | Count | File(s)                                                                                                                | Why not fixed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| -------------------------------------- | -------- | ----- | ---------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pmd:ApexUnitTestClassShouldHaveRunAs` | Low      | 45    | 4 test classes                                                                                                         | `System.runAs` is used where it is meaningful: the five gate tests in `AuditPermissionServiceTest` run as a freshly inserted Minimum Access - Salesforce user to prove denial of `canViewSetup`/`assertCanViewSetup`, denial at `search` and `searchUsers`, the ungated `getContext` answer, the deterministic positive case through a locally created permission set, and the packaged-permission-set equivalence (section 4). Of the remaining 45 tests, most are user-independent (cursor arithmetic, filter compilation, scanning a mock provider) and the rest require `ViewSetup` on the running user, which the test runner holds. |
| `pmd:ApexDoc`                          | Low      | 38    | Apex classes and test classes                                                                                          | Every class and non-trivial method carries an explanatory comment; the rule requires ApexDoc `@description`/`@param` tag syntax, which this project does not use. No functional or security impact.                                                                                                                                                                                                                                                                                                                                                                                                                                       |
| `slds:no-hardcoded-values-slds2`       | Low      | 22    | `auditExplorer.css`                                                                                                    | SLDS 2 design-token advisories. Cosmetic; no security or functional impact.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| `pmd:ExcessiveParameterList`           | Moderate | 4     | `AuditTrailProvider.cls:25`, `SetupAuditTrailProvider.cls:9`, `MockAuditTrailProvider.cls:19` and `:69`                | This is the testability seam. `SetupAuditTrail` rows cannot be inserted in an Apex test, so the query sits behind an injectable interface. The parameters are the query's bind values, passed explicitly so each is visibly bound at the point a reviewer most wants to see it.                                                                                                                                                                                                                                                                                                                                                           |
| `pmd:CognitiveComplexity`              | Moderate | 3     | `AuditQueryService` class total (`:24`), `AuditQueryService.search` (`:53`), `MockAuditTrailProvider.fetch` (`:19`)    | Inherent to the algorithm — see below. The mock is test code.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `pmd:CyclomaticComplexity`             | Moderate | 3     | `AuditQueryService.search` (`:53`), `AuditQueryServiceTest` class total (`:2`), `MockAuditTrailProvider.fetch` (`:19`) | As above. The test-class total is 28 test methods counted together; the mock is test code.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `lwc:no-inline-disable`                | Moderate | 2     | `auditExplorer.js:289`, `__tests__/auditExplorer.test.js:81`                                                           | One `eslint-disable-next-line no-await-in-loop` on the progressive-search loop, and one on the Jest helper that drives it. Each call needs the paging cursor returned by the previous one, so the awaits are sequential by necessity. Scoped to a single line and justified inline. Disabling the rule file-wide instead would silence it far more broadly and leave no marker at the call site.                                                                                                                                                                                                                                          |
| `pmd:NcssCount`                        | Moderate | 1     | `AuditQueryService.search` (`:53`)                                                                                     | As above.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| `pmd:AvoidDebugStatements`             | Low      | 1     | `AuditQueryController.genericFailure`                                                                                  | The single `System.debug(LoggingLevel.ERROR, ...)` is the server-side half of the generic error handling: unexpected exceptions are logged for the administrator and replaced with a non-specific client message, so platform exception text cannot leak query internals to the browser. It logs exception type and message only — no credential, session or personal data. Removing it would satisfy the linter by discarding the diagnostic trail.                                                                                                                                                                                      |

On the complexity findings: `SetupAuditTrail` cannot be filtered on `Section` or `Display`
in SOQL and supports no aggregate functions, so `AuditQueryService.search` must scan
backwards through time in bounded windows, post-filter in Apex, and maintain an exact
cursor across window boundaries while staying inside governor limits. Decomposing that
single stateful loop would spread it across several methods that could not be understood
or tested independently; in `1.0.1` the method is additionally kept to as few branches as
possible so that the Graph Engine can enumerate its paths (`AuditQueryService.cls:57-66`
and the next subsection). The behaviour is pinned by tests:
`pagingCoversEveryRowExactlyOnce`, `handlesManyRowsSharingOneTimestamp`,
`multiBatchScanFindsAMatchInTheLastShortBatch`, `sameTimestampRowsPageByIdAcrossBatches`
and `ceilingStopsACallWithoutLosingProgress` (section 8), and the `1.0.0.2` live paging
check in [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) (118 rows exported
against 118 in the org, 0 duplicates, with a 65-row same-timestamp block spanning a page
boundary) confirmed the previous cursor on real data.

### Engines that need a runtime

PMD, CPD and the Graph Engine require a local JDK; the Flow engine requires Python 3.10
or later. If one is missing the engine **fails to load**: depending on the plugin version
it is either skipped silently, so the scan reports a false all-clear, or, as 5.16.0 did
for the flow engine on 2026-10-11, reported as a Critical `UninstantiableEngineError`
with no file, which is not a code finding. The same applies to the eslint engine without
`node_modules` (see "Prerequisite" above). Check the engine and rule counts rather than
the violation total. The 2026-09-10 record notes OpenJDK 21 and records nothing about
Python (on 5.15.0 and the `force-app` workspace the flow engine was not in play); the
2026-10-11 three-tag runs had OpenJDK 21.0.12.1 and no Python, and Python 3.12.10 was
installed before the official-selector run that day; the 2026-10-12 runs had OpenJDK
21.0.12.1 and Python 3.12.10 throughout.

### Graph Engine

The Graph Engine needs particular care. On timeout it still prints "0 violations" and
reports the abandoned entry point only as an easily missed `Internal execution error`,
so a bare "0 violations" from it proves nothing. The path count is a property of the
code: every conditional between the entry point and the SOQL multiplies it.
The engine analysed **14,503 paths** across the three entry points on the `1.0.0.2`
source (nearly all of them in `AuditQueryController.search`; about 7 minutes at the
600 s per-path budget then configured) and **6,537 paths** on the `1.0.1` source. `code-analyzer.yml` now sets `java_thread_timeout` to
1,800,000 ms and the CI job allows 90 minutes, because the first `1.0.1` builds
showed how quickly the count can explode:

- `1.0.1.1` (`47bd65f`): a memory-starved run reported one
  `sfge:ApexNullPointerException` on `working.lastIdValue()`, a false positive caused
  by a null check that had moved into a separate Boolean the path analysis cannot
  correlate. Fixed in `41e2a29` by keeping the check inline.
- `1.0.1.2` (`41e2a29`): the standalone run timed out on the `search` entry point at
  600 s and again at a diagnostic 1,800 s, reporting 3 paths from 2 entry points and
  the vacuous "0 violations". The cause was path explosion from conditionals added
  inside the per-row scan loop, not the host. Fixed in `f05ed25` with the same
  behaviour and fewer branches.
- `1.0.1.3` (`f05ed25`): still timed out at 1,800 s; the remaining multipliers were in
  the cursor normalisation before the loop. Fixed in `f0ad675`: one ternary decides
  whether the client sent a complete continuation cursor, observed sections and
  actions are collected unconditionally and nulls removed once, and the search terms
  are bounded by a counted loop (section 6 describes the resulting behaviour).

Those three versions were never promoted. Heap size is set to `2g` **deliberately, not
higher**. Requesting more than the host can spare makes the JVM thrash and the analysis
times out anyway: on an 8 GB machine a 4g request produced `3 path(s) from 2 entry
point(s)` plus an error, whereas 2g with 4 threads completed the full space. Running the
Graph Engine alongside the other five engines can lose the same memory race, so verify it
with its own run on an otherwise idle machine:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector sfge
```

On `f0ad675` this run (2026-10-12, otherwise idle host, 757 s) reported **"analyzed
6537 path(s) from 3 entry point(s)"** and **"Detected 1 violation(s) from 6537 path(s)
on 3/3 entry point(s)"**, with no `Internal execution error`, which is the validity bar.
The two security rules, `sfge:ApexFlsViolation` and
`sfge:DatabaseOperationsMustUseWithSharing`, report 0 violations. The one violation is
`sfge:AvoidDatabaseOperationInLoop` (severity High in the report; tags `DevPreview`,
`Performance`, `Apex`; not a `Security` or `AppExchange` rule): "A database operation
occurred inside a loop", the `while` at `AuditQueryService.cls:116`, reported against
the `search` entry point (`AuditQueryController.cls:22`) and the `Database.query` at
`SetupAuditTrailProvider.cls:42`. It is by design and bounded: that loop is the
progressive, time-sliced scan the application exists for, it issues at most
`maxBatchesPerCall` (10) queries per transaction against the 100-query governor limit,
each call is its own transaction, and the ceiling is pinned by
`ceilingStopsACallWithoutLosingProgress`. It cannot be removed without abandoning the
design and is accepted; the disposition is in
[`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md).
It appears only in this run because `--rule-selector sfge` selects every Graph Engine
rule, Performance rules included; the three-tag union reaches only the two
Security-tagged ones. `.github/workflows/code-analyzer.yml` pins the `6537 path(s)`
figure; if `search()` grows a conditional, re-measure before trusting the result. Treat
any Graph Engine result that does not name the path and entry-point counts as unproven.

### Official AppExchange command

Salesforce's submission instructions name a different selector and a specific output
file:

```
sf code-analyzer rules --rule-selector AppExchange --rule-selector Recommended:Security
sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security \
  --output-file CodeAnalyzerReport.html
```

**2026-10-12, the report for `1.0.1.4`.** Run on commit `f0ad675` from the release
worktree's top-level directory after `npm ci`, with no `--config-file` and no
`--workspace`, using plugin 5.16.0 on CLI 2.153.5, Node 24.20.0, OpenJDK 21.0.12.1
and Python 3.12.10. The selector resolved to **62 rules from 5 engines** (51 pmd,
4 retire-js, 3 eslint, 3 flow, 1 regex; no sfge and no cpd), so the result is not
the vacuous zero this document warns about. The run exited 0 and reported **"Found 0
violations."** The retire-js, eslint, regex and pmd engines executed; the flow engine
had no Flow metadata to scan. `CodeAnalyzerReport.html` is gitignored and is kept by
the maintainer outside the repository; the copy produced by this run is 64,954 bytes
with SHA-256
`03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`. **This is the
file to upload with the `1.0.1.4` submission.**

**2026-10-11, the `1.0.0.2` record.** The same command was run from a clean
`git worktree` at commit `934f200` (tag `v1.0.0`, the source that built `1.0.0.2`),
with no `node_modules` (that commit predates the `eslint_config_file` setting), on
plugin 5.16.0 with OpenJDK 21.0.12.1 and Python 3.12.10: the same 62 rules from 5
engines, exit 0, "Found 0 violations.", report 65,085 bytes with SHA-256
`5c05b155418a8a1be3fa2ff77132260f3b62e628380b25afa4dc293d93c9169e`. That report and
the interim `1.0.1.2` report are superseded for the `1.0.1` submission by the
2026-10-12 file above.

Comparing the two rule lists (`sf code-analyzer rules` with each selector), 48 of the 62
official rules are also in the three-tag union above. The other 14 are rules the union
run could not offer because `--workspace force-app` holds no metadata for them: 11 PMD
Visualforce rules (`AvoidCreateElementScriptLinkTag`, `AvoidHardcodedSecretsInVFAttrs`,
`AvoidUnauthorizedApiSessionIdInVisualforce`,
`AvoidUnauthorizedGetSessionIdInVisualforce`, `LoadCSSApexStylesheet`, `LoadCSSLinkHref`,
`LoadJavaScriptHtmlScript`, `LoadJavaScriptIncludeScript`, `VfCsrf`, `VfHtmlStyleTagXss`,
`VfUnescapeEl`) and the 3 flow rules; the package contains no Visualforce pages or
components and no Flows, so none of the 14 had anything to evaluate. What the official
selector does not reach is the two Graph Engine rules, and the 119 style findings fall
outside it. The official report is the file to upload; the three-tag scan and the
`--rule-selector sfge` run remain the supporting evidence. Full detail is in
[`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

## 11. Editions and compatibility

Lightning Experience only (the app is Lightning Web Components). Professional Edition is
not supported, because it cannot run custom Apex.
