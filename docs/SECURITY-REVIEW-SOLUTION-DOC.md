# Solution Documentation

This document describes the design and security controls of Audit Trail Explorer,
managed 2GP version `1.0.1.4` (`04thm000002tWirAAE`), built on 2026-10-12 from commit
`f0ad675` and promoted the same day.

## 1. What the solution does

Audit Trail Explorer is a read-only UI over the standard Salesforce `SetupAuditTrail`
object. Salesforce retains setup audit records for 180 days and exposes them in Setup
only as a flat list with no search, a 20-row page and a CSV download. This app
provides search, filtering, faceting, paging and export over that same data.

It adds no new data. It is a viewer. It contains no Agentforce components.

**Status.** `1.0.1.4` is a released managed package version; "released" is the
Salesforce packaging state. No version of the package has completed AppExchange
Security Review, and its AppExchange listing is an unpublished draft. The previous
released version is `1.0.0.2` (`04thm000002OtQPAA0`). Install and test evidence is in
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).

## 2. Architecture

```
Browser (Lightning Web Component)
  |  imperative Apex
  v
AuditQueryController          @AuraEnabled facade; the only entry point from the browser
  |  (search and searchUsers call AuditPermissionService first; getContext
  |   returns no audit data and is not gated, as section 4 explains. The
  |   controller also issues one SOQL query directly, against the standard
  |   User object, for the "changed by" type-ahead described in section 6)
  v
AuditQueryService             progressive, time-sliced scan; Apex-side filtering
  |
  v
SetupAuditTrailProvider       implements AuditTrailProvider; the only class
  |                           that queries SetupAuditTrail
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

## 4. Authentication and authorization

The app has a single authorization gate: the standard **View Setup and Configuration**
(`ViewSetup`) user permission, which is the same permission Salesforce itself requires to
view the Setup Audit Trail. The app grants no access that the user did not already have.

`AuditPermissionService.assertCanViewSetup()` enforces this by checking
`Schema.SObjectType.SetupAuditTrail.isAccessible()`. The equivalence between that
describe call and the ViewSetup permission was tested in a scratch org
(`AuditPermissionService.cls:8-12`). `AuditPermissionServiceTest` covers both
directions under `System.runAs` as freshly inserted users on the stock
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
  `PermissionsViewSetup = true` and `PermissionsViewRoles = true` inside the test
  and assigns it to the Minimum Access user. Under `runAs` it then asserts that the
  gate opens, that `search` returns the mock row, that `getContext` reports
  `canViewSetup = true` and that `searchUsers` finds the user's own record. A
  permission set created in the org is never stripped by packaging, so the test
  holds in source, unlocked and managed contexts alike; it is exactly the grant a
  subscriber administrator makes.
- Positive, running user: `allowsUserWithViewSetup` (no `runAs`; the test runner is
  an administrator who holds ViewSetup).
- Packaging equivalence: `packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup`
  asserts under `runAs` that the gate opens exactly when the shipped permission set
  carries ViewSetup, which it does on a source deploy and does not under a managed
  install (see below).

The controller exposes three `@AuraEnabled` methods, all declared `cacheable=false`
(`AuditQueryController.cls:21,40,59`), so neither the access answer nor the
type-ahead results are held in the Lightning client-side action cache: every call is
evaluated afresh against the caller's current permissions. The two that return data,
`search` and `searchUsers`, call the gate before doing any other work; `getContext` is
not gated because it returns no audit data:

| Method        | Gated                | Notes                                                                                                                                                                                                                                                                                                                   |
| ------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `search`      | Yes                  | `assertCanViewSetup()` is the first statement inside the `try` (`AuditQueryController.cls:24`).                                                                                                                                                                                                                         |
| `searchUsers` | Yes                  | Type-ahead over the User object for the "changed by" filter. Gated on the same permission as the audit data so it cannot be used to enumerate the org's user list (`:62-65`).                                                                                                                                           |
| `getContext`  | Not gated, by design | Returns only compile-time constants, `Datetime.now()`, and the calling user's own access boolean. It discloses nothing the caller does not already know about themselves, and the UI needs it to render the "you lack permission" state; the component shows no form until it has answered (`auditExplorer.js:96-132`). |

The shipped permission set `Audit_Trail_Viewer` declares `ViewSetup` and its
`ViewRoles` prerequisite (Salesforce requires `ViewRoles` to enable
`ViewSetup`), plus the app, the tab, and Apex class access. It carries no object
CRUD/FLS grant and no other system permission. Its description states that the two
system permissions take effect for source deploys only
(`Audit_Trail_Viewer.permissionset-meta.xml:4-5`).

**Under managed packaging, the app grants no system permission at all.**
Salesforce strips system permissions from a managed package's permission sets
on install, so in a subscriber org `Audit_Trail_Viewer` carries
`PermissionsViewSetup = false` and grants only the app, its tab, and its Apex
classes. Subscriber administrators must grant "View Setup and Configuration"
themselves. This is verified in
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
  are confirmed by path-sensitive analysis as well as by inspection.
- `SetupAuditTrail` is a read-only platform-owned object, so there is no DML to enforce.

## 6. Injection defenses

**SOQL.** `SetupAuditTrailProvider` is the only class that builds the
`SetupAuditTrail` query string (`SetupAuditTrailProvider.cls:17-35`);
`AuditQueryController.searchUsers` is the only other method that issues SOQL,
against `User` (see section 3 and the LIKE-wildcards note below). In both
queries, every literal fragment is a compile-time string literal. There is no
path by which user input reaches the query text. Every caller-supplied value is
a bind variable: the date bounds (`:lowerBound`, `:upperBound`), the optional
`Action IN :actions` and `CreatedById IN :userIds` predicates, the keyset
position and the row limit. The keyset continuation predicate is appended only
when a position exists and reads `AND (CreatedDate < :upperBound OR Id < :lastId)`
(`:26-28`); `lastId` is typed `Id`, so a value that is not a well-formed Id cannot
reach it (see "Untrusted cursor"). The row limit is bound from the service's
private `scanBatch` field (1000; `@TestVisible` so tests can shrink it, assigned
nowhere outside tests, `AuditQueryService.cls:34-35`), not from the client. The
query carries no list of already-seen record ids and no `NOT IN`.

**LIKE wildcards.** For the user type-ahead, the search term is bound (never
concatenated), and LIKE metacharacters are neutralized in the correct order: backslash
first, then `%`, then `_` (`AuditQueryController.cls:77`). `String.escapeSingleQuotes`
is **not** used on bind values, because it corrupts legitimate names such as
`O'Brien` without adding safety. The escaping is covered by
`searchUsersTreatsPercentAsLiteral`, `searchUsersTreatsUnderscoreAsLiteral` and
`searchUsersTreatsEscapedPercentAsLiteral` (`AuditQueryControllerTest.cls:195-249`).
The test user's last name is chosen to sort near the top under `ORDER BY Name`, so in
an org with fewer than 20 active users who sort ahead of it, an unescaped wildcard
would surface it inside the 20-row limit.

**Untrusted cursor.** The paging cursor round-trips through the browser and is therefore
treated as untrusted input. It is fixed-size (`lastDateMillis`, `lastId`,
`rangeStartMillis`, `rangeEndMillis` and `exhausted`; `AuditCursor.cls:21-30`) because
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
  `blankIdOnPositionedCursorIsRejected` and `cursorIdOfAnotherObjectIsRejected`
  assert the rejection; the first and the last also assert that the provider's
  fetch count stays at 0, i.e. that the rejection happens before any query.
- The pinned bounds are re-clamped (`AuditQueryService.cls:84-93`):
  the lower bound is `max(rangeStartMillis, retention floor)` and the upper bound
  `min(lastDateMillis, rangeEndMillis)`, so a tampered cursor cannot reach below
  the 180-day floor, and any range it describes is one a fresh search could
  request anyway (`continuationBoundsAreReclampedFromAnUntrustedCursor`). Every
  call still runs the permission check first and queries in user mode.
- A cursor that does not deserialize at all fails inside the controller and is masked
  the same way (`searchHidesDeserializationFailureDetail`).

**Client-controlled quantities.** Every value that could widen the scan is bounded on
the server:

- `searchText` is cut to 200 characters and at most 10 whitespace-separated terms
  before it is matched against up to 10,000 rows per call
  (`AuditQueryService.cls:47-48,266-270`; `searchTextIsTruncatedToTwoHundredCharacters`,
  `searchTextHonoursOnlyTheFirstTenTerms`).
- `lastDays` is capped at `RETENTION_DAYS` (180) and resolved against the server
  clock, never the browser's (`:200-211`; `lastDaysIsCappedAtTheRetentionWindow`,
  `lastDaysUsesServerClockAndPinsRange`).
- An explicit start date is clamped to the retention floor
  (`clampsRequestsBelowTheRetentionFloor`).
- `pageSize` defaults to 50 when null or non-positive and is clamped to 200
  (`:213-218`; `pageSizeIsClampedToTheMaximumAndDefaulted`).
- Each call issues at most `maxBatchesPerCall` (10) queries of `scanBatch` (1000)
  rows (`:34-37,116`), so the work one request can cause is fixed whatever the
  filter.

The list filters (actions, sections, user ids) are used only as bind variables or
in-memory comparisons.

**XSS.** The LWC renders exclusively through `{}` template interpolation, which is
context-escaped by the framework. The package contains no `innerHTML`, no
`lwc:dom="manual"`, no `eval`, no `document.write`, and no Visualforce or Aura.

**CSV formula injection.** Audit descriptions echo admin-controlled text (renamed field
labels, for example), so an exported cell could otherwise carry a payload that executes
when the file is opened in Excel or Google Sheets. `csv.js` prefixes any cell beginning
with `=`, `+`, `-`, `@`, whitespace, a C0 control character or a zero-width space with a
single quote. The logic is isolated in its own module so that it can be unit tested,
and the Jest suite tests it. Since `1.0.1` the file starts with the UTF-8 byte-order
mark so that Excel on Windows decodes it correctly; the mark precedes the quoted header
cell `"Date"`, so the guard applies to the data cells exactly as before
(`auditExplorer.js:469-471`).

## 7. Error handling

All three `@AuraEnabled` methods share one contract (`AuditQueryController.cls:7-9`):
each body is wrapped in `try/catch`, and every catchable exception leaves the
controller as an `AuraHandledException`. (A governor-limit `System.LimitException`
cannot be caught in Apex; the per-call bounds in section 6 keep a search well
inside those limits.)

- The permission failure is passed to the client verbatim, because it is the
  actionable, user-facing case: `permissionFailure` (`:101-107`) builds the
  `AuraHandledException` from `AuditPermissionException.getMessage()` and calls
  `setMessage()` with the same text, so the browser receives the sentence naming
  View Setup and Configuration. Without `setMessage()` the client would see only
  "Script-thrown exception".
- Every other exception, from any of the three methods, goes through
  `genericFailure` (`:109-117`): the exception type and message are written to the
  debug log with `System.debug(LoggingLevel.ERROR, ...)`, and the client receives the
  fixed `GENERIC_ERROR` text via `setMessage()`. The text of a caught platform
  exception, which can carry query fragments, therefore never reaches the browser.
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
  (`RunAllTestsInOrg` run `707di0000LCKGo0`), and again 50/50 on 2026-10-14 in
  the reviewer test org provided with this submission (run `707i800000BHk65`).
  Org-wide coverage reads 0% there because Salesforce does not expose
  managed-package coverage to subscribers, so the build-time 96% is the
  meaningful figure. Run ids are recorded in
  [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).
- Tests added or extended in `1.0.1`, by area:
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
- The multi-batch scan and the per-call ceiling are exercised directly.
  `useSmallBatches()` (`AuditQueryServiceTest.cls:48-52`) sets the `@TestVisible`
  fields to `scanBatch = 100` and `maxBatchesPerCall = 3`, and three tests then
  assert fetch counts, scanned counts and cursor positions:
    - `multiBatchScanFindsAMatchInTheLastShortBatch`: 250 rows at distinct
      timestamps, three fetches, only the oldest row matches, and the range is
      reported done;
    - `sameTimestampRowsPageByIdAcrossBatches`: 250 rows in one second, batches of
      100 and pages of 40, with every row returned exactly once across batch and
      page boundaries;
    - `ceilingStopsACallWithoutLosingProgress`: 350 non-matching rows; the first
      call stops at 300 scanned rows with the cursor positioned on the last of them,
      and the second finishes the remaining 50 in one short batch.
- `SetupAuditTrail` cannot be inserted in a test, so the service takes an injectable
  provider interface; `MockAuditTrailProvider` implements the same keyset contract as
  the real query (`(CreatedDate DESC, Id DESC)` order, exclusion at the upper bound).
  `SetupAuditTrailProviderTest` also runs the real production query against
  `SetupAuditTrail`, with no mock;
  `realQueryExecutesWithEveryOptionalFilter` passes a `lastId`, so the keyset predicate
  `Id < :lastId` runs against the real object.
- 26 Jest tests (7 in `1.0.0.2`) covering the component, including the CSV
  escaping, the BOM and object-URL handling, the three access states (spinner, denied,
  error-only), the filter snapshot behind "Search further back", the type-ahead
  stale-response guard, user-pill removal and the 25-call bound on one search
  action. Measured on the `1.0.1` source with the v8 coverage provider: `auditExplorer.js`
  **95.16% statements** / 79.34% branches / 95.65% functions / 94.84% lines, and
  `csv.js`, the formula-injection control, at **100%**. (Jest's default Babel
  coverage provider prints an empty table when Jest runs in an additional working
  copy of the repository created with `git worktree`; the v8 provider does not.)
  `npm run lint` and `npm run prettier:verify` are clean.
- Paging correctness on real data was validated for `1.0.0.2` in the installed
  managed package (`00DRK00000aOfV72AK`, 2026-09-13). There, 65 audit rows sharing
  one timestamp were seeded so that the 50-row page boundary fell inside the block.
  Paging to completion (50, 100, 118) exported **118 data rows against 118 rows in
  the org with 0 duplicate rows**. That run exercised the previous cursor design;
  the `1.0.1` keyset cursor is covered by the unit tests named above.
- A UI smoke test of the `1.0.1` source ran in a scratch org on 2026-10-12. As an
  administrator, it confirmed that the tab loads with data, that the user
  type-ahead returns active users and a selected pill can be removed, and that
  editing a filter shows the "Filters changed" hint. It also confirmed that "Search
  further back" continues the original search (rows 50 to 64) without applying a
  pending term, and that Enter in the search box applies it.
- Via Login As, the same smoke test confirmed that a Minimum Access user holding
  only the packaged permission set sees the full app on a source deploy. On a
  managed install, that user sees the denied message with no form and Export
  disabled, and sees the app once a locally created permission set carrying
  ViewSetup and ViewRoles is assigned.
- On 2026-10-14 the released `1.0.1.4` was checked the same way in the reviewer
  test org provided with this submission. The user holding only the packaged
  permission set sees the access message, and the user who also holds the local
  View Setup and Configuration permission set gets the search form, the default
  search with results, and Export CSV.

## 9. Third-party code

**None.** The package contains no third-party JavaScript library, no static resource, and
no npm dependency shipped to the runtime. RetireJS reports zero findings.

## 10. Static analysis

Two scan reports are attached to this submission.

**Salesforce Code Analyzer (document 08).** Salesforce's AppExchange command was
run on 2026-10-12 against commit `f0ad675`, the source of `1.0.1.4`, with
Code Analyzer plugin 5.16.0:

```
sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security \
  --output-file CodeAnalyzerReport.html
```

The selector resolved to 62 rules from 5 engines (51 PMD, 4 RetireJS, 3 ESLint,
3 Flow and 1 regex rule), and the run reported **"Found 0 violations."** The
report footer lists the engine modules bundled with plugin 5.16.0 (core 0.53.0
with the PMD, ESLint, regex and RetireJS engines); the Flow engine had no Flow
metadata to scan and is not listed. The attached `CodeAnalyzerReport.html` is
64,954 bytes, SHA-256
`03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`. The
repository's `code-analyzer.yml`, which the plugin reads from the working
directory, loads the project's ESLint configuration, so `npm ci` has to run
before the command.

**Source Code Scanner (document 09).** The Partner Security Portal scan of
`1.0.1.4` reports no Critical, High or Serious issue and no quality issue. Its
three Medium issues are all in one test class and are explained as false
positives in document 05.

**Broader Code Analyzer scan.** Each release is also scanned with a wider
selection, and the same scan runs weekly in CI:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector Security \
  --rule-selector AppExchange
```

This resolves to 310 rules across six engines (202 ESLint, 94 PMD, 6 regex,
4 RetireJS, 2 CPD and 2 Graph Engine rules). The `Security` tag adds the Graph
Engine rules `sfge:ApexFlsViolation` and `sfge:DatabaseOperationsMustUseWithSharing`,
which neither of the other tags selects. On `f0ad675` (2026-10-12) the scan
reported 0 Critical, 0 High, 13 Moderate and 106 Low findings, none of them
tagged `Security`, `AppExchange` or `ErrorProne`, and the GitHub Actions
workflow reproduced the same counts on 2026-10-13 (run `38462017378`). All 119
are code-quality or style findings. None is suppressed, and each is explained in
document 05:

| Rule                                   | Severity | Count | Where                                                        |
| -------------------------------------- | -------- | ----- | ------------------------------------------------------------ |
| `pmd:ApexUnitTestClassShouldHaveRunAs` | Low      | 45    | The four test classes                                        |
| `pmd:ApexDoc`                          | Low      | 38    | Apex classes and test classes                                |
| `slds:no-hardcoded-values-slds2`       | Low      | 22    | `auditExplorer.css`                                          |
| `pmd:ExcessiveParameterList`           | Moderate | 4     | The provider interface, its implementation and the test mock |
| `pmd:CognitiveComplexity`              | Moderate | 3     | `AuditQueryService` (class and `search`) and the test mock   |
| `pmd:CyclomaticComplexity`             | Moderate | 3     | `AuditQueryService.search` and test code                     |
| `lwc:no-inline-disable`                | Moderate | 2     | Two single-line suppressions of `no-await-in-loop`           |
| `pmd:NcssCount`                        | Moderate | 1     | `AuditQueryService.search`                                   |
| `pmd:AvoidDebugStatements`             | Low      | 1     | `AuditQueryController.genericFailure`                        |

**Graph Engine on its own.** The Graph Engine was also run by itself on
2026-10-12 (`--rule-selector sfge`). It analyzed 6,537 paths from all 3 entry
points with no internal error, and the two security rules,
`sfge:ApexFlsViolation` and `sfge:DatabaseOperationsMustUseWithSharing`,
reported 0 violations. Because that run selects every Graph Engine rule, it
also reported one Performance finding, `sfge:AvoidDatabaseOperationInLoop`
(scored High in the report), on the batch loop at `AuditQueryService.cls:116`. The loop issues at most 10
queries per transaction; document 05 explains why it stays.

Earlier scans, their environments and the scan history of the `1.0.0.2` source
are recorded in [`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

## 11. Editions and compatibility

Lightning Experience only (the app is Lightning Web Components). Supported editions are
Enterprise, Unlimited, Performance and Developer. Professional and Group Editions are
not supported and have not been tested; Base Edition cannot install the package because
that edition does not support custom Apex.
