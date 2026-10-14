# Scanner Findings and False Positives

This document covers every finding in the two scan reports attached to this
submission for Audit Trail Explorer `1.0.1.4` (`04thm000002tWirAAE`), and the
code-quality findings of the broader Code Analyzer scan that each release
also gets.

| Report                                                         | Result                                                                                                                                         | Covered in                 |
| -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| Source Code Scanner (Checkmarx), document 09                   | 3 Medium issues from one query, all in one test class; 0 quality issues                                                                        | Section 1, false positives |
| Salesforce Code Analyzer, AppExchange command, document 08     | 62 rules, 0 violations                                                                                                                         | Section 2                  |
| Broader Code Analyzer scan and Graph Engine run (not attached) | 119 code-quality findings (13 Moderate, 106 Low) and 1 Graph Engine performance finding; none tagged `Security`, `AppExchange` or `ErrorProne` | Section 3                  |

Line numbers refer to commit `f0ad675`, the source of `1.0.1.4`. `force-app`
has not changed since that commit.

## 1. Source Code Scanner (Checkmarx): false positives

| Item            | Value                                                                                        |
| --------------- | -------------------------------------------------------------------------------------------- |
| Job             | `a0BKX000000pcxh2AA`; report scan ID `a0OKX000001JTaT2AW`                                    |
| Package version | `1.0.1.4` (`04thm000002tWirAAE`)                                                             |
| Submitted       | Wed Oct 14 02:04:53 GMT 2026 (the job's Created Date in the Partner Security Portal)         |
| Report header   | Scan Start 2026-10-13 14:06:36, Scan End 2026-10-13 19:07:52, as printed by the scanner      |
| Profile         | Security and Quality Rules (`PortalAll`)                                                     |
| Engine          | Checkmarx 9.7, scanner service v3.2                                                          |
| Attached as     | `09-Checkmarx-Report.zip`, the portal's export, containing `report_phxcxmanwp001_42312.html` |

The report lists 28 checks, and only one has results: `Apex SOQL SOSL User
Mode Missing` (Medium), with 3 issues. All 15 Critical, High and Serious
checks report "No Issues Found". Among them are SOQL SOSL Injection, Stored
XSS and Reflected XSS (Critical); the four client DOM XSS and code-injection
checks (High); and FLS Create, FLS Update, CRUD Delete, Sharing, URL
Redirection Attack and XSRF (Serious). All 11 code-quality checks also report
no issues.

### `Apex SOQL SOSL User Mode Missing` (3, Medium)

| #   | File                             | Query lines | Data path in the report | Test method                                                  |
| --- | -------------------------------- | ----------- | ----------------------- | ------------------------------------------------------------ |
| 1   | `AuditPermissionServiceTest.cls` | 215-220     | 42, 43, 214, 218, 215   | `packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup`    |
| 2   | `AuditPermissionServiceTest.cls` | 248-253     | 42, 43, 247, 251, 248   | `packagedPermissionSetGrantsApexAccessRegardlessOfPackaging` |
| 3   | `AuditPermissionServiceTest.cls` | 264-270     | 42, 43, 247, 269, 264   | `packagedPermissionSetGrantsApexAccessRegardlessOfPackaging` |

Queries 1 and 2 read `PermissionSet` by name and namespace. Query 3 reads
`ApexClass` for the three runtime classes. Each data path starts at
`AuditPermissionServiceTest.class.getName()` on line 42 and ends in the
query's `:ns` bind.

**Disposition: false positive.** The flagged queries are test code that no
user can reach:

- The class is `@IsTest` and `private` (`AuditPermissionServiceTest.cls:10-11`).
  Nothing outside it can reference it, and its methods run only when Apex
  tests run. No page, component, Apex entry point or API request reaches
  these queries.
- The bound value is not user input. `packageNamespace()` (lines 41-44)
  returns the namespace prefix of the test class's own name: `atexplorer` in a
  managed install and `null` in a source deploy. It is used only as a bind
  variable and is never concatenated into query text.
- The queries read setup metadata, not customer records: the packaged
  permission set and the three runtime classes, so that the two tests can
  check what the shipped permission set grants.
- The runtime queries run in user mode and were not flagged:
  `SetupAuditTrailProvider.cls:42` (`Database.query(soql, AccessLevel.USER_MODE)`)
  and `AuditQueryController.cls:80-83` (`WITH USER_MODE`) are the only SOQL
  statements outside test classes.

## 2. Salesforce Code Analyzer: AppExchange command

Document 08 is the report of Salesforce's AppExchange command, run on
2026-10-12 against commit `f0ad675` with Code Analyzer plugin 5.16.0:

```
sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security \
  --output-file CodeAnalyzerReport.html
```

The selector resolved to 62 rules from 5 engines, and the run reported
**"Found 0 violations."** There is nothing to disposition. The attached
`CodeAnalyzerReport.html` is 64,954 bytes, SHA-256
`03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`. It is
zipped as `08-CodeAnalyzerReport.zip` because the review wizard does not
accept HTML files.

## 3. Broader Code Analyzer scan

Each release is also scanned with a wider selection, the `Recommended`,
`Security` and `AppExchange` tags together, using the repository's
`code-analyzer.yml`:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector Recommended \
  --rule-selector Security \
  --rule-selector AppExchange
```

The selection resolves to 310 rules from six engines (202 ESLint, 94 PMD,
6 regex, 4 RetireJS, 2 CPD and 2 Graph Engine rules). The `Security` tag adds
the Graph Engine rules `sfge:ApexFlsViolation` and
`sfge:DatabaseOperationsMustUseWithSharing`, which the other two tags do not
select. The same scan runs weekly in GitHub Actions. Its reports are not
attached; the results of every run are recorded in
[`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

### Result

Run of 2026-10-12 on `f0ad675` with Code Analyzer plugin 5.16.0, exit 0 with
`--severity-threshold 2`. The GitHub Actions workflow reproduced the same
counts on 2026-10-13 (run `38462017378`).

| Severity  | Count   |
| --------- | ------- |
| Critical  | **0**   |
| High      | **0**   |
| Moderate  | 13      |
| Low       | 106     |
| **Total** | **119** |

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

No finding carries the `Security`, `AppExchange` or `ErrorProne` tag. All 29
PMD AppExchange rules are clean, and RetireJS, the regex secrets engine, CPD
and the two Graph Engine security rules report 0 violations. Every finding is
a code-quality or style rule, and none is suppressed in `code-analyzer.yml`.

Compared with the scan of `1.0.0.2` (85 findings: 11 Moderate, 74 Low), the
changes are +19 `ApexUnitTestClassShouldHaveRunAs` (50 Apex test methods, up
from 29), +9 `ApexDoc` (new methods), +4 SLDS advisories (new CSS), +1
`CyclomaticComplexity` (the `AuditQueryServiceTest` class total) and +1
`no-inline-disable` (in the Jest file). `CognitiveComplexity` is unchanged at 3.

### Graph Engine on its own

The Graph Engine was also run by itself on 2026-10-12:

```
sf code-analyzer run \
  --config-file code-analyzer.yml \
  --workspace force-app \
  --rule-selector sfge
```

It analyzed 6,537 paths from all 3 entry points in 757 seconds, with no
internal error. The two security rules, `ApexFlsViolation` and
`DatabaseOperationsMustUseWithSharing`, reported 0 violations, so the CRUD/FLS
and sharing enforcement described in section 5 of document 01 is confirmed by
path analysis as well as by reading the code. This run selects every Graph
Engine rule, so it also reported one performance finding,
`AvoidDatabaseOperationInLoop`, explained at the end of this section.

### `CognitiveComplexity` (2 of 3), `CyclomaticComplexity` (1 of 3) and `NcssCount` (1) in `AuditQueryService`

**Accepted.** The locations are the class total (`AuditQueryService.cls:24`)
and `search()` (`AuditQueryService.cls:53`) for `CognitiveComplexity`, and
`search()` for `CyclomaticComplexity` and `NcssCount`.

The complexity comes from the problem. `SetupAuditTrail` cannot be filtered on
`Section` or `Display` in SOQL and supports no aggregate functions, so the
service has to scan backwards through time in bounded windows, filter in
Apex, and keep an exact cursor across window boundaries, all within governor
limits whatever the size of the org.

Version 1.0.1 moved more of the contract into `search()`. The date range is
resolved on the first call and pinned in the cursor (`pinRange`), paging is
keyset-based on `CreatedDate` and `Id` with the continuation id validated
before any query runs, and the range and position that come back from the
client are re-clamped on every call. The method was also kept to as few
branches as possible, so that the Graph Engine can analyze every path through
it, which is why these counts did not grow with the added behavior. Splitting
the scan loop further would spread one stateful algorithm across methods that
could not be understood or tested on their own.

The behavior is covered by tests. `multiBatchScanFindsAMatchInTheLastShortBatch`,
`sameTimestampRowsPageByIdAcrossBatches` and
`ceilingStopsACallWithoutLosingProgress` (`AuditQueryServiceTest.cls:425-527`)
shrink the scan to `scanBatch = 100` and `maxBatchesPerCall = 3` through two
`@TestVisible` fields (`AuditQueryService.cls:34-37`), so that a few hundred
mock rows cross real batch boundaries:

- a match that exists only in a short third batch is found, and the range is
  reported done after exactly three fetches;
- 250 rows that share one timestamp are paged by id across batch and page
  boundaries, and every row is returned exactly once;
- a call stopped by the ceiling at 300 scanned rows leaves the cursor on the
  last scanned row, and the next call finishes the remaining 50 in one short
  batch.

`pagingCoversEveryRowExactlyOnce` and `handlesManyRowsSharingOneTimestamp`
check the same no-duplicate, no-skip rule within one batch, and
`searchRoundTripsCursorJson` (`AuditQueryControllerTest.cls:67-100`) checks
that the keyset id and the pinned range survive the JSON round trip through
the browser. All 50 Apex tests passed on the released source (source deploy
`0Afh1000000NfiTCAS`) and against the installed `1.0.1.4` in a subscriber org
(run `707di0000LCKGo0`).

### `ExcessiveParameterList` (4) in `AuditTrailProvider`, `SetupAuditTrailProvider` and `MockAuditTrailProvider`

**Accepted.** The locations are `fetch` on the interface
(`AuditTrailProvider.cls:25`), on the production provider
(`SetupAuditTrailProvider.cls:9`) and on the mock
(`MockAuditTrailProvider.cls:19`), six parameters each, and the mock's `row`
test-data builder (`MockAuditTrailProvider.cls:69`), five.

This interface is what makes the code testable. `SetupAuditTrail` records
cannot be inserted in an Apex test, so the query sits behind an interface that
tests replace with a mock. The parameters are the query's filter values,
passed one by one so that each is visibly a bind variable. A criteria object
would hide the binding at the point a reviewer most wants to see it, so the
parameters stay explicit.

### `CognitiveComplexity` and `CyclomaticComplexity` in `MockAuditTrailProvider` and `AuditQueryServiceTest`

**Accepted.** This is test-support code, not part of the runtime path.
`MockAuditTrailProvider.fetch` (`MockAuditTrailProvider.cls:19`) is reported
under both rules because it mirrors the real provider's keyset paging, which
is what lets the tests above exercise paging without inserting
`SetupAuditTrail` rows. The class total of `AuditQueryServiceTest`
(`AuditQueryServiceTest.cls:2`, `CyclomaticComplexity`) counts its 28 small
test methods together.

### `@lwc/lwc-platform/no-inline-disable` (2) in `auditExplorer.js` and `auditExplorer.test.js`

**Accepted.** There are two `// eslint-disable-next-line no-await-in-loop`
comments. The first is in the progressive-search loop
(`auditExplorer.js:289`): each server call needs the paging cursor returned by
the previous one, so the calls have to run one after another. The second is in
the Jest suite's `settle()` helper (`__tests__/auditExplorer.test.js:81`),
which steps through the same chain of calls so the tests can check each step.
Each suppression covers a single line and carries a comment explaining it.
Turning the rule off for the whole file would silence it far more widely and
leave no marker at the call site.

### `ApexDoc` (38)

**Accepted.** Every class has a header comment that explains its role,
including the progressive-search contract of the two `search` entry points
(`AuditQueryController.cls:1-10`, `AuditQueryService.cls:1-23`). The rule asks
for more: a `/** */` comment on every public method, constructor and nested
class, an `@param` for each parameter and an `@return` on each non-void
method. The 38 findings are 16 public members without their own `/** */`
comment (constructors, the two `search` methods and small accessors such as
`AuditCursor.lastDate()`), 10 comments without matching `@param` tags and 12
without an `@return`. The code uses the tags where they add information, for
example for the six parameters of `AuditTrailProvider.fetch`
(`AuditTrailProvider.cls:13-24`) and the `@throws` of `AuditCursor`
(`AuditCursor.cls:49`). The net increase of nine since `1.0.0.2` is twelve new
findings on methods that 1.0.1 added, less three that went away with methods it
removed. No functional or security impact.

### `ApexUnitTestClassShouldHaveRunAs` (45)

**Accepted.** The four test classes hold 50 `@IsTest` methods. The rule flags
the 45 that run as the test runner; the other 5 use `System.runAs`, and they
are the five tests of the access gate, all in `AuditPermissionServiceTest.cls`:

- `deniesUserWithoutViewSetup` (lines 46-69): a user on the standard
  **Minimum Access - Salesforce** profile, which lacks **View Setup and
  Configuration**, gets `false` from `canViewSetup()` and the permission
  exception from `assertCanViewSetup()`.
- `blocksControllerEntryPointsForUnprivilegedUser` (lines 71-104): the same
  user is refused by `search` and `searchUsers`, the two `@AuraEnabled` methods
  that return data. The test checks that each refusal is an
  `AuraHandledException` whose message names **View Setup and Configuration**,
  which shows that the controller calls `setMessage()`; without it the client
  would see only "Script-thrown exception".
- `restrictedUserGetContextReportsNoAccessWithoutThrowing` (lines 106-121): the
  controller's third `@AuraEnabled` method, `getContext`, returns no audit data
  and is not gated (`AuditQueryController.cls:39-56`). For the same user it
  must answer `canViewSetup = false` instead of throwing, because the page uses
  that answer to choose between the search form and the "ask your
  administrator" message.
- `restrictedUserWithLocalViewSetupPermissionSetCanUseEveryEntryPoint`
  (lines 130-195): the same user, given **View Setup and Configuration**
  through a permission set created in the test org, can use `search`,
  `getContext` and `searchUsers`. This is what a subscriber's administrator
  does, and because packaging never strips a local permission set, the test
  holds for source deploys and managed installs alike.
- `packagedPermissionSetOpensTheAppWhenItCanGrantViewSetup` (lines 197-240):
  the same user, assigned only the shipped `Audit_Trail_Viewer` permission set,
  passes the gate exactly when that permission set carries `ViewSetup`. In a
  managed install it does not, because Salesforce strips the system permission
  at install, so in a subscriber org the test confirms the gate stays shut
  until the administrator grants the permission separately.

Of the other 45 methods, 31 do not depend on who runs them: the 28 in
`AuditQueryServiceTest` (paging, cursor, date range, filter and facet logic
against the mock provider), the two `AuditEventRow` mapping tests in
`SetupAuditTrailProviderTest`, and the Apex class access check in
`AuditPermissionServiceTest`. The remaining 14 pass only when the running user
holds `ViewSetup`, because they call a gated entry point, check the running
user's access, or run the real `SetupAuditTrail` query in user mode:
`allowsUserWithViewSetup`, all 11 methods of `AuditQueryControllerTest`, and
the two real-query tests in `SetupAuditTrailProviderTest`. The 50/50 passes
recorded in [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) therefore
show that the runner held `ViewSetup`. Wrapping these 45 tests in `runAs` to
satisfy the rule would add code without adding assurance. CSV escaping is
tested in the Jest suite
(`force-app/main/default/lwc/auditExplorer/__tests__/auditExplorer.test.js:311-347`
and the `CSV export` block at lines 689-762), not in Apex.

### `@salesforce-ux/slds/no-hardcoded-values-slds2` (22)

**Accepted.** These are SLDS 2 design-token advisories in the component
stylesheet (`auditExplorer.css`). The four added since `1.0.0.2` come from the
14 lines that 1.0.1 added for the "Filters changed" hint and the spinner
placeholders. Cosmetic only, with no security or functional impact.

### `AvoidDebugStatements` (1)

**Accepted.** The single `System.debug(LoggingLevel.ERROR, ...)`
(`AuditQueryController.cls:110`) is in `genericFailure`, the server-side half
of the error handling: an unexpected exception is written to the Apex debug
log and replaced with a fixed message to the client, so platform exception
text cannot reveal query details to the browser. `search`, `getContext` and
`searchUsers` each wrap their whole body in the same two catch blocks
(`AuditQueryController.cls:21-95`). The permission exception is the one whose
text reaches the client, through `permissionFailure` (lines 101-107), because
it is written for the user and names the missing permission. Every other
exception becomes `GENERIC_ERROR`.

Both halves are tested. `searchHidesInternalErrorDetail` and
`searchHidesDeserializationFailureDetail` (`AuditQueryControllerTest.cls:102-153`)
check that the client receives the generic text and none of "Malformed",
"SELECT", "SetupAuditTrail", "JSON" or field names, and
`blocksControllerEntryPointsForUnprivilegedUser` checks that the permission
message does reach the client from `search` and `searchUsers`.

The log line is a diagnostic record, not a notification. On a source deploy
an administrator with a trace flag on the user can read it in the debug log;
in a managed install, Salesforce hides managed-package debug output from the
subscriber org. The line contains the exception type and message only: never
a row of audit data, and no credential, session data or personal data.
Removing it would satisfy the rule by giving up that record.

### `sfge:AvoidDatabaseOperationInLoop` (1, Graph Engine run only)

**Accepted.** The standalone Graph Engine run reports one violation of this
rule: "A database operation occurred inside a loop [WhileLoopStatement at
AuditQueryService:116]", with the entry point at `AuditQueryController.cls:22`
and the `Database.query` at `SetupAuditTrailProvider.cls:42`. The report scores
it High; its tags are `DevPreview`, `Performance` and `Apex`, not `Security` or
`AppExchange`. The runs on `1.0.0.2` recorded 0 violations, so it first
appears on the 1.0.1 source.

The loop is the progressive, time-sliced scan that the application exists for
(`AuditQueryService.cls:116-167`). `SetupAuditTrail` cannot be filtered on
`Section` or `Display` in SOQL, so the service fetches bounded batches and
filters them in Apex, and each batch is one query. The loop is bounded in
every direction: at most `maxBatchesPerCall` (10) queries per transaction
against the limit of 100 SOQL queries; each client call is its own
transaction; and the loop also stops on a full page or a short batch. The
ceiling is covered by `ceilingStopsACallWithoutLosingProgress`
(`AuditQueryServiceTest.cls:484-527`). Taking the query out of the loop would
mean either fetching the whole date range in one query, which runs into heap
and row limits in large orgs, or giving up server-side filtering on the two
fields users most want to search.

Earlier scans, their environments, and the scan history of `1.0.0.2` and of the
unreleased 1.0.1 builds are recorded in
[`docs/CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).
