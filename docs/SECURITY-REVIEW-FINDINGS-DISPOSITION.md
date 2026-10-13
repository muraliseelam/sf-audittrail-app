# Audit Trail Explorer — Code Analyzer Findings Disposition

Companion to `CodeAnalyzerReport.html`. That report is a build artifact and is
deliberately not committed (see `.gitignore`); the dated result of each scan
is recorded in
[`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md) so the
disposition below can be checked against a real run. Prepared ahead of an
AppExchange security review submission. **This package has not yet been
submitted for, or passed, AppExchange Security Review** — see
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for its current
status: released managed 2GP version `1.0.1.4` (`04thm000002tWirAAE`, built
from commit `f0ad675`; "released" is the Salesforce packaging state only), no
review, no listing.

The counts below are from the run of 2026-10-12 on commit `f0ad675`, the
`force-app` source that built `1.0.1.4`. The previous edition of this document
described released version `1.0.0.2` (85 violations); where a count moved, the
reason is given with it.

Scan command (reproducible from a clean checkout, after `npm ci`):

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector Security \
  --rule-selector AppExchange \
  --output-file CodeAnalyzerReport.html
```

`npm ci` is part of the procedure, not a convenience: `code-analyzer.yml` points
the ESLint engine at `eslint.config.js`, which loads the project's
devDependencies. In a checkout without `node_modules` the ESLint engine fails to
instantiate (`UninstantiableEngineError`, "Cannot find module 'eslint/config'"),
the selector resolves to 59 rules from 4 engines, and the one Critical entry in
the report describes the machine, not the code. That was verified on a pristine
checkout of `47bd65f` on 2026-10-12.

All three tags are selected deliberately, as three separate flags — a
colon-separated selector is an _intersection_, and the old
`Recommended:AppExchange` matched no rule at all. `AppExchange` alone resolves
to 29 PMD rules and does **not** engage the Graph Engine, ESLint, RetireJS or
the secrets-regex engine. `Security` is what reaches `sfge:ApexFlsViolation`
and `sfge:DatabaseOperationsMustUseWithSharing`, which are tagged `DevPreview`
and so are selected by neither of the other two tags — yet they are the two
rules most relevant to this review.

**The selector resolves to 310 rules** (202 eslint, 94 pmd, 6 regex,
4 retire-js, 2 cpd, 2 sfge). Confirm that with `sf code-analyzer rules` and the
same flags before trusting a clean result.

## Result

Three-tag run of 2026-10-12 on `f0ad675`, Code Analyzer plugin 5.16.0,
11 minutes, exit 0 with `--severity-threshold 2`:

| Severity  | Count   |
| --------- | ------- |
| Critical  | **0**   |
| High      | **0**   |
| Moderate  | 13      |
| Low       | 106     |
| **Total** | **119** |

119 violations across 16 files, by rule:

| Rule                                            | Engine | Severity | Count |
| ----------------------------------------------- | ------ | -------- | ----- |
| `ApexUnitTestClassShouldHaveRunAs`              | pmd    | Low      | 45    |
| `ApexDoc`                                       | pmd    | Low      | 38    |
| `@salesforce-ux/slds/no-hardcoded-values-slds2` | eslint | Low      | 22    |
| `ExcessiveParameterList`                        | pmd    | Moderate | 4     |
| `CognitiveComplexity`                           | pmd    | Moderate | 3     |
| `CyclomaticComplexity`                          | pmd    | Moderate | 3     |
| `@lwc/lwc-platform/no-inline-disable`           | eslint | Moderate | 2     |
| `NcssCount`                                     | pmd    | Moderate | 1     |
| `AvoidDebugStatements`                          | pmd    | Low      | 1     |

Against the `1.0.0.2` baseline (85 = 11 Moderate + 74 Low) the movement is
+19 `ApexUnitTestClassShouldHaveRunAs` (50 Apex test methods, up from 29),
+9 `ApexDoc` (new methods), +4 SLDS advisories (new CSS),
+1 `CyclomaticComplexity` (the `AuditQueryServiceTest` class total) and
+1 `no-inline-disable` (in the Jest file). `CognitiveComplexity` is unchanged
at 3. Three rules that fired on intermediate 1.0.1 builds —
`FieldNamingConventions`, `AvoidDeeplyNestedIfStmts` and
`ApexUnitTestClassShouldHaveAsserts` — were addressed in the code before release
and do not appear in this run; see the note at the end of this document.

All six engines execute as part of the single command above. **RetireJS, the
regex secrets engine and CPD each report 0 violations, and so do the two Graph
Engine rules the selector reaches.** In this run the Graph Engine portion also
ran to completion inside the six-engine scan (`analyzed 6537 path(s) from 3
entry point(s)`), which the trimmed 1.0.1 search path made possible; that is
not relied upon, for the reason that follows.

The Graph Engine result is the one that needs its evidence stated, because a
bare "0 violations" from it can mean the analysis never finished. Verify it with
its own run on an otherwise idle machine:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector sfge
```

which must report **`6537 path(s)` from `3/3 entry point(s)`** and no
`Internal execution error` (757 s on 2026-10-12; `1.0.0.2` analysed in 14,503
paths and ~7 minutes). Anything less means the analysis was abandoned part-way
and the "0 violations" proves nothing — see the environment note below. The two
Security-tagged Graph Engine rules, `ApexFlsViolation` and
`DatabaseOperationsMustUseWithSharing`, report **0 violations**, i.e. the
CRUD/FLS and sharing enforcement described in section 5 of the solution
document is confirmed by path-sensitive analysis, not only by inspection. This
standalone run selects _every_ Graph Engine rule, not only the two in the
310-rule selection, and on the 1.0.1 source it reports **one** violation of the
Performance rule `AvoidDatabaseOperationInLoop`; that finding is outside the
three-tag result above and is dispositioned in its own section near the end.

**No violation of any severity carries the `Security`, `AppExchange` or
`ErrorProne` tag.** All 29 PMD AppExchange security rules are clean. Every
remaining item is a code-quality or style rule, dispositioned below.

The official AppExchange command, run from the package's top-level directory on
the same source
(`sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security --output-file CodeAnalyzerReport.html`,
62 rules from 5 engines), reports **`Found 0 violations.`** That
`CodeAnalyzerReport.html` is the file to upload with the `1.0.1.4` submission;
it is kept by the maintainer outside the repository, 64,954 bytes, SHA-256
`03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`.

## Environment note

PMD, the Graph Engine and CPD require a local JDK, the Flow engine requires
Python 3.10 or later, and the ESLint engine requires the project's
`node_modules` (above). If one is missing the engine **fails to load**:
depending on the plugin version it is either skipped silently, so the scan
reports a false all-clear, or, as 5.16.0 does, reported as a Critical
`UninstantiableEngineError` with no file, which is not a code finding (seen for
the flow engine without Python on 2026-10-11 and for the ESLint engine without
`node_modules` on 2026-10-12). Every recorded run had OpenJDK 21, so PMD, CPD
and the Graph Engine genuinely executed. The flow engine is not eligible for
the `force-app` workspace (no Flow metadata). The 2026-10-12 runs used Code
Analyzer plugin 5.16.0 on `@salesforce/cli` 2.153.5 (win32-x64), Node 24.20.0,
OpenJDK 21.0.12.1 (Microsoft build) and Python 3.12.10, from the release
worktree after `npm ci`. Check the engine and rule counts rather than the
violation total; each run's environment is in
[`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

Two further ways this scan can report a false all-clear, both guarded against
in `code-analyzer.yml`:

- **Selector syntax.** A colon-separated rule selector is an _intersection_. No
  rule carries both the `Recommended` and `AppExchange` tags, so
  `Recommended:AppExchange` selects **0 rules** and reports `0 violations`
  while proving nothing. The tags must be passed as separate `--rule-selector`
  flags, which unions them — three flags here (`Recommended`, `Security`,
  `AppExchange`), 310 rules, the same count `code-analyzer.yml` and the CI gate
  check. Always confirm the count with `sf code-analyzer rules` before trusting
  a clean result.
- **Graph Engine path timeouts.** The path count is a property of the code:
  every conditional between `AuditQueryController.search` and the SOQL
  multiplies it. On `1.0.0.2` the entry point had a 14,503-path space, far
  beyond the stock 30 s per-path budget, and `code-analyzer.yml` raised
  `java_thread_timeout` to 600 s. On timeout the engine still prints
  `0 violations`, with the abandoned entry point reported only as an
  `Internal execution error` in the surrounding output. The first 1.0.1 builds
  showed how quickly that budget is lost: range pinning and cursor validation
  added conditionals on the search path, and on the sources of `1.0.1.2` and
  `1.0.1.3` the standalone run timed out even at a diagnostic 1,800,000 ms,
  printing `3 path(s) from 2 entry point(s)` and the vacuous all-clear.
  `AuditQueryService.search` was rewritten in `f0ad675` with the minimum of
  branches (`Math.min`/`Math.max` clamps, unconditional set inserts with nulls
  removed once, one ternary for the cursor — `AuditQueryService.cls:57-73`),
  which brought the count to 6,537; `code-analyzer.yml` now sets
  `java_thread_timeout` to 1,800,000 ms and
  `.github/workflows/code-analyzer.yml` pins `6537 path(s)`. If `search()` or
  anything it calls gains a conditional, re-measure before trusting a result.
- **Graph Engine memory.** `java_max_heap_size` is set to `2g` deliberately, not
  higher. Requesting more heap than the host can spare makes the JVM thrash and
  the analysis times out regardless: on an 8 GB machine a 4g request yielded
  `3 path(s) from 2 entry point(s)` plus an error, while 2g with 4 threads
  completed all 14,503 paths of `1.0.0.2`, and the same setting completed the
  6,537 paths of `1.0.1` in 757 s. Running the Graph Engine concurrently with
  the other five engines can lose the same memory race, so verify it with its
  own run. Treat any Graph Engine result that does not name the path and
  entry-point counts as unproven.

---

## Moderate findings

### `CognitiveComplexity` (2 of 3), `CyclomaticComplexity` (1 of 3), `NcssCount` (1) — `AuditQueryService`

**Accepted, not a defect.**

Locations: the class total (`AuditQueryService.cls:24`) and `search()`
(`AuditQueryService.cls:53`) for `CognitiveComplexity`; `search()` for
`CyclomaticComplexity` and `NcssCount`.

The complexity is inherent to the problem. `SetupAuditTrail` cannot be filtered
on `Section` or `Display` in SOQL, and supports no aggregate functions at all.
The service therefore has to scan backwards through time in bounded windows,
post-filter in Apex, and maintain an exact cursor across window boundaries —
all while staying inside governor limits regardless of org size.

1.0.1 moved more of the contract into `search()`: the date range is resolved on
the first call and pinned in the cursor (`pinRange`), paging is keyset-based on
(`CreatedDate`, `Id`) with the continuation id validated before any query runs,
and the client-supplied bounds are re-clamped rather than trusted. At the same
time the method lost branches for the Graph Engine (see the environment note),
which is why these counts did not move with the added behaviour.

Decomposing the scan loop further would spread a single stateful algorithm
across several methods that could not be understood or tested independently,
which we judge to be worse for a reviewer than one cohesive, heavily commented
method.

The behaviour is pinned by tests.
`multiBatchScanFindsAMatchInTheLastShortBatch`,
`sameTimestampRowsPageByIdAcrossBatches` and
`ceilingStopsACallWithoutLosingProgress` (`AuditQueryServiceTest.cls:425-527`)
shrink the scan to `scanBatch = 100` and `maxBatchesPerCall = 3` through the
two `@TestVisible` fields (`useSmallBatches()`,
`AuditQueryServiceTest.cls:49-52`; `AuditQueryService.cls:34-37`), so a few
hundred mock rows cross real batch boundaries: a match that exists only in a
short third batch is found and the range reported done after exactly three
fetches; 250 rows sharing one timestamp are paged by id across both batch and
page boundaries, every row returned exactly once; and a call stopped by the
ceiling at 300 scanned rows leaves the cursor on the last scanned row, with the
next call finishing the remaining 50 in a single short batch.
`pagingCoversEveryRowExactlyOnce` and `handlesManyRowsSharingOneTimestamp` hold
the same no-duplicate, no-skip invariant within one batch, and
`searchRoundTripsCursorJson` (`AuditQueryControllerTest.cls:67-100`) that the
keyset id and the pinned range survive the JSON round trip through the browser.
All 50 Apex tests passed on the released source (source deploy
`0Afh1000000NfiTCAS`, 50 run, 0 failed) and against the installed `1.0.1.4` in
a subscriber org (run `707di0000LCKGo0`, 50 passed, 0 failed).

### `ExcessiveParameterList` (4) — `AuditTrailProvider`, `SetupAuditTrailProvider`, `MockAuditTrailProvider`

**Accepted, not a defect.**

Locations: `fetch` on the interface (`AuditTrailProvider.cls:25`), on the
production provider (`SetupAuditTrailProvider.cls:9`) and on the mock
(`MockAuditTrailProvider.cls:19`), six parameters each, and the mock's `row`
test-data builder (`MockAuditTrailProvider.cls:69`), five.

This is the seam that makes the code testable. `SetupAuditTrail` records cannot
be inserted in an Apex test, so the query is placed behind an interface with an
injectable mock. The parameters are the query's filter criteria, passed
explicitly so that each one is visibly bound rather than assembled into a
string. 1.0.1 replaced the seen-id set parameter with the keyset `lastId`; the
parameter count did not change.

Replacing them with a criteria object would hide the binding at the exact point
a reviewer most wants to see it. We consider explicit parameters the safer
shape here.

### `CognitiveComplexity`, `CyclomaticComplexity` — `MockAuditTrailProvider`, `AuditQueryServiceTest`

**Accepted.** Test-support code only; none of it is part of the runtime path.
`MockAuditTrailProvider.fetch` (`MockAuditTrailProvider.cls:19`) is reported
under both rules: it now mirrors the real provider's keyset contract, which is
what lets the tests above exercise paging without inserting `SetupAuditTrail`
rows. The class total of `AuditQueryServiceTest` (`AuditQueryServiceTest.cls:2`,
`CyclomaticComplexity`) is the one Moderate location new since `1.0.0.2`: 28
test methods in one class, each of them small.

### `@lwc/lwc-platform/no-inline-disable` (2) — `auditExplorer.js`, `auditExplorer.test.js`

**Accepted, justified suppression.**

Two `// eslint-disable-next-line no-await-in-loop` comments exist. The first is
in the progressive-search loop (`auditExplorer.js:289`): the awaits are
sequential by necessity, because each server call needs the paging cursor
returned by the previous one, so they cannot be parallelised. The second, new
in 1.0.1, is in the Jest suite's `settle()` helper
(`__tests__/auditExplorer.test.js:81`), which drains that same chain of
sequential calls one flush at a time so the tests can observe each step. Each
suppression is narrowly scoped to a single line and carries an inline
justification comment.

The alternative — disabling `no-await-in-loop` for the whole file in
`eslint.config.js` — would silence the rule far more broadly and leave no
visible marker at the call site.

---

## Low findings

### `ApexDoc` (38)

**Accepted.** Every class and non-trivial method carries an explanatory
comment; the rule requires the specific ApexDoc
`@description`/`@param`/`@return` tag syntax, which this project does not use.
The nine additional hits since `1.0.0.2` are on methods 1.0.1 added. No
functional or security impact.

### `ApexUnitTestClassShouldHaveRunAs` (45)

**Accepted, and deliberately not blanket-applied.**

The four test classes hold 50 `@IsTest` methods (29 in `1.0.0.2`). The rule
flags the 45 that run as the test user; the other 5 use `System.runAs`, and
they are exactly the five that test the access gate, all in
`AuditPermissionServiceTest.cls`:

- `deniesUserWithoutViewSetup` (`AuditPermissionServiceTest.cls:46-69`): a user
  on the stock **Minimum Access - Salesforce** profile, which lacks **View
  Setup and Configuration**, gets `false` from `canViewSetup()` and the
  permission exception from `assertCanViewSetup()`.
- `blocksControllerEntryPointsForUnprivilegedUser` (`:71-104`): the same user
  is refused by `search` and `searchUsers`, the two `@AuraEnabled` methods that
  return data, and since 1.0.1 the test asserts that each refusal is an
  `AuraHandledException` whose message names **View Setup and Configuration**
  — proof that the controller calls `setMessage()`, without which the client
  would see only "Script-thrown exception".
- `restrictedUserGetContextReportsNoAccessWithoutThrowing` (`:106-121`, new):
  the controller's third `@AuraEnabled` method, `getContext`, is ungated by
  design and returns no audit data (`AuditQueryController.cls:39-56`); for the
  same user it must answer `canViewSetup = false` rather than throw, because
  the UI uses that answer to choose between the search form and the "ask your
  administrator" message.
- `restrictedUserWithLocalViewSetupPermissionSetCanUseEveryEntryPoint`
  (`:130-195`, new): the deterministic positive case. The same user, granted
  **View Setup and Configuration** through a permission set created in the test
  org — which is what a managed-package subscriber's administrator has to do —
  can use `search`, `getContext` and `searchUsers`. A local permission set is
  never stripped by packaging, so this holds in source, unlocked and managed
  contexts alike.
- `packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup` (`:197-240`): the
  same user, assigned only the shipped `Audit_Trail_Viewer` permission set,
  passes the gate exactly when that permission set genuinely carries
  `ViewSetup`. Under managed packaging it does not — Salesforce strips the
  system permission on install — so in a subscriber org the test pins the gate
  shut until the administrator grants the permission separately
  (`CHANGELOG.md`, "Managed-package installs require ...").

Of the remaining 45 methods, 31 do not depend on who runs them: the 28 in
`AuditQueryServiceTest` (paging, cursor, range pinning, filter and facet logic
against the mock provider), the two `AuditEventRow` mapping tests in
`SetupAuditTrailProviderTest`, and the Apex-class-access check in
`AuditPermissionServiceTest`. The other 14 pass only when the running user
holds `ViewSetup`, because they call a gated entry point, assert the running
user's access, or run the real `SetupAuditTrail` query in user mode:
`allowsUserWithViewSetup`; all 11 methods of `AuditQueryControllerTest` (the
five `search` tests, two of which assert the generic error message;
`contextExposesRetentionWindow`, which since 1.0.1 asserts
`canViewSetup = true` rather than merely that a value is present; and the five
`searchUsers` tests, which pass the permission gate before the term-length
check); and the two real-SOQL tests in `SetupAuditTrailProviderTest`. A 50/50
pass — source deploy `0Afh1000000NfiTCAS` of the released source and run
`707di0000LCKGo0` against the installed `1.0.1.4`
([`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md)) — therefore implies
the runner held `ViewSetup`; a runner without it would fail these 14. Wrapping
the 45 in `runAs` to satisfy the rule would add ceremony without adding
assurance. CSV escaping is covered by the Jest suite
(`force-app/main/default/lwc/auditExplorer/__tests__/auditExplorer.test.js:311-347`
and the `CSV export` block at `:689-762`), not by Apex.

### `@salesforce-ux/slds/no-hardcoded-values-slds2` (22)

**Accepted.** SLDS 2 design-token advisories in the component stylesheet
(`auditExplorer.css`); the four added since `1.0.0.2` come from the 14 lines
1.0.1 added for the "Filters changed" hint and the spinner placeholders.
Cosmetic only; no security or functional impact.

### `AvoidDebugStatements` (1)

**Accepted, intentional.**

The single `System.debug(LoggingLevel.ERROR, ...)`
(`AuditQueryController.cls:110`) sits in `genericFailure`, the server-side half
of the generic error handling: an unexpected exception is written to the Apex
debug log and replaced with a non-specific message to the client, so platform
exception text cannot leak query internals to the browser. In `1.0.0.2` only
`search` went through that handler; since 1.0.1 every entry point does.
`search`, `getContext` and `searchUsers` each wrap their whole body in the same
two catch blocks (`AuditQueryController.cls:21-95`): the permission exception
is the one whose text passes through, via `permissionFailure` (`:101-107`),
because it is written for the user and names the permission they lack, and
every other exception becomes `GENERIC_ERROR`. Both halves are tested:
`searchHidesInternalErrorDetail` and `searchHidesDeserializationFailureDetail`
(`AuditQueryControllerTest.cls:102-153`) assert the generic text and the
absence of "Malformed", "SELECT", "SetupAuditTrail", "JSON" and field names in
what the client receives, and `blocksControllerEntryPointsForUnprivilegedUser`
asserts that the permission message does reach the client from `search` and
`searchUsers`. Because this is managed-package code, a subscriber administrator
sees that log line only subject to the org's trace flags and the debug settings
that apply to the package's code; it is a diagnostic trail, not a notification.
The line echoes the exception type and message only — never a row of audit
data, and no credential, no session data, and no personal data.

Removing it would satisfy the linter by discarding the diagnostic trail, which
is the wrong trade.

---

## Outside the three-tag selection: the standalone Graph Engine run

### `sfge:AvoidDatabaseOperationInLoop` (1)

**Accepted, by design and bounded.**

The `--rule-selector sfge` verification run selects every Graph Engine rule,
not only the two Security-tagged rules in the 310-rule selection, so it is the
one scan in which a `Performance` rule can appear. On `f0ad675` it reports,
alongside the 6,537-path completion and 0 violations from `ApexFlsViolation`
and `DatabaseOperationsMustUseWithSharing`, one violation of
`AvoidDatabaseOperationInLoop`: "A database operation occurred inside a loop
[WhileLoopStatement at AuditQueryService:116]", with the entry point at
`AuditQueryController.cls:22` and the `Database.query` at
`SetupAuditTrailProvider.cls:42`. The report scores it High; its tags are
`DevPreview`, `Performance` and `Apex`, not `Security` or `AppExchange`. The
`1.0.0.2` standalone runs recorded 0 violations from 14,503 paths, so it first
fires on the 1.0.1 source.

The loop it names is the progressive, time-sliced scan the application exists
for (`AuditQueryService.cls:116-167`): `SetupAuditTrail` cannot be filtered on
`Section` or `Display` in SOQL, so the service fetches bounded batches and
post-filters them, and the batch loop is where each fetch happens. It is
bounded in every direction: at most `maxBatchesPerCall` (10) queries per
transaction against the limit of 100 SOQL queries, each client call is its own
transaction, the loop also exits on a full page or a short batch, and the
ceiling is pinned by `ceilingStopsACallWithoutLosingProgress`
(`AuditQueryServiceTest.cls:484-527`). Removing the query from the loop would
mean either fetching the whole window in one query — the heap and row-limit
failure in large orgs that the design exists to avoid — or giving up
server-side filtering on the two fields users most want to search. Accepted.

## Rules that fired on intermediate 1.0.1 builds

For the record, the superseded `1.0.1.1` source (`47bd65f`) also reported
`FieldNamingConventions` (2: the scan-tuning statics, once they stopped being
`final` so tests could shrink them), `AvoidDeeplyNestedIfStmts` (1: nested
conditions in `CompiledFilter.matches`) and `ApexUnitTestClassShouldHaveAsserts`
(2: assertions that lived in a shared helper). All were addressed in the code
before release — the statics renamed `scanBatch` / `maxBatchesPerCall` and
documented as deliberately non-final (`AuditQueryService.cls:28-37`), the
nested `if` folded into one condition (`AuditQueryService.cls:275`), direct
assertions added to the two tests — and none appears on the released source.
