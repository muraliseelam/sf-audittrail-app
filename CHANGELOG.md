# Changelog

All notable changes to Audit Trail Explorer are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses the packaging version number (`versionNumber` in
`sfdx-project.json`) rather than strict SemVer, consistent with how
Salesforce packages are versioned.

## [Unreleased]

## [1.0.1] - 2026-10-12

Released managed 2GP version `1.0.1.4` (`04thm000002tWirAAE`), built on
2026-10-12 from commit `f0ad675` and promoted from beta the same day
(`sf package version report`: Released true, Ancestor Version `1.0.0.2`, Code
Coverage 96%, Code Coverage Met true). It installs as an upgrade over the
released `1.0.0.2` (`04thm000002OtQPAA0`), which remains released as the
previous version. Three earlier `1.0.1` betas were built and superseded on the
way - `1.0.1.1` (`04thm000002tVurAAE`), `1.0.1.2` (`04thm000002tVwTAAU`) and
`1.0.1.3` (`04thm000002tVy5AAE`) - and none was promoted; their aliases stay in
`sfdx-project.json` for traceability. Tag `v1.0.1` marks the release commit,
whose `force-app` is identical to `f0ad675`.

**Not an AppExchange release.** The package has not been submitted for
AppExchange Security Review, has not been reviewed and is not listed on
AppExchange. "Released" is the Salesforce packaging state only. Installation is
by direct URL:
<https://login.salesforce.com/packaging/installPackage.apexp?p0=04thm000002tWirAAE>
(sandboxes: `test.salesforce.com`), or with
`sf package install --package 04thm000002tWirAAE --target-org my-org --wait 20`
followed by
`sf org assign permset --name atexplorer__Audit_Trail_Viewer --target-org my-org`.

**Both grants are still required.** The installed
`atexplorer__Audit_Trail_Viewer` permission set shows
`PermissionsViewSetup=false` and `PermissionsViewRoles=false` after every
`1.0.1` install, so an administrator must grant "View Setup and Configuration"
separately. The permission set's own description now says so.

### Added

- `AuditFilter.lastDays`: preset ranges send the number of days instead of
  bounds computed from the browser clock. `AuditQueryService.pinRange`
  resolves the window on the server on the first call of a search (end = now,
  start = now minus min(`lastDays`, 180)) and pins it in the cursor as
  `rangeStartMillis`/`rangeEndMillis`; every continuation pages over exactly
  that window whatever the client sends later. Zero or negative `lastDays`
  means the explicit dates apply; a preset longer than retention is capped at
  the retention window. Tests: `lastDaysUsesServerClockAndPinsRange` (which
  also sends a different filter on the continuation call and asserts the
  pinned range wins), `lastDaysIsCappedAtTheRetentionWindow`,
  `lastDaysZeroMeansExplicitDatesApply`,
  `negativeLastDaysMeansExplicitDatesApply`.
- Cursor validation. `AuditCursor.lastIdValue()` rejects a continuation cursor
  whose id is blank, not a well-formed Id, or an Id of an object other than
  `SetupAuditTrail`, before any query runs; the controller turns the rejection
  into the generic client message. The pinned bounds carried in the cursor are
  re-clamped on every call (start up to the retention floor, position down to
  the range end), so an edited cursor cannot widen the scan. A cursor that
  carries a position but not both pinned bounds - which only a hand-built
  payload looks like, as the client round-trips the whole cursor - restarts
  the search instead of resuming it. Tests:
  `malformedContinuationCursorIsRejected`,
  `blankIdOnPositionedCursorIsRejected`, `cursorIdOfAnotherObjectIsRejected`,
  `continuationBoundsAreReclampedFromAnUntrustedCursor`,
  `continuationCursorMissingRangeRestartsTheSearch`,
  `searchHidesInternalErrorDetail`, `searchHidesDeserializationFailureDetail`,
  `searchRoundTripsCursorJson`.
- Free-text bounds. `searchText` is cut to 200 characters and only its first
  10 whitespace-separated terms are honoured (`MAX_SEARCH_TEXT_LENGTH`,
  `MAX_SEARCH_TERMS` in `AuditQueryService`), because the term loop runs once
  per scanned row and a call can scan up to 10,000 rows. Tests:
  `searchTextIsTruncatedToTwoHundredCharacters`,
  `searchTextHonoursOnlyTheFirstTenTerms`.
- `AuditQueryService.scanBatch` and `maxBatchesPerCall` are `@TestVisible`
  variables (formerly the constants `SCAN_BATCH` and `MAX_BATCHES_PER_CALL`;
  the production values 1000 and 10 are unchanged and nothing outside tests
  assigns them). `AuditQueryServiceTest.useSmallBatches()` sets them to 100
  and 3 so a few hundred mock rows exercise the multi-batch and per-call
  ceiling paths: `multiBatchScanFindsAMatchInTheLastShortBatch`,
  `sameTimestampRowsPageByIdAcrossBatches`,
  `ceilingStopsACallWithoutLosingProgress`.
- `auditExplorer`: a filter snapshot. The filter a search started with is kept
  as `activeFilterJson`, and every "Search further back" call reuses it
  verbatim; edits made since show the hint "Filters changed. Click Search to
  apply them; Search further back continues the current search." until the
  next Search (button or Enter in the search box) picks them up.
- `auditExplorer`: tri-state access. `canViewSetup` is undefined until
  `getContext` answers, so the component shows a `lightning-spinner`
  ("Loading") and no form until then, the "View Setup and Configuration"
  message when access is false, and only the error - no form, no search - when
  `getContext` fails. Export CSV is enabled only when access is confirmed and
  rows exist.
- Apex tests: 50 test methods (was 29) across `AuditPermissionServiceTest`,
  `AuditQueryControllerTest`, `AuditQueryServiceTest` and
  `SetupAuditTrailProviderTest`. Besides those named above:
  `restrictedUserWithLocalViewSetupPermissionSetCanUseEveryEntryPoint` (the
  deterministic positive case: a Minimum Access user granted View Setup
  through a locally created permission set can use `search`, `getContext` and
  `searchUsers`), `restrictedUserGetContextReportsNoAccessWithoutThrowing`,
  `pageSizeIsClampedToTheMaximumAndDefaulted`, `searchUsersFindsActiveUsers`
  (against an inserted user with a distinctive last name),
  `searchUsersTreatsPercentAsLiteral`, `searchUsersTreatsUnderscoreAsLiteral`,
  `searchUsersTreatsEscapedPercentAsLiteral`,
  `exhaustedScanReportsRangeBoundary`,
  `exhaustedScanWithRowsReportsRangeBoundaryNotOldestRow`,
  `blankFieldDoesNotMatchTheWordNull`.
- Jest: 26 tests (was 7) covering the pill removal, the filter snapshot and
  hint, the filter payload for presets and custom ranges, the type-ahead
  (selection, two-character minimum, stale-response guard, error surfacing),
  the access tri-state, CSV export (BOM, object-URL lifecycle, no-row no-op)
  and the search-loop bounds (25-call cap, Stop). `auditExplorer.js` coverage
  is 95.16% statements / 79.34% branch / 95.65% functions / 94.84% lines
  (measured with the v8 coverage provider; the stock Babel provider reports an
  empty table when run inside a git worktree on the maintainer's machine, a
  measurement quirk, not a code problem) and `csv.js` 100%.
- `sfdx-project.json`: `packageAliases` for `Audit Trail Explorer@1.0.1-1`
  through `@1.0.1-4`.
- `.github/workflows/code-analyzer.yml`: a weekly and on-demand Salesforce
  Code Analyzer workflow, kept out of the per-PR gate. It fails unless the
  three-flag selector resolves to 310 rules from 6 engines, runs the Graph
  Engine on its own, and fails unless that run reports the full path analysis
  over 3/3 entry points (the pinned count is a property of the source: 14,503
  paths for `1.0.0.2`, 6,537 for this release); a bare "0 violations" is never
  accepted as proof.
- `docs/CODE-ANALYZER-SCAN-RECORD.md`: the 2026-09-10 (plugin 5.15.0,
  workstation) and 2026-09-19 (plugin 5.16.0, CI) scan records, identical
  rule for rule and count for count, and the 2026-10-11 workstation
  reproduction (plugin 5.16.0, Runs 1-3), which includes Salesforce's official
  AppExchange selector run from a clean `934f200` worktree: 62 rules from 5
  engines, "Found 0 violations.", exit 0.
- `docs/SECURITY-REVIEW-SUBMISSION.md` (2026-10-11): the AppExchange Security
  Review submission plan - verified status, blockers, should-fix and accepted
  findings, the end-to-end runbook, listing-asset gaps, fees and timeline,
  and open questions.
- `docs/USER-GUIDE.md`: the end-user and reviewer usage guide the submission
  plan lists in its section 2.3 - the two grants, a test-user setup for
  reviewers, date range, free-text search, section and user filters, facets,
  row detail, CSV export, limits, troubleshooting and uninstall, each
  behaviour claim pointing at the file and line that implements it.
- `docs/SECURITY-PROGRAM-STATEMENT.md`: the one-page security program
  statement the submission plan lists in its section 2.3, drafted for the
  publisher's signature; the publisher name reads "(to be supplied by the
  publisher)".

### Changed

- Paging is keyset-based on `(CreatedDate, Id)`. `AuditCursor` carries
  `lastDateMillis` and `lastId` instead of a `seenIdsAtLastDate` list, so it
  stays a fixed size however many rows share a timestamp; the 5,000-id cap
  (`MAX_SEEN_IDS`) and its test are gone with the list.
  `SetupAuditTrailProvider` orders by `CreatedDate DESC, Id DESC` and resumes
  with `AND (CreatedDate < :upperBound OR Id < :lastId)` in place of
  `AND Id NOT IN :excludeIds`. `AuditTrailProvider.fetch` takes `Id lastId`
  where it took `Set<Id> excludeIds`; `MockAuditTrailProvider` sorts its rows
  the same way and applies the same keyset exclusion.
  `AuditFilter.startDate()`/`endDate()`, unused once the range is pinned in
  the cursor, are removed.
- Uniform error contract in `AuditQueryController`: every entry point throws
  only `AuraHandledException`. `searchUsers` and `getContext` are wrapped the
  way `search` already was; a permission failure passes its user-facing text
  through `permissionFailure`, which calls `setMessage` so the client sees the
  permission name instead of "Script-thrown exception"; every other failure
  collapses to the generic message.
  `blocksControllerEntryPointsForUnprivilegedUser` now asserts that the
  message names View Setup and Configuration for both `search` and
  `searchUsers`.
- Exhausted scans report the range boundary. Once the range is exhausted,
  `scannedThroughMillis` is the lower bound of the pinned window rather than
  the oldest row that happened to be examined, so the "examined N events back
  to ..." date names the window actually covered; an unfinished call still
  reports the oldest row it examined.
- `AuditQueryService.search` is written with as few conditionals as the
  behaviour allows: `Math.max`/`Math.min` clamps in `search()` and
  `pinRange()`, observed sections and actions collected unconditionally into
  sets with null and blank removed once after the loop, one ternary deciding
  whether the client sent a complete continuation cursor, a plain cast for the
  id `consume()` just wrote, a counted loop over the trimmed term split, and a
  set-based null drop in `CompiledFilter.matches`. This is what keeps the
  entry point analysable by the Graph Engine (see "Static analysis" below):
  the `1.0.1.2` and `1.0.1.3` betas had pushed `AuditQueryController.search`
  past a 1,800,000 ms per-path budget.
- `auditExplorer`: presets send `lastDays` and no explicit bounds, and the
  "Today" preset is relabelled "Last 24 hours", which is what the server
  computes for it. For a custom range a blank "To" is sent as null and
  resolved as "now" on the server; a blank "From" defaults to seven days ago
  and a "From" below the retention floor is clamped to it on the client, as
  before.
- `auditExplorer`: the in-progress indicator is a `lightning-spinner`
  ("Searching") in place of the `lightning-progress-bar`.
- `Audit_Trail_Viewer` permission set description: now reads that View Setup
  and Configuration (and View Roles) take effect for source deploys only and
  that a managed-package install strips them, so an administrator must grant
  View Setup and Configuration separately.
- Tests: `AuditPermissionServiceTest` filters its `PermissionSet` and
  `ApexClass` lookups by `NamespacePrefix`, so under a managed install they
  find the packaged copies; `System.assert*` calls are replaced by `Assert.*`
  with messages; vacuous assertions are replaced
  (`pageSizeIsClampedToTheMaximumAndDefaulted` takes the place of
  `permissionCheckRunsRealQuery`, `contextExposesRetentionWindow` asserts
  `canViewSetup` is true, the packaged-permission-set test asserts a
  positioned result);
  `SetupAuditTrailProviderTest.realQueryExecutesWithEveryOptionalFilter`
  passes a `lastId` so the `Id < :lastId` predicate executes against the real
  object.
- `sfdx-project.json`: `versionName` "Version 1.0.1", `versionNumber`
  `1.0.1.NEXT`, `ancestorVersion` `HIGHEST` (which resolved to `1.0.0.2`).
- `code-analyzer.yml`: the Graph Engine `java_thread_timeout` is raised from
  600000 to 1800000 ms and the comment rewritten (the path count is a property
  of the code; 14,503 was the `1.0.0.2` figure). In
  `.github/workflows/code-analyzer.yml` the job `timeout-minutes` goes from 45
  to 90 and the pinned path count from 14503 to 6537.
- The Code Analyzer workflow runs on Node 22, which the Salesforce CLI
  requires (its `engines` field). On Node 20 the 2026-09-14 scheduled run
  crashed at CLI startup, before any rule was loaded.
- Documentation reconciled against the code, the live-org record and the
  packaging state, on 2026-09-12, 2026-09-13 and 2026-10-11: packaging and
  review-status wording; the Developer Edition install, the Base Edition
  install failure (editions without custom Apex) and the functional UI
  verification recorded in `docs/LIVE-ORG-VALIDATION.md`; per-version test
  counts, CI command names and listing-copy claims; and the structure of
  this changelog.

### Fixed

- `auditExplorer.js`: removing a user pill did nothing.
  `lightning-pill-container`'s `itemremove` event carries `{ item, index }`,
  not the pill's `name`;
  `handleUserRemove` now reads `detail.item.name` and falls back to the pill
  at `detail.index`. The user is dropped from the next search (Jest) and the
  pill's x removes it in the org (manual smoke test below).
- `AuditQueryService.CompiledFilter.matches`: a blank `display`, `section`,
  `action` or `userName` reached the haystack as the literal word "null"
  (`String.valueOf(null)`), so the search term "null" matched every row with
  an empty field. Null fields are now dropped before the haystack is built
  (`blankFieldDoesNotMatchTheWordNull`).
- `auditExplorer.js` CSV export: the file now starts with the UTF-8 BOM, which
  Excel on Windows needs to decode non-ASCII text (the first cell is still the
  quoted header "Date", so the formula guard in `csv.js` is unaffected), and
  the object URL is no longer revoked synchronously after `click()`, which can
  cancel the download; it is kept until the next export or
  `disconnectedCallback`.
- `auditExplorer.js` type-ahead: a lookup that failed was swallowed silently
  and a response arriving after the term had changed could overwrite the newer
  list. Failures now surface through the component's error banner, and a
  response whose term no longer matches the box is dropped.
- `code-analyzer.yml`: Code Analyzer 5.16.0 stopped applying an ESLint
  configuration file it had merely discovered, so the ESLint engine fell back
  to its bundled defaults and the selector silently resolved to 309 rules
  (201 eslint). The project config is now passed explicitly through
  `eslint_config_file`; the selector again resolves to 310 rules (202
  eslint), identical to the 5.15.0 baseline. The CI rule-count check caught
  the drift on 2026-09-19. Consequence: in a checkout without `node_modules`
  the official AppExchange command's eslint engine fails with "Cannot find
  module 'eslint/config'" - an environment error, not a code finding; run
  `npm ci` first.
- `jest.config.js`: `npm run test:unit:coverage` instrumented nothing, wrote
  an empty `coverage-final.json` and reported 0% for every file while still
  exiting 0. The coverage glob is now limited to `.js` files outside
  `__tests__`; at the time of the fix measured coverage was 70.64% statements
  for `auditExplorer.js` and 100% for `csv.js` (7/7 Jest tests). The `1.0.1`
  figures are under "Added" above.

### Security

- `getContext` and `searchUsers` are `@AuraEnabled(cacheable=false)` (both
  were `cacheable=true`), so the access flag and the user type-ahead results
  are no longer eligible for the client-side Lightning cache. The `1.0.0`
  statement below that type-ahead results are never persisted, cached or
  logged now holds on the client as well as the server.
- The client-supplied id list is gone with the keyset cursor: the only
  client-controlled values in a continuation are one timestamp, one Id, which
  must be a well-formed `SetupAuditTrail` Id, and two pinned bounds that are
  re-clamped on the server. There is no list bind and no cap to tune.
- The date range is owned by the server: a stale or skewed browser clock, or
  a different filter sent on a continuation call, cannot widen the window
  (`lastDaysUsesServerClockAndPinsRange`).
- The free-text bounds (200 characters, 10 terms) cap the per-row cost of the
  haystack test for the up to 10,000 rows one call may scan.
- No internal detail reaches the browser from any entry point: exception
  text, query text and the word "Malformed" are all masked; the permission
  message is the only pass-through, and `searchUsers` now follows the same
  contract as `search`.
- Export CSV is gated on confirmed access as well as on rows, and nothing
  actionable is rendered before `getContext` has answered.
- `docs/SECURITY-REVIEW-SUBMISSION.md` records the audit this release answers
  (67 candidates, 63 confirmed: 0 blocker, 0 high, 12 medium, 41 low, 10
  info; 4 rejected). Resolved here by code: its items 3.4 to 3.8 and 3.10 to
  3.12 and the section 4 code rows. Deliberately unchanged and accepted: the
  SLDS hardcoded values (now 22 hits), the type-ahead list and live-region
  semantics, browser-timezone formatting in the detail panel and progress
  text, the auto-search on connect, the permission set still declaring
  ViewSetup/ViewRoles for source deploys, publisher org ids in the docs,
  unpinned CI tool versions and the absence of a Jest `coverageThreshold`.

### Verified in a live org (not run in CI)

- **Package build and promotion.** `1.0.1.4` (`04thm000002tWirAAE`,
  `Package2VersionId` `05ihm0000001CK5AAM`) built on 2026-10-12 from `f0ad675`
  at 96% coverage with `HasPassedCodeCoverageCheck=true`;
  `sf package version promote --package 04thm000002tWirAAE` succeeded on
  2026-10-12. The superseded betas `1.0.1.1` (from `d931ba7`, `force-app`
  identical to `47bd65f`), `1.0.1.2` (from `41e2a29`) and `1.0.1.3` (from
  `f05ed25`) also built at 96% with the coverage check passed; each was
  replaced for a Graph Engine reason recorded under "Static analysis".
- **Source deploy of `f0ad675`** to a namespaced scratch org with
  `RunLocalTests`: deploy `0Afh1000000NfiTCAS`, 18/18 components, **50 run, 0
  failed**; per-class coverage `AuditCursor` 100%, `AuditQueryController`
  92%, `AuditSearchResult` 100%, `AuditQueryService` 96%,
  `AuditPermissionService` 100%, `AuditEventRow` 100%,
  `SetupAuditTrailProvider` 100% (`AuditFilter` has no executable lines). The
  `main` baseline `f27a009` in the namespaced scratch org `ate-101`: deploy
  `0Afh1000000N46ACAS`, 18/18 components, 29 run, 0 failed.
- **Managed install** into the clean, un-namespaced scratch org `ate-mgd`:
  `1.0.1.1` installed (request `0Hfdi000002FareCAC`), then upgraded to
  `1.0.1.2` (`0Hfdi000002FhebCAC`), `1.0.1.3` (`0Hfdi000002FiKYCA0`) and
  `1.0.1.4` (`0Hfdi000002FyKTCA0`), every request SUCCESS;
  `InstalledSubscriberPackage` shows `04thm000002tWirAAE` build 4.
  `RunAllTestsInOrg` on `1.0.1.4`: run `707di0000LCKGo0`, **50 passed, 0
  failed** (on `1.0.1.1`, `1.0.1.2` and `1.0.1.3`: runs `707di0000LCGPxR`,
  `707di0000LCGvO4` and `707di0000LCHRya`, each 50 passed, 0 failed).
  Org-wide coverage reads 0% there because Salesforce does not expose
  managed-package coverage to subscribers; the build-time 96% is the
  meaningful figure.
- **Permission stripping re-confirmed.** After every `1.0.1` install the
  installed `atexplorer__Audit_Trail_Viewer` shows `PermissionsViewSetup=false`
  and `PermissionsViewRoles=false`. Via Login As in `ate-mgd`, a Minimum
  Access - Salesforce user holding only the packaged permission set sees the
  "View Setup and Configuration" message, no form, Export CSV disabled and no
  spinner; after a locally created permission set (`PermissionsViewSetup` and
  `PermissionsViewRoles` true) was assigned, the app loaded with data for that
  user - the two-grant sequence `README.md` describes. In the source-deploy
  org `ate-101` the same kind of user sees the full app, because the shipped
  permission set's ViewSetup entry is honoured outside managed packaging.
- **Manual UI smoke test** (2026-10-12, `ate-101`, administrator): the tab
  loads with data; the type-ahead returns active users; selecting one adds a
  pill and the pill's x removes it (the `1.0.0.2` defect is gone); editing a
  filter shows the "Filters changed" hint; "Search further back" continued the
  original search (50 to 64 rows; the progress text read "Search complete -
  examined 64 events back to" followed by the range boundary) without applying
  a pending non-matching term; Enter in the search box applied it (0 events,
  empty state, hint cleared).
- Operational notes: for about 15 minutes after `sf package version create`
  the new version was not yet visible to the subscriber org and
  `sf package install` failed with "No record found ... FROM
  SubscriberPackageVersion"; the install succeeded once the org's Tooling API
  returned the version (`InstallValidationStatus NO_ERRORS_DETECTED`). A
  Minimum Access - Salesforce user in a scratch or Developer Edition org also
  needs the "Lightning Experience User" permission before Lightning Experience
  itself loads, and Login As requires "Administrators Can Log in as Any User".

### Static analysis (not run in CI at release time)

- **Official AppExchange command** on `f0ad675`
  (`sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security --output-file CodeAnalyzerReport.html`;
  plugin 5.16.0, `@salesforce/cli` 2.153.5, Node 24.20.0, OpenJDK 21.0.12.1,
  run 2026-10-12 from the release worktree after `npm ci`): 62 rules from 5
  engines, **"Found 0 violations."** (executed: retire-js, eslint, regex, pmd;
  there is no Flow metadata for the flow engine). The report
  (`CodeAnalyzerReport.html`, 64,954 bytes, SHA-256
  `03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`) is kept
  outside the repository by the maintainer and is the one to upload with the
  `1.0.1.4` submission; the `1.0.0.2` and `1.0.1.2` report hashes are
  superseded for that purpose.
- **Three-tag union** (`Recommended` + `Security` + `AppExchange` with the
  committed `code-analyzer.yml`, 310 rules from 6 engines, run 2026-10-12, 11
  minutes) on `f0ad675`: exit 0, **0 Critical, 0 High**, 119 violations across
  16 files = 13 Moderate + 106 Low, no finding carrying the `Security`,
  `AppExchange` or `ErrorProne` tag. By rule:
  `ApexUnitTestClassShouldHaveRunAs` 45, `ApexDoc` 38,
  `@salesforce-ux/slds/no-hardcoded-values-slds2` 22, `ExcessiveParameterList`
  4, `CognitiveComplexity` 3, `CyclomaticComplexity` 3,
  `@lwc/lwc-platform/no-inline-disable` 2 (both the deliberate
  `no-await-in-loop` for sequential cursor-driven calls), `NcssCount` 1,
  `AvoidDebugStatements` 1. Versus the `1.0.0.2` baseline (85 = 11 Moderate +
  74 Low): +19 RunAs (new tests), +9 ApexDoc (new methods), +4 SLDS (new
  CSS), +1 CyclomaticComplexity, +1 no-inline-disable (Jest);
  `FieldNamingConventions`, `AvoidDeeplyNestedIfStmts` and
  `ApexUnitTestClassShouldHaveAsserts` no longer appear. All are the families
  the `1.0.0.2` disposition already accepts.
- **Graph Engine on its own** (`--rule-selector sfge`, `java_thread_timeout`
  1800000, 2g heap, 4 threads, 757 s on an otherwise idle host) on `f0ad675`:
  "analyzed 6537 path(s) from 3 entry point(s)", 3/3 entry points, no
  "Internal execution error" - the validity bar is met. The two Security rules
  (`ApexFlsViolation`, `DatabaseOperationsMustUseWithSharing`) report 0
  violations. The one finding is `sfge:AvoidDatabaseOperationInLoop`
  (Performance, not Security or AppExchange) on the batch loop in
  `AuditQueryService.search`: by design and bounded - the loop is the
  progressive, time-sliced scan the application exists for, issues at most
  `maxBatchesPerCall` (10) queries per transaction against the 100-query
  limit, and the ceiling is pinned by `ceilingStopsACallWithoutLosingProgress`;
  accepted. The path count moved from 14,503 (`1.0.0.2`) to 6,537 because of
  the branch trimming.
- **Why there were four builds.** `1.0.1.1`'s Graph Engine run flagged
  `sfge:ApexNullPointerException` on `working.lastIdValue()`, a false positive
  (the null check had moved into a separate Boolean the path analysis cannot
  correlate), fixed in `41e2a29`. On `1.0.1.2` the standalone run could not
  finish: `AuditQueryController.search` reported "Path evaluation timed out"
  at the stock 600 s per-path budget and again at a diagnostic 1,800 s (3
  paths from 2 entry points), printing the vacuous "0 violations" that
  `code-analyzer.yml` warns about; `f05ed25` trimmed the branches inside the
  scan loop. On `1.0.1.3` the run still timed out at 1,800 s because of the
  remaining multipliers in the cursor normalisation before the loop; `f0ad675`
  removed those. The cause was path explosion from conditionals `1.0.1` had
  added on the search path, not the host; the behaviour is unchanged.

## [1.0.0] - 2026-09-09

Released managed 2GP version `1.0.0.2` (`04thm000002OtQPAA0`), promoted from
beta on 2026-09-09. A released managed version installs into any org type,
including production, and carries normal managed-package upgrade guarantees.

**Not an AppExchange release.** This package has not been submitted for or
passed AppExchange Security Review and has no AppExchange listing. "Released"
here is the Salesforce packaging state only. Installation is by direct URL:
<https://login.salesforce.com/packaging/installPackage.apexp?p0=04thm000002OtQPAA0>

**Both grants are required.** Managed packaging strips system permissions on
install, so after assigning `atexplorer__Audit_Trail_Viewer` an administrator
must separately grant "View Setup and Configuration". Re-verified against the
released version: `PermissionsViewSetup` is `false` on the installed
permission set.

### Added

- **Managed 2GP package lineage.** Namespace `atexplorer` is now linked to
  the packaging Dev Hub, and a managed package
  (`0Hohm0000000NHZCA2`) has been created from this source. Released managed
  version `1.0.0.2` (`04thm000002OtQPAA0`) builds at **97% coverage** with
  `HasPassedCodeCoverageCheck=true` and 43 metadata files. This supersedes
  the earlier unlocked lineage, which cannot be converted in place; the
  unlocked package aliases are retained in `sfdx-project.json` for
  traceability only.
- `AuditPermissionServiceTest.packagedPermissionSetGrantsApexAccessRegardlessOfPackaging`,
  pinning that the shipped permission set still grants access to the app's
  Apex classes under managed packaging, where system permissions are
  stripped but class access is not.
- `LICENSE` (Apache-2.0), `SECURITY.md`, `CONTRIBUTING.md`, and this
  `CHANGELOG.md` for AppExchange/public-repository release readiness.
- `docs/PRIVACY.md` describing the app's zero-storage, zero-callout data
  handling.
- `docs/ARCHITECTURE.md` describing the component design and known
  limitations.
- `docs/APPEXCHANGE-LISTING.md`, a draft of the AppExchange listing copy.
- CI workflow (`.github/workflows/ci.yml`) that runs `npm run lint`,
  `npm run prettier:verify`, and `npm run test:unit:coverage` on every push
  and pull request.
- `docs/LIVE-ORG-VALIDATION.md` recording live-org validation performed
  outside CI (package install, `RunLocalTests` results, and the
  namespace-linkage blocker for a managed 2GP package that stood when the
  file was first written; the managed lineage above resolved it).

### Changed

- **Managed-package installs require the subscriber's administrator to grant
  "View Setup and Configuration" separately.** Salesforce strips system
  permissions from a managed package's permission set on install, as an
  anti-privilege-escalation measure, so the shipped `Audit_Trail_Viewer`
  permission set cannot grant `ViewSetup` to subscribers even though it
  declares it. The permission set still grants the app, its tab and its Apex
  classes, and remains sufficient on its own for source deploys and the
  unlocked package. The runtime error message, the in-app empty state, the
  permission set description, and the `README.md` install steps now state
  this explicitly rather than telling subscribers the shipped permission set
  alone is enough.
- `AuditPermissionServiceTest.packagedPermissionSetAloneGrantsAccess` is
  replaced by
  `packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup`, which asserts
  the access gate opens exactly when the assigned permission set genuinely
  carries `ViewSetup`. The previous test asserted an outcome the managed
  platform forbids, and failed on first install of the managed beta.

### Verified in a live org (not run in CI)

- **Managed beta `1.0.0.2` (`04thm000002OtQPAA0`)** installs successfully
  into a **clean scratch org** with no packages installed beforehand, the
  namespaced `atexplorer__Audit_Trail_Viewer` permission set assigns without
  error, and `RunAllTestsInOrg` passes **29/29 with 0 failures**. Package
  build reported 97% coverage with the coverage check passed. (Org-wide
  coverage reads 0% in the subscriber org because Salesforce does not expose
  managed package code coverage to subscribers; the build-time figure is the
  meaningful one.)
- **Source deploy of the same commit** to a clean scratch org passes
  `RunLocalTests` **29/29 with 0 failures**, confirming the shipped
  permission set alone is still sufficient outside managed packaging.
- **The administrator workaround is empirically verified**, not merely
  documented. In the managed subscriber org, a freshly created Minimum
  Access user assigned only the installed `Audit_Trail_Viewer` cannot open
  the app; the same user, additionally granted `ViewSetup` through a separate
  local permission set, can. Both assertions pass.
- Managed beta `1.0.0.1` (`04thm000002OtOnAAK`) is superseded: it installed
  cleanly but failed 1 of 28 Apex tests, which is what surfaced the managed
  permission-stripping behavior described under **Changed**.
- Superseded unlocked builds: package version `1.0.0.2`
  (`04tbm000000gaALAAY`) installed into a clean QA scratch org with
  `RunLocalTests` 28/28 and 97% org-wide coverage; `1.0.0.1`
  (`04tbm000000aeOjAAI`) passed 22/22 against earlier source.
- **This package has not undergone AppExchange security review and has no
  AppExchange listing.** Managed version `1.0.0.2` was promoted to a released
  packaging state on 2026-09-09; that is a packaging state, not a review
  outcome.

### Static analysis (not run in CI at release time)

- Salesforce Code Analyzer (plugin 5.15.0), run 2026-09-10 against commit
  `934f200` (tag `v1.0.0`, the source that built the released managed
  version), across all six engines (PMD, Graph Engine, ESLint, CPD, RetireJS,
  secrets-regex) using the `Recommended` + `Security` + `AppExchange` rule
  selectors, which resolve to **310 rules**. Result: **0 Critical, 0 High**,
  11 Moderate, 74 Low, and no finding carrying the `Security`, `AppExchange`
  or `ErrorProne` tag. The Graph Engine analysed 14,503 paths across 3/3
  entry points with 0 violations. Reproduced rule for rule and count for
  count in CI on 2026-09-19 with plugin 5.16.0, against `force-app` source
  unchanged since the tag. See `docs/CODE-ANALYZER-SCAN-RECORD.md` for both
  runs and `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md` for the per-rule
  disposition of the Moderate/Low items.

### Fixed

- `.prettierrc` was missing `tabWidth`/`printWidth`/`singleQuote`, so
  `npm run prettier:verify` failed on every source file even though no file
  had actually drifted from the project's real style. The settings now match
  the codebase, and `package-lock.json` (npm-managed, always 2-space) is
  excluded from Prettier formatting to avoid churn on every `npm install`.
- `csv.js`: the CSV formula-injection guard only recognized ASCII
  `= + - @` as formula-trigger characters. It now also recognizes their
  full-width Unicode variants (`＝ ＋ － ＠`, U+FF1D/FF0B/FF0D/FF20), since
  some spreadsheet/IME environments normalize full-width punctuation to
  ASCII on paste/import. Detection and quoting behavior is otherwise
  identical to the ASCII case; no exported display text is altered beyond
  the existing leading-quote prefix.
- `auditExplorer.js`: "Top sections"/"Top users" facets were being replaced
  wholesale by each `search()` response's facets, which the server computes
  only over the rows scanned in that one call - so a "Search further back"
  call silently dropped earlier facets even as the displayed row count kept
  growing. Facets are now recomputed client-side from the full accumulated
  result set on every response.
- Corrected documentation claims that `SetupAuditTrailProvider` is "the only
  class that issues SOQL" (`docs/PRIVACY.md`, `docs/ARCHITECTURE.md`,
  `docs/SECURITY-REVIEW-SOLUTION-DOC.md`): `AuditQueryController.searchUsers`
  also issues SOQL, against the standard `User` object, for the "changed by"
  type-ahead. Disclosed its purpose, permission gate, and that results are
  never persisted/cached/logged.
- Corrected `docs/SECURITY-REVIEW-SOLUTION-DOC.md`'s permission-set summary
  to name both `ViewSetup` and its `ViewRoles` prerequisite (previously
  implied "nothing more" without naming `ViewRoles`), and to describe both
  production SOQL paths (`SetupAuditTrail` and the `User` type-ahead) rather
  than only the former.
- Corrected `docs/APPEXCHANGE-LISTING.md`: shortened the tagline and the
  short description (no Salesforce source for a numeric limit is cited; read
  the current limits from the Listing Builder's own field help); removed a
  false claim that row detail shows "context, issuer" (the UI renders only
  delegate user and namespace); reworded the access-control claim so it does
  not imply the runtime itself bypasses permissions - assigning the packaged
  permission set is what grants `ViewSetup` and its `ViewRoles` prerequisite.
- Corrected the same false "row detail" claim in `README.md`'s feature list.
- (Superseded by the managed release above.) Corrected beta/release wording
  throughout `README.md`, `SECURITY.md`, and
  `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md` at a time when the installed
  package was an unreleased unlocked beta: not production-installable, not
  managed, not AppExchange-reviewed/submitted, and not upgrade-equivalent to
  a future released version. `README.md` install guidance was then restricted
  to Developer Edition orgs, sandboxes, and trial/scratch orgs. The current
  packaging state is the one described in the preamble of this entry; "not
  AppExchange-reviewed/submitted" remains true.
- `SECURITY.md`'s vulnerability-reporting channel previously pointed to
  GitHub's private vulnerability reporting flow, which is **not enabled**
  for this repository. It now publishes a monitored email address
  (`muralirseelam+sf-audittrail-security@gmail.com`) as the reporting
  channel and no longer implies GitHub PVR is available.

## 1.0.0 (unlocked beta lineage, superseded)

Retained for history only. These unlocked beta builds belong to a different,
non-namespaced package (`0Hobm0000005681CAA`) that preceded the managed
lineage and cannot be converted into it; do not install them. This heading is
deliberately not linked: tag `v1.0.0` marks the managed release above.

- Progressive, time-sliced search over `SetupAuditTrail` (`AuditQueryService`),
  working around the object's lack of SOQL filtering on `Section`/`Display`
  and lack of aggregate function support.
- Lightning web component UI (`auditExplorer`) with date-range presets,
  section/user filters, free-text search, section/user facets, row detail,
  and CSV export.
- CSV export escaping (`csv.js`) that neutralizes spreadsheet formula
  injection (`=`, `+`, `-`, `@`, and control/zero-width leading characters)
  while preserving legitimate data.
- `AuditPermissionService` gate on the standard "View Setup and
  Configuration" permission, enforced on every `@AuraEnabled` entry point
  that exposes audit data.
- `Audit_Trail_Viewer` permission set granting the minimum access needed to
  use the app (the app itself, its tab, its Apex classes, and `ViewSetup`/
  `ViewRoles`).
- Apex tests, per version: 22/22 passed against unlocked `1.0.0.1`
  (`04tbm000000aeOjAAI`); 28/28 passed with 97% org-wide coverage against
  unlocked `1.0.0.2` (`04tbm000000gaALAAY`)
  (`docs/LIVE-ORG-VALIDATION.md:104-107`). The tests cover paging correctness
  against real data (Apex) and CSV formula-injection escaping (Jest).
- The Salesforce Code Analyzer scan formerly listed here ran on 2026-09-10
  against commit `934f200`, the managed-lineage source, not against these
  unlocked builds; it is recorded under the managed [1.0.0] entry above.

[Unreleased]: https://github.com/muraliseelam/sf-audittrail-app/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/muraliseelam/sf-audittrail-app/releases/tag/v1.0.1
[1.0.0]: https://github.com/muraliseelam/sf-audittrail-app/releases/tag/v1.0.0
