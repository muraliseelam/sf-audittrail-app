# Audit Trail Explorer — Code Analyzer Findings Disposition

Companion to `CodeAnalyzerReport.html`, prepared ahead of an eventual
AppExchange security review submission. **This package has not yet been
submitted for, or passed, AppExchange Security Review** — see
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for its current
unreleased-beta, unlocked-package status.

Scan command (reproducible from a clean checkout):

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector AppExchange \
  --output-file CodeAnalyzerReport.html
```

`Recommended` and `AppExchange` are both selected deliberately. The `AppExchange` selector
alone resolves to 29 PMD rules and does **not** engage the Salesforce Graph Engine, ESLint,
RetireJS or the secrets-regex engine. Scanning with it alone would have produced a
misleadingly clean report.

## Result

| Severity  | Count  |
| --------- | ------ |
| Critical  | **0**  |
| High      | **0**  |
| Moderate  | 11     |
| Low       | 74     |
| **Total** | **85** |

RetireJS and the regex secrets engine execute as part of the command above and report
**0 violations**.

The Salesforce Graph Engine has no rule tagged `Recommended` or `AppExchange`, so it is
**not** engaged by that command and must be run separately:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector sfge
```

This reports **0 violations**, having analysed **14,503 paths across all 3 of 3 entry
points**. The path and entry-point counts are the evidence that matters — see the
environment note below for why a bare `0 violations` from this engine is not sufficient on
its own.

No finding of any severity relates to security. Every remaining item is a code-quality or
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
- **Graph Engine path timeouts.** At the stock 30s per-path budget, path evaluation of
  `AuditQueryController.search` times out. The engine then still prints `0 violations`,
  with the abandoned entry point reported only as an `Internal execution error` in the
  surrounding output. `code-analyzer.yml` raises `java_thread_timeout` and
  `java_max_heap_size` so the analysis actually finishes; the run takes ~7 minutes.
  Treat any Graph Engine result that does not name the entry-point count as unproven.

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
