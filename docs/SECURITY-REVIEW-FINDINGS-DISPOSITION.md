# Audit Trail Explorer — Code Analyzer Findings Disposition

Companion to `CodeAnalyzerReport.html`. That report is a build artifact and is
deliberately not committed (see `.gitignore`); the dated result of each scan
is recorded in
[`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md) so the
disposition below can be checked against a real run. Prepared ahead of an
AppExchange security review submission. **This package has not yet been
submitted for, or passed, AppExchange Security Review** — see
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for its current
status: released managed 2GP version `1.0.0.2`, no review, no listing.

Scan command (reproducible from a clean checkout):

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector Security \
  --rule-selector AppExchange \
  --output-file CodeAnalyzerReport.html
```

All three tags are selected deliberately, as three separate flags — a colon-separated
selector is an _intersection_, and the old `Recommended:AppExchange` matched no rule at all.
`AppExchange` alone resolves to 29 PMD rules and does **not** engage the Graph Engine,
ESLint, RetireJS or the secrets-regex engine. `Security` is what reaches
`sfge:ApexFlsViolation` and `sfge:DatabaseOperationsMustUseWithSharing`, which are tagged
`DevPreview` and so are selected by neither of the other two tags — yet they are the two
rules most relevant to this review.

**The selector resolves to 310 rules** (202 eslint, 94 pmd, 6 regex, 4 retire-js, 2 cpd,
2 sfge). Confirm that with `sf code-analyzer rules` and the same flags before trusting a
clean result.

## Result

| Severity  | Count  |
| --------- | ------ |
| Critical  | **0**  |
| High      | **0**  |
| Moderate  | 11     |
| Low       | 74     |
| **Total** | **85** |

All six engines execute as part of the single command above. **RetireJS, the regex secrets
engine and the Salesforce Graph Engine each report 0 violations.**

The Graph Engine result is the one that needs its evidence stated, because a bare
"0 violations" from it can mean the analysis never finished. Verify it with its own run on
an otherwise idle machine:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector sfge
```

which must report **`14503 path(s) from 3/3 entry point(s)`** and no `Internal execution
error` (~7 minutes). Anything less means the analysis was abandoned part-way and the
"0 violations" proves nothing — see the environment note below. The two Graph Engine rules reached are `ApexFlsViolation` and
`DatabaseOperationsMustUseWithSharing`, i.e. the CRUD/FLS and sharing enforcement described
in section 5 of the solution document is confirmed by path-sensitive analysis, not only by
inspection.

**No violation of any severity carries the `Security`, `AppExchange` or `ErrorProne` tag.**
All 29 PMD AppExchange security rules are clean. Every remaining item is a code-quality or
style rule, dispositioned below.

## Environment note

PMD, the Graph Engine and CPD require a local JDK, and the Flow engine requires Python. If
either is missing, those engines **fail to load and are silently skipped**, and the scan
reports a false all-clear. This scan was run with OpenJDK 21 and Python 3.12 present, so
all engines were genuinely executed.

Two further ways this scan can report a false all-clear, both guarded against in
`code-analyzer.yml`:

- **Selector syntax.** A colon-separated rule selector is an _intersection_. No rule
  carries both the `Recommended` and `AppExchange` tags, so `Recommended:AppExchange`
  selects **0 rules** and reports `0 violations` while proving nothing. The two tags must
  be passed as two separate `--rule-selector` flags, which unions them (295 rules here).
  Always confirm the count with `sf code-analyzer rules` before trusting a clean result.
- **Graph Engine path timeouts.** `AuditQueryController.search` has a 14,503-path space,
  far beyond the stock 30s per-path budget. On timeout the engine still prints
  `0 violations`, with the abandoned entry point reported only as an `Internal execution
error` in the surrounding output. `code-analyzer.yml` raises `java_thread_timeout` to
  600s so the analysis can finish.
- **Graph Engine memory.** `java_max_heap_size` is set to `2g` deliberately, not higher.
  Requesting more heap than the host can spare makes the JVM thrash and the analysis times
  out regardless: on an 8 GB machine a 4g request yielded `3 path(s) from 2 entry
point(s)` plus an error, while 2g with 4 threads completed all 14,503 paths. Running the
  Graph Engine concurrently with the other five engines can lose the same memory race, so
  verify it with its own run. Treat any Graph Engine result that does not name the
  path and entry-point counts as unproven.

---

## Moderate findings

### `CognitiveComplexity`, `CyclomaticComplexity`, `NcssCount` — `AuditQueryService`

**Accepted, not a defect.**

The complexity is inherent to the problem. `SetupAuditTrail` cannot be filtered on
`Section` or `Display` in SOQL, and supports no aggregate functions at all. The service
therefore has to scan backwards through time in bounded windows, post-filter in Apex, and
maintain an exact cursor across window boundaries — all while staying inside governor
limits regardless of org size.

Decomposing the scan loop further would spread a single stateful algorithm across several
methods that could not be understood or tested independently, which we judge to be worse
for a reviewer than one cohesive, heavily commented method. The behaviour is pinned by
tests, including a real-data paging check over 122 records and 18 pages that confirmed
zero duplicates and zero skipped rows.

### `ExcessiveParameterList` — `AuditTrailProvider`, `SetupAuditTrailProvider`, `MockAuditTrailProvider`

**Accepted, not a defect.**

This is the seam that makes the code testable. `SetupAuditTrail` records cannot be
inserted in an Apex test, so the query is placed behind an interface with an injectable
mock. The parameters are the query's filter criteria, passed explicitly so that each one
is visibly bound rather than assembled into a string.

Replacing them with a criteria object would hide the binding at the exact point a reviewer
most wants to see it. We consider explicit parameters the safer shape here.

### `CognitiveComplexity`, `CyclomaticComplexity` — `MockAuditTrailProvider`

**Accepted.** Test-support code only; it is not part of the runtime path.

### `@lwc/lwc-platform/no-inline-disable` — `auditExplorer.js`

**Accepted, justified suppression.**

One `// eslint-disable-next-line no-await-in-loop` exists in the progressive-search loop.
The awaits are sequential by necessity: each server call needs the paging cursor returned
by the previous one, so they cannot be parallelised. The suppression is narrowly scoped to
a single line and carries an inline justification comment.

The alternative — disabling `no-await-in-loop` for the whole file in `eslint.config.js` —
would silence the rule far more broadly and leave no visible marker at the call site.

---

## Low findings

### `ApexDoc` (29)

**Accepted.** Every class and non-trivial method carries an explanatory comment; the rule
requires the specific ApexDoc `@description`/`@param`/`@return` tag syntax, which this
project does not use. No functional or security impact.

### `ApexUnitTestClassShouldHaveRunAs` (26)

**Accepted, and deliberately not blanket-applied.**

`System.runAs` is used precisely where it is meaningful — `AuditPermissionServiceTest`
runs as real users on real profiles to prove that a user without **View Setup and
Configuration** is denied by both `@AuraEnabled` entry points, and that the shipped
permission set alone is sufficient to grant access.

The remaining tests exercise pure logic (cursor arithmetic, filter compilation, CSV
escaping) where the running user is irrelevant. Wrapping them in `runAs` to satisfy the
rule would add ceremony without adding assurance.

### `@salesforce-ux/slds/no-hardcoded-values-slds2` (18)

**Accepted.** SLDS 2 design-token advisories in the component stylesheet. Cosmetic only;
no security or functional impact.

### `AvoidDebugStatements` (1)

**Accepted, intentional.**

The single `System.debug(LoggingLevel.ERROR, ...)` is the server-side half of the generic
error handling: unexpected exceptions are logged for the administrator and replaced with a
non-specific message to the client, so platform exception text cannot leak query internals
to the browser. It logs the exception type and message only — no credential, no session
data, and no personal data.

Removing it would satisfy the linter by discarding the diagnostic trail, which is the
wrong trade.
