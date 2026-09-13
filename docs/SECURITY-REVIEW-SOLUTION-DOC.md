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
  |  (every method calls AuditPermissionService first; also issues one SOQL
  |   query directly, against the standard User object, for the "changed by"
  |   type-ahead - see section 6)
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

| Question                                         | Answer                                                                                                                                                                         |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Does the solution store data outside Salesforce? | **No.**                                                                                                                                                                        |
| Does the solution make external callouts?        | **No.** There is no `HttpRequest`, no named credential, and no remote site setting in the package.                                                                             |
| Does the solution create or modify any record?   | **No.** The package performs no DML of any kind.                                                                                                                               |
| Does the solution include a custom object?       | **No.**                                                                                                                                                                        |
| Where is data persisted?                         | Nowhere. Every request reads `SetupAuditTrail` (and, for the user type-ahead described below, `User`) live and returns the rows to the browser. Nothing is cached server-side. |
| Is any data sent to a third party?               | **No.**                                                                                                                                                                        |

Because nothing is stored, there is no data-retention, data-residency or data-deletion
surface. Uninstalling the package removes the code and leaves no residue.

## 4. Authentication and authorisation

The app has a single authorisation gate: the standard **View Setup and Configuration**
(`ViewSetup`) user permission, which is the same permission Salesforce itself requires to
view the Setup Audit Trail. The app grants no access that the user did not already have.

`AuditPermissionService.assertCanViewSetup()` enforces this by checking
`Schema.SObjectType.SetupAuditTrail.isAccessible()`. This was verified empirically rather
than assumed: under `System.runAs`, a user on a profile granting ViewSetup returns `true`,
and a user on **Minimum Access - Salesforce** returns `false`. `AuditPermissionServiceTest`
pins both cases with real users on real profiles.

Every `@AuraEnabled` method calls this gate before doing any work:

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
- Every Apex class in the package is declared `with sharing`.
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
- Paging correctness was validated against real data: 122 records over 18 pages,
  **0 duplicates and 0 skipped rows**.

## 9. Third-party code

**None.** The package contains no third-party JavaScript library, no static resource, and
no npm dependency shipped to the runtime. RetireJS reports zero findings.

## 10. Static analysis

Salesforce Code Analyzer v5 (`@salesforce/plugin-code-analyzer` 5.15.0), run from a clean
checkout as:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector Security \
  --rule-selector AppExchange
```

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

| Rule                                   | Count | File(s)                                                                   | Why not fixed                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| -------------------------------------- | ----- | ------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `pmd:ApexDoc`                          | 29    | all 10 Apex classes                                                       | Every class and non-trivial method carries an explanatory comment; the rule requires ApexDoc `@description`/`@param` tag syntax, which this project does not use. No functional or security impact.                                                                                                                                                                                                                                                  |
| `pmd:ApexUnitTestClassShouldHaveRunAs` | 26    | 4 test classes                                                            | `System.runAs` is used where it is meaningful — `AuditPermissionServiceTest` runs as real users on real profiles to prove the access gate. The rest exercise pure logic (cursor arithmetic, filter compilation, CSV escaping) where the running user is irrelevant.                                                                                                                                                                                  |
| `slds:no-hardcoded-values-slds2`       | 18    | `auditExplorer.css`                                                       | SLDS 2 design-token advisories. Cosmetic; no security or functional impact.                                                                                                                                                                                                                                                                                                                                                                          |
| `pmd:ExcessiveParameterList`           | 4     | `AuditTrailProvider`, `SetupAuditTrailProvider`, `MockAuditTrailProvider` | This is the testability seam. `SetupAuditTrail` rows cannot be inserted in an Apex test, so the query sits behind an injectable interface. The parameters are the query's bind values, passed explicitly so each is visibly bound at the point a reviewer most wants to see it.                                                                                                                                                                      |
| `pmd:CognitiveComplexity`              | 3     | `AuditQueryService`, `MockAuditTrailProvider`                             | Inherent to the algorithm — see below.                                                                                                                                                                                                                                                                                                                                                                                                               |
| `pmd:CyclomaticComplexity`             | 2     | `AuditQueryService`, `MockAuditTrailProvider`                             | As above.                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `pmd:NcssCount`                        | 1     | `AuditQueryService.search`                                                | As above.                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `lwc:no-inline-disable`                | 1     | `auditExplorer.js:216`                                                    | One `eslint-disable-next-line no-await-in-loop` on the progressive-search loop. Each call needs the paging cursor returned by the previous one, so the awaits are sequential by necessity. Scoped to a single line and justified inline. Disabling the rule file-wide instead would silence it far more broadly and leave no marker at the call site.                                                                                                |
| `pmd:AvoidDebugStatements`             | 1     | `AuditQueryController.genericFailure`                                     | The single `System.debug(LoggingLevel.ERROR, ...)` is the server-side half of the generic error handling: unexpected exceptions are logged for the administrator and replaced with a non-specific client message, so platform exception text cannot leak query internals to the browser. It logs exception type and message only — no credential, session or personal data. Removing it would satisfy the linter by discarding the diagnostic trail. |

On the complexity findings: `SetupAuditTrail` cannot be filtered on `Section` or `Display`
in SOQL and supports no aggregate functions, so `AuditQueryService.search` must scan
backwards through time in bounded windows, post-filter in Apex, and maintain an exact
cursor across window boundaries while staying inside governor limits. Decomposing that
single stateful loop would spread it across several methods that could not be understood
or tested independently. The behaviour is pinned by tests, including a paging check over
122 real records and 18 pages showing 0 duplicates and 0 skipped rows.

### Engines that need a runtime

PMD, CPD and the Graph Engine require a local JDK; the Flow engine requires Python. If one
is missing the engine **fails to load and is silently skipped**, and the scan reports a
false all-clear. This scan ran with OpenJDK 21 and Python 3.12 present.

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

## 11. Editions and compatibility

Lightning Experience only (the app is Lightning Web Components). Professional Edition is
not supported, because it cannot run custom Apex.
