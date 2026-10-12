# Audit Trail Explorer — Solution Documentation

Prepared ahead of an AppExchange/AgentExchange security review submission.
**This package has not yet been submitted for, or passed, that review** — see
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for its current
status: released managed 2GP version `1.0.0.2`, no review, no listing.

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

| Question                                         | Answer                                                                                                                                                                                                                             |
| ------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Does the solution store data outside Salesforce? | **No.**                                                                                                                                                                                                                            |
| Does the solution make external callouts?        | **No.** There is no `HttpRequest`, no named credential, and no remote site setting in the package.                                                                                                                                 |
| Does the solution create or modify any record?   | **No.** The runtime code performs no DML. The packaged test classes insert `User` and `PermissionSetAssignment` records (`AuditPermissionServiceTest.cls:30,108`), but only inside Apex tests, where the platform rolls them back. |
| Does the solution include a custom object?       | **No.**                                                                                                                                                                                                                            |
| Where is data persisted?                         | Nowhere. Every request reads `SetupAuditTrail` (and, for the user type-ahead described below, `User`) live and returns the rows to the browser. Nothing is cached server-side.                                                     |
| Is any data sent to a third party?               | **No.**                                                                                                                                                                                                                            |

Because nothing is stored, there is no data-retention, data-residency or data-deletion
surface. Uninstalling the package removes the code and leaves no residue.

## 4. Authentication and authorisation

The app has a single authorisation gate: the standard **View Setup and Configuration**
(`ViewSetup`) user permission, which is the same permission Salesforce itself requires to
view the Setup Audit Trail. The app grants no access that the user did not already have.

`AuditPermissionService.assertCanViewSetup()` enforces this by checking
`Schema.SObjectType.SetupAuditTrail.isAccessible()`. The equivalence between that
describe call and the ViewSetup permission was verified empirically in a scratch org
rather than assumed (`AuditPermissionService.cls:8-10`). `AuditPermissionServiceTest`
pins the negative case under `System.runAs` as a freshly inserted user on the stock
**Minimum Access - Salesforce** profile (`deniesUserWithoutViewSetup`,
`blocksControllerEntryPointsForUnprivilegedUser`). The positive case is exercised by
the running test user, who holds ViewSetup (`allowsUserWithViewSetup`, no `runAs`),
and, where the packaging model allows it, by a Minimum Access user assigned the shipped
permission set: `packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup` asserts under
`runAs` that the gate opens exactly when that permission set genuinely carries
ViewSetup, which it does on a source deploy and does not under a managed install (see
below).

The controller exposes three `@AuraEnabled` methods. The two that return data, `search`
and `searchUsers`, call this gate before doing any other work; `getContext` is
deliberately not gated because it returns no audit data:

| Method        | Gated                | Notes                                                                                                                                                                                                                                    |
| ------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `search`      | Yes                  |                                                                                                                                                                                                                                          |
| `searchUsers` | Yes                  | Type-ahead over the User object for the "changed by" filter                                                                                                                                                                              |
| `getContext`  | Not gated, by design | Returns only compile-time constants, `Datetime.now()`, and the calling user's own access boolean. It discloses nothing the caller does not already know about themselves, and the UI needs it to render the "you lack permission" state. |

The shipped permission set `Audit_Trail_Viewer` declares `ViewSetup` and its
`ViewRoles` prerequisite (Salesforce requires `ViewRoles` to enable
`ViewSetup`), plus the app, the tab, and Apex class access - no object
CRUD/FLS grant and no other system permission.

**Under managed packaging, the app grants no system permission at all.**
Salesforce strips system permissions from a managed package's permission sets
on install, so in a subscriber org `Audit_Trail_Viewer` carries
`PermissionsViewSetup = false` and grants only the app, its tab, and its Apex
classes. Subscriber administrators must grant "View Setup and Configuration"
themselves. This is verified empirically in
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) and means the managed
package cannot escalate any subscriber's privileges: every user who can see
audit data through this app could already see it natively in Setup.

## 5. CRUD/FLS and sharing enforcement

- Both production SOQL paths enforce CRUD/FLS at the platform level rather
  than via hand-written describe checks: the `SetupAuditTrail` query runs as
  `Database.query(soql, AccessLevel.USER_MODE)`, and the `User` type-ahead
  query (`AuditQueryController.searchUsers`) runs `WITH USER_MODE`.
- Every production Apex class is declared `with sharing`, as are the two inner
  classes that hold logic (`AuditQueryService.CompiledFilter` and
  `AuditSearchResult.AuditFacet`). `AuditTrailProvider` is an interface and
  cannot carry a sharing keyword; `AuditPermissionService.AuditPermissionException`
  is an empty inner exception type. The four `@IsTest` test classes carry no
  sharing keyword and run only in test context; the `@IsTest` mock provider is
  `with sharing`.
- `SetupAuditTrail` is a read-only platform-owned object, so there is no DML to enforce.

## 6. Injection defences

**SOQL.** `SetupAuditTrailProvider` is the only class that builds the
`SetupAuditTrail` query string; `AuditQueryController.searchUsers` is the
only other class that issues SOQL, against `User` (see section 3 and the
LIKE-wildcards note below). In both queries, every literal fragment is a
compile-time string literal - there is no path by which user input reaches
the query text. All user-supplied values (`CreatedById`, `Action`, date
bounds, excluded ids, row limit, the type-ahead search term) are passed as
bind variables. The row limit on the `SetupAuditTrail` query is bound from
the private constant `SCAN_BATCH`, not from the client.

**LIKE wildcards.** For the user type-ahead, the search term is bound (never
concatenated), and LIKE metacharacters are neutralised in the correct order: backslash
first, then `%`, then `_`. `String.escapeSingleQuotes` is deliberately **not** used on
bind values, because it corrupts legitimate names such as `O'Brien` without adding safety.

**Untrusted cursor.** The paging cursor round-trips through the browser and is therefore
treated as untrusted input. Malformed ids are discarded rather than cast, and the set of
"already seen" ids is capped so a crafted cursor cannot push an unbounded bind into the
query.

**XSS.** The LWC renders exclusively through `{}` template interpolation, which is
context-escaped by the framework. The package contains no `innerHTML`, no
`lwc:dom="manual"`, no `eval`, no `document.write`, and no Visualforce or Aura.

**CSV formula injection.** Audit descriptions echo admin-controlled text (renamed field
labels, for example), so an exported cell could otherwise carry a payload that executes
when the file is opened in Excel or Google Sheets. `csv.js` prefixes any cell beginning
with `=`, `+`, `-`, `@`, whitespace, a C0 control character or a zero-width space with a
single quote. The logic is isolated in its own module specifically so it can be unit
tested, and it is.

## 7. Error handling

Only the permission error is passed to the client verbatim, because it is the actionable,
user-facing case. Every other exception is converted to a generic message, with the detail
written to the debug log via `System.debug(LoggingLevel.ERROR, ...)`, so platform
exception text cannot leak query or limit internals to the browser. No secret, credential
or personal data is logged.

## 8. Testing

- 29 Apex tests; coverage **97%** at package build time
  (`HasPassedCodeCoverageCheck = true`), with no class below 95% (the
  managed-package requirement is 75%). Re-verified 2026-09-10: the **released
  managed version** passes 29/29 as namespaced `atexplorer.*` classes in a
  clean subscriber org, and the same source passes 29/29 at 97% org-wide
  coverage on a direct source deploy. Run ids are recorded in
  [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).
- `SetupAuditTrail` cannot be inserted in a test, so the service takes an injectable
  provider interface. `SetupAuditTrailProviderTest` nonetheless executes the real
  production query, so the SOQL is genuinely exercised rather than mocked away.
- 7 Jest tests covering the component, including the CSV escaping. Measured
  2026-09-12: **72.16% statements** overall, with `csv.js` — the
  formula-injection control — at **100%** and `auditExplorer.js` at 70.64%.
- Paging correctness was validated against real data in the installed managed
  package (`00DRK00000aOfV72AK`, 2026-09-13): 65 audit rows sharing one
  timestamp were seeded so that the 50-row page boundary fell inside the block,
  and paging to completion (50, 100, 118) exported **118 data rows against 118
  rows in the org with 0 duplicate rows**. The record is in
  [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).

## 9. Third-party code

**None.** The package contains no third-party JavaScript library, no static resource, and
no npm dependency shipped to the runtime. RetireJS reports zero findings.

## 10. Static analysis

Salesforce Code Analyzer v5 (`@salesforce/plugin-code-analyzer`), run from a checkout of
this repository as:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector Security \
  --rule-selector AppExchange
```

This scan has been run three times, with an identical rule set and identical results
each time. Every run is recorded in
[`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md); the report
Salesforce asks for, generated with its own command, is recorded under "Official
AppExchange command" at the end of this section.

| Date       | Plugin   | Host                                                           | Source                                                   |
| ---------- | -------- | -------------------------------------------------------------- | -------------------------------------------------------- |
| 2026-09-10 | `5.15.0` | Windows workstation, CLI 2.98.6, OpenJDK 21                    | commit `934f200` (tag `v1.0.0`, the source of `1.0.0.2`) |
| 2026-09-19 | `5.16.0` | GitHub Actions `ubuntu-latest`, CLI 2.150.6, run `35450675758` | commit `5c70c8c`; `force-app` identical to `934f200`     |
| 2026-10-11 | `5.16.0` | Windows workstation, CLI 2.153.5, OpenJDK 21.0.12.1            | HEAD `f27a009`; `force-app` identical to `934f200`       |

The 5.15.0 and 5.16.0 rule lists match rule for rule, not merely in total, and the 85
findings in the result table below reproduce count for count on all three dates. The
2026-10-11 run additionally printed one Critical `UninstantiableEngineError` from the
`flow` engine ("Could not locate a Python v3.10.0+ install"), because Python was not yet
installed on that workstation. That is an engine-instantiation error with no file, not a
code finding: the flow engine is not eligible for the `force-app` workspace anyway (no
Flow metadata), the six engines counted below all ran, and the Graph Engine completed its
full path space both inside that run and in the separate `--rule-selector sfge` run that
followed it.

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

| Severity | Count |
| -------- | ----- |
| Critical | **0** |
| High     | **0** |
| Moderate | 11    |
| Low      | 74    |

**No violation of any severity carries the `Security`, `AppExchange` or `ErrorProne` tag.**
Specifically clean: all 29 PMD AppExchange security rules, both Graph Engine security
rules, the regex secrets engine, and RetireJS.

### Items not fixed, and why

Every remaining violation is a code-quality or style rule. None is suppressed by
configuration; all 85 are reported on every run and dispositioned individually in
[`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md). In
summary:

| Rule                                   | Count | File(s)                                                                   | Why not fixed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| -------------------------------------- | ----- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pmd:ApexDoc`                          | 29    | all 10 Apex classes                                                       | Every class and non-trivial method carries an explanatory comment; the rule requires ApexDoc `@description`/`@param` tag syntax, which this project does not use. No functional or security impact.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| `pmd:ApexUnitTestClassShouldHaveRunAs` | 26    | 4 test classes                                                            | `System.runAs` is used where it is meaningful: the three gate tests in `AuditPermissionServiceTest` run as a freshly inserted Minimum Access - Salesforce user to prove denial of `canViewSetup`/`assertCanViewSetup`, denial at `search` and `searchUsers` (the two data-returning entry points), and the permission-set equivalence (the gate opens exactly when the assigned permission set genuinely carries `ViewSetup`, which under managed packaging it does not). Of the remaining 26 tests, most are user-independent (cursor arithmetic, filter compilation, scanning a mock provider) and several require `ViewSetup` on the running user, which the test runner holds. |
| `slds:no-hardcoded-values-slds2`       | 18    | `auditExplorer.css`                                                       | SLDS 2 design-token advisories. Cosmetic; no security or functional impact.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `pmd:ExcessiveParameterList`           | 4     | `AuditTrailProvider`, `SetupAuditTrailProvider`, `MockAuditTrailProvider` | This is the testability seam. `SetupAuditTrail` rows cannot be inserted in an Apex test, so the query sits behind an injectable interface. The parameters are the query's bind values, passed explicitly so each is visibly bound at the point a reviewer most wants to see it.                                                                                                                                                                                                                                                                                                                                                                                                    |
| `pmd:CognitiveComplexity`              | 3     | `AuditQueryService`, `MockAuditTrailProvider`                             | Inherent to the algorithm — see below.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| `pmd:CyclomaticComplexity`             | 2     | `AuditQueryService`, `MockAuditTrailProvider`                             | As above.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `pmd:NcssCount`                        | 1     | `AuditQueryService.search`                                                | As above.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| `lwc:no-inline-disable`                | 1     | `auditExplorer.js:216`                                                    | One `eslint-disable-next-line no-await-in-loop` on the progressive-search loop. Each call needs the paging cursor returned by the previous one, so the awaits are sequential by necessity. Scoped to a single line and justified inline. Disabling the rule file-wide instead would silence it far more broadly and leave no marker at the call site.                                                                                                                                                                                                                                                                                                                              |
| `pmd:AvoidDebugStatements`             | 1     | `AuditQueryController.genericFailure`                                     | The single `System.debug(LoggingLevel.ERROR, ...)` is the server-side half of the generic error handling: unexpected exceptions are logged for the administrator and replaced with a non-specific client message, so platform exception text cannot leak query internals to the browser. It logs exception type and message only — no credential, session or personal data. Removing it would satisfy the linter by discarding the diagnostic trail.                                                                                                                                                                                                                               |

On the complexity findings: `SetupAuditTrail` cannot be filtered on `Section` or `Display`
in SOQL and supports no aggregate functions, so `AuditQueryService.search` must scan
backwards through time in bounded windows, post-filter in Apex, and maintain an exact
cursor across window boundaries while staying inside governor limits. Decomposing that
single stateful loop would spread it across several methods that could not be understood
or tested independently. The behaviour is pinned by tests, and the live paging check in
[`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) (118 rows exported against 118
in the org, 0 duplicates, with a 65-row same-timestamp block spanning a page boundary)
confirms the cursor on real data.

### Engines that need a runtime

PMD, CPD and the Graph Engine require a local JDK; the Flow engine requires Python 3.10
or later. If one is missing the engine **fails to load**: depending on the plugin version
it is either skipped silently, so the scan reports a false all-clear, or, as 5.16.0 did
for the flow engine on 2026-10-11, reported as a Critical `UninstantiableEngineError`
with no file, which is not a code finding. Check the engine and rule counts rather than
the violation total. The 2026-09-10 record notes OpenJDK 21 and records nothing about
Python (on 5.15.0 and the `force-app` workspace the flow engine was not in play); the
2026-10-11 three-tag runs had OpenJDK 21.0.12.1 and no Python, and Python 3.12.10 was
installed before the official-selector run below.

The Graph Engine needs particular care. `AuditQueryController.search` has a
**14,503-path** space, far beyond the stock 30s per-path budget; on timeout the engine
still prints "0 violations" and reports the abandoned entry point only as an easily missed
`Internal execution error`. `code-analyzer.yml` therefore sets `java_thread_timeout` to
600s.

Heap size is set to `2g` **deliberately, not higher**. Requesting more than the host can
spare makes the JVM thrash and the analysis times out anyway: on an 8 GB machine a 4g
request produced `3 path(s) from 2 entry point(s)` plus an error, whereas 2g with 4 threads
completed the full space. Running the Graph Engine alongside the other five engines can
lose the same memory race, so verify it with its own run on an otherwise idle machine:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector sfge
```

This must report **`14503 path(s) from 3/3 entry point(s)`**, 0 violations, and no
`Internal execution error` (~7 minutes). Treat any Graph Engine result that does not name
the path and entry-point counts as unproven.

### Official AppExchange command — 2026-10-11

Salesforce's submission instructions name a different selector and a specific output
file. That command was run on 2026-10-11 from a clean `git worktree` at commit `934f200`
(tag `v1.0.0`, the source that built released version `1.0.0.2`), from the package's
top-level directory, with no `--config-file`, no `--workspace` and no `node_modules`,
using plugin 5.16.0 with OpenJDK 21.0.12.1 and Python 3.12.10 installed:

```
sf code-analyzer rules --rule-selector AppExchange --rule-selector Recommended:Security
sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security \
  --output-file CodeAnalyzerReport.html
```

The selector resolved to **62 rules from 5 engines** (51 pmd, 4 retire-js, 3 eslint,
3 flow, 1 regex; no sfge and no cpd), so the result is not the vacuous zero this document
warns about. The run exited 0 and reported **"Found 0 violations."** The regex,
retire-js, pmd and eslint engines executed; the flow engine instantiated but had no Flow
metadata to scan. `CodeAnalyzerReport.html` is gitignored and is kept by the maintainer
outside the repository; the copy produced by this run is 65,085 bytes with SHA-256
`5c05b155418a8a1be3fa2ff77132260f3b62e628380b25afa4dc293d93c9169e`.

Comparing the two rule lists (`sf code-analyzer rules` with each selector), 48 of the 62
official rules are also in the three-tag union above. The other 14 are rules the union
run could not offer because `--workspace force-app` holds no metadata for them: 11 PMD
Visualforce rules (`AvoidCreateElementScriptLinkTag`, `AvoidHardcodedSecretsInVFAttrs`,
`AvoidUnauthorizedApiSessionIdInVisualforce`,
`AvoidUnauthorizedGetSessionIdInVisualforce`, `LoadCSSApexStylesheet`, `LoadCSSLinkHref`,
`LoadJavaScriptHtmlScript`, `LoadJavaScriptIncludeScript`, `VfCsrf`, `VfHtmlStyleTagXss`,
`VfUnescapeEl`) and the 3 flow rules; the package contains no Visualforce pages or
components and no Flows, so none of the 14 had anything to evaluate. What the official
selector does not reach is the two Graph Engine rules, and the 85 style findings fall
outside it. The official report is the file to upload; the three-tag scan and the
`--rule-selector sfge` run remain the supporting evidence. Full detail is in
[`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

## 11. Editions and compatibility

Lightning Experience only (the app is Lightning Web Components). Professional Edition is
not supported, because it cannot run custom Apex.
