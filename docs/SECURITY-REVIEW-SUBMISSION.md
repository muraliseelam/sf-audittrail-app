# Security Review Submission Plan

This is the working document for taking managed package **Audit Trail
Explorer** (`atexplorer`, `0Hohm0000000NHZCA2`, released version `1.0.1.4`,
`04thm000002tWirAAE`, built from commit `f0ad675` and promoted 2026-10-12;
`1.0.0.2`, `04thm000002OtQPAA0`, remains released as the previous version)
through AppExchange Security Review. It records what is verified true today,
what must change first, the end-to-end procedure, and what could not be
confirmed from a primary source.

**Status:** the package is released in the Salesforce packaging sense only.
It has **not** been submitted for Security Review, has **not** been reviewed,
and has **no** AppExchange listing. Nothing here changes that, and nothing in
this document should be read as a review outcome.

Every claim below cites a file and line in this repository or a Salesforce
page. Where a source is secondary, stale or conflicting, the text says so.
The findings in sections 2-4 are kept as written on 2026-10-11, as the record
of what was found: their line numbers were measured on commit `f27a009` (the
`1.0.0.2` source), so a `force-app/` citation there refers to that commit
(`git show f27a009:<path>`), not to the current files, and citations into
Markdown files may have shifted since. Text added on 2026-10-12 cites the
`1.0.1` source (`f0ad675`, the commit `1.0.1.4` was built from) by its current
line numbers.

## 1. Status on 2026-10-12

| Item                               | Verified state today                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Evidence                                                                                                   |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------- |
| Package version                    | Managed 2GP `1.0.1.4` (`04thm000002tWirAAE`, `Package2VersionId` `05ihm0000001CK5AAM`), built 2026-10-12 from `f0ad675` with 96% coverage and `HasPassedCodeCoverageCheck` `true`; promoted 2026-10-12 from Dev Hub `00Dhm000004MOXjEAO` (`sf package version report`: Released `true`, Ancestor Version `1.0.0.2`). `1.0.0.2` (`04thm000002OtQPAA0`) stays released as the previous version; `1.0.1.1`-`1.0.1.3` are superseded betas, never promoted                                                                                                                                                                                                                                                                                                                          | `sfdx-project.json:23-27`; `sf package version report --package 04thm000002tWirAAE` on 2026-10-12          |
| Review / listing                   | Not submitted, not reviewed, not listed                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | `README.md:237-238`, `docs/LIVE-ORG-VALIDATION.md:796-799`                                                 |
| Local gates                        | `npm run lint`, `npm run prettier:verify`, `npm run test:unit:coverage` all pass on the `1.0.1` source; Jest 26/26 (was 7); `auditExplorer.js` 95.16% statements / 79.34% branches / 95.65% functions / 94.84% lines, `csv.js` 100% (v8 coverage provider; the stock Babel provider prints an empty table inside a git worktree on this machine, a measurement quirk, not a code problem)                                                                                                                                                                                                                                                                                                                                                                                       | Run in the release worktree on 2026-10-12                                                                  |
| Apex tests                         | 50/50 (was 29): source deploy of `f0ad675` into the namespaced scratch org `ate-101` (`00Dh100000146fmEAA`), deploy `0Afh1000000NfiTCAS`, 18/18 components, `RunLocalTests` 50 run / 0 failed; managed `1.0.1.4` in the clean scratch org `ate-mgd` (`00Ddi00000EXdFSEA1`), `RunAllTestsInOrg` run `707di0000LCKGo0`, 50 passed / 0 failed. 96% coverage at package build, `HasPassedCodeCoverageCheck` `true`; per class `AuditQueryController` 92%, `AuditQueryService` 96%, every other class with executable lines 100% (`AuditFilter` has none)                                                                                                                                                                                                                            | Deploy and test-run ids as stated; `sf package version report`                                             |
| Code Analyzer (repo selector)      | On `f0ad675`, plugin 5.16.0, `--rule-selector Recommended --rule-selector Security --rule-selector AppExchange --workspace force-app` with the committed config: 310 rules from 6 engines; exit 0; 119 violations across 16 files = 0 Critical / 0 High / 13 Moderate / 106 Low, none carrying the Security, AppExchange or ErrorProne tag. Versus the `1.0.0.2` baseline (85 = 11 Moderate / 74 Low, re-confirmed 2026-10-11): +19 `ApexUnitTestClassShouldHaveRunAs` and +9 `ApexDoc` from the new tests and methods, +4 SLDS hardcoded values from the new CSS, +1 `CyclomaticComplexity` (`search()`), +1 `no-inline-disable` (the Jest `settle()` helper); `FieldNamingConventions`, `AvoidDeeplyNestedIfStmts` and `ApexUnitTestClassShouldHaveAsserts` no longer appear  | Run 2026-10-12 in the release worktree after `npm ci`, 11 minutes; section 5, step 8                       |
| Code Analyzer (Graph Engine alone) | On `f0ad675`, `--rule-selector sfge` with the committed config (`java_thread_timeout` 1,800,000 ms, 2g heap, 4 threads): "analyzed 6537 path(s) from 3 entry point(s)", 3/3 entry points, no internal execution error, 757 s on an idle host. The two Security-tagged rules (`ApexFlsViolation`, `DatabaseOperationsMustUseWithSharing`) report 0 violations; the one finding is `AvoidDatabaseOperationInLoop` (Performance, not Security or AppExchange) on the bounded batch loop at `AuditQueryService.cls:116`, which is the design (at most `maxBatchesPerCall` = 10 queries per transaction, each call its own transaction) and is accepted. The path count fell from 14,503 (`1.0.0.2`) to 6,537 because `search()` was rewritten with fewer branches; CI now pins 6537 | `code-analyzer.yml` (sfge block); `.github/workflows/code-analyzer.yml` (path-count check); run 2026-10-12 |
| Official-selector report           | Regenerated 2026-10-12 from the release worktree at `f0ad675` (the source of `1.0.1.4`) after `npm ci`, with Salesforce's command (`--rule-selector AppExchange --rule-selector Recommended:Security`, no `--config-file`, no `--workspace`): 62 rules from 5 engines; exit 0, "Found 0 violations." Kept outside the repository; SHA-256 `03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`, 64,954 bytes. The 2026-10-11 report for `1.0.0.2` (`5C05B155...`) is superseded                                                                                                                                                                                                                                                                                   | Section 2.2; section 5, step 8; `.gitignore:55`                                                            |
| Checkmarx scan                     | Never run; the word does not appear in the repository                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | grep of `README.md`, `SECURITY.md`, `CHANGELOG.md`, `docs/`                                                |
| Reviewer test org                  | Persistent Developer Edition `00Dbm00000u2XaoEAE` with `04thm000002OtQPAA0` (`1.0.0.2`) installed, 29/29 tests; no install of `1.0.1.4` there is recorded; no reviewer users or instructions recorded                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | `docs/LIVE-ORG-VALIDATION.md:301-326`                                                                      |
| Org access on this machine         | Dev Hub `partner-pbo` (`00Dhm000004MOXjEAO`) and the scratch orgs `ate-101` and `ate-mgd` (both expire 2026-10-19) were used on 2026-10-12 for the `1.0.1` builds, the promotion and the validation runs above; the Partner Console and the DE org remain owner steps                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Run ids above                                                                                              |
| Source drift since the build       | `force-app` identical to `f0ad675`, the commit `1.0.1.4` was built from; the one later commit, `37c2ad9`, records the `1.0.1.4` alias and the 6537 path pin (config and CI only). The maintainer tags `v1.0.1` on the final commit of this documentation pass                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | `git diff --stat f0ad675..HEAD -- force-app` is empty (verifier run 2026-10-12)                            |
| Next-version config                | `versionName` `Version 1.0.1`, `versionNumber` `1.0.1.NEXT`, `ancestorVersion` `HIGHEST`; aliases `1.0.1-1` to `1.0.1-4` recorded                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | `sfdx-project.json:4-6,24-27`                                                                              |

## 2. Blockers - fix before submitting

**No code or documentation finding is a blocker.** Sixty-seven candidate
findings (60 merged from 87 raw findings across eight review dimensions, plus
7 added by a completeness critic) were each judged by three independent
verifiers; 63 were confirmed (0 blocker, 0 high, 12 medium, 41 low, 10 info)
and 4 were rejected (section 10 lists the four). None was judged something a
Salesforce reviewer would fail or send back: every data-returning entry point
is gated, every production class is `with sharing`, SOQL uses bind variables
and `USER_MODE`, there are no callouts, no storage, no secrets and no
third-party JavaScript.

Two **process artifacts** were missing that Salesforce lists as required for
this solution type; the Code Analyzer report (2.2) was produced on 2026-10-11
and regenerated for `1.0.1.4` on 2026-10-12; the Checkmarx report (2.1) is
still missing. They are not defects in the
package, but without them Security Review Operations returns the submission
at the 1-2 week verification stage, so the Checkmarx report still gates a
successful submission in practice.

### 2.1 Checkmarx (Source Code Scanner) report - MISSING

- **Why a reviewer cares:** the Required Materials table marks "Checkmarx
  report" required for "Salesforce Native Solution with Lightning
  Components", and the Code Analyzer page says its scan "is in addition to the
  scan that you must complete using the Source Code Scanner". The repository
  never mentions it.
- **Fix [Owner]:** connect the Dev Hub to the Partner Console, create the
  draft listing, link version `1.0.1.4` (`04thm000002tWirAAE`), then scan it
  on the Partner Security Portal
  (`https://security.my.salesforce-sites.com/sourcescanner/`; the URL
  printed in the guide, `security.secure.force.com`, is dead). Three scans per
  review are included. Expect possible CRUD/FLS false positives on
  `Database.query(soql, AccessLevel.USER_MODE)`
  (`force-app/main/default/classes/SetupAuditTrailProvider.cls:42` in the
  `1.0.1` source) and `WITH USER_MODE` (`AuditQueryController.cls:83`);
  dispose of them in the false-positive document (section 2.3).
- **Caveat:** Salesforce's own pages conflict (see section 9). The
  conservative reading, both reports, is what the materials table and the
  live portal FAQ state.
- Source: <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_required_materials.htm>

### 2.2 Code Analyzer report from the official command - DONE 2026-10-11, regenerated for 1.0.1 on 2026-10-12

- **Why a reviewer cares:** the instructions name one command and one file:
  `sf code-analyzer run --rule-selector AppExchange --rule-selector
Recommended:Security --output-file CodeAnalyzerReport.html`, run from the
  package's top-level directory on source matching the submitted version, and
  "Upload your clean CodeAnalyzerReport.html file". The repo's reproducible
  scan uses `--rule-selector Recommended --rule-selector Security
--rule-selector AppExchange --workspace force-app` (`code-analyzer.yml:5-6`,
  `.github/workflows/code-analyzer.yml:86-94`). That is a superset, so it is
  not weaker, but it is not the file the reviewers ask for, and its 85
  style-rule findings invite questions the official report should not raise.
  The HTML is gitignored (`.gitignore:55`) and the only persisted copy is a
  30-day CI artifact from 2026-09-19 (`docs/CODE-ANALYZER-SCAN-RECORD.md:255-257`).
- **Done 2026-10-11 [Repo]:** from a clean `git worktree` at `934f200`
  (tag `v1.0.0`; no `node_modules`, no `--config-file`, no `--workspace`),
  in the package's top-level directory, with `@salesforce/cli` 2.153.5 and
  code-analyzer plugin 5.16.0, after Python 3.12.10 was installed.
  `sf code-analyzer rules` with the two official selectors
  (`AppExchange`, `Recommended:Security`) resolved to 62 rules from 5
  engines (pmd 51, retire-js 4, eslint 3, flow 3, regex 1; no sfge, no cpd).
  `sf code-analyzer run` with the same selectors and
  `--output-file CodeAnalyzerReport.html` exited 0 with "Found 0
  violations." (rules executed from regex, retire-js, pmd and eslint; the
  flow engine had no Flow metadata to scan). The HTML is kept by the
  maintainer outside the repository, as `.gitignore:55` requires; SHA-256
  `5C05B155418A8A1BE3FA2FF77132260F3B62E628380B25AFA4DC293D93C9169E`
  (65,085 bytes). It must be regenerated from the same commit as the
  submitted version if the shipped source ever changes. The three-tag scan
  and the `--rule-selector sfge` run remain supporting evidence (section 1).
- **Regenerated for `1.0.1` on 2026-10-12 [Repo]:** the shipped source
  changed, so the report was produced again from the release worktree at
  `f0ad675` (the commit `1.0.1.4` was built from), in the package's top-level
  directory, with the same CLI and plugin versions, after `npm ci` (see the
  prerequisite in section 5, step 8). The two official selectors again
  resolved to 62 rules from 5 engines, and the run exited 0 with "Found 0
  violations." (rules executed from retire-js, eslint, regex and pmd; the flow
  engine had no Flow metadata to scan). SHA-256
  `03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`
  (64,954 bytes), kept by the maintainer outside the repository. This is the
  file to upload for `1.0.1.4`; the 2026-10-11 report above is superseded.
- Source: <https://developer.salesforce.com/docs/platform/salesforce-code-analyzer/guide/appexchange.html>

### 2.3 Documents the wizard asks for that did not exist on 2026-10-11

Status: the first and third items below were drafted on 2026-10-11 as
`docs/SECURITY-PROGRAM-STATEMENT.md` (publisher name, targets, contacts and
signature read "(to be supplied by the publisher)") and `docs/USER-GUIDE.md`.
The second still waits on the Checkmarx scan (2.1).

- A **company information security policy / security program statement**.
  `SECURITY.md:39-86` is a vulnerability-disclosure policy only. Salesforce
  says it factors in company size, so a one-page statement (SDLC, how
  vulnerabilities are handled, remediation targets, breach response,
  contacts) is enough. [Repo drafts, Owner signs]
- A **false-positive document** that also covers the Checkmarx results.
  `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md` covers the 85 Code Analyzer
  findings (none Security- or AppExchange-tagged, lines 37-70) but nothing
  from Checkmarx, because that scan has never run. [Repo, after 2.1]
- **End-user / reviewer usage documentation.** `README.md` covers install and
  development; nothing explains using search, facets, detail and CSV export,
  and nothing tells a reviewer how to set up the two grants for a test user.
  [Repo drafts]
- Source: <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_required_materials.htm>

## 3. Should fix before submitting

Confirmed medium findings. Each is a real defect or a false statement that a
reviewer or customer could hit; none fails the review on its own. All
thirteen are now resolved. The documentation items (3.1, 3.2, 3.3, 3.9, 3.13)
were applied on 2026-10-11 under runbook step 9 (commit `c484205`). The code
items (3.4-3.8, 3.10-3.12) were fixed in `1.0.1`: commit `47bd65f`, with the
follow-ups `41e2a29`, `f05ed25` and `f0ad675` that trim branches on the
search path so the Graph Engine can analyse it (section 1), shipped as
`1.0.1.4` (`04thm000002tWirAAE`, built from `f0ad675`, promoted 2026-10-12).
Each finding's text is kept as written, as the record of what was found; a
closing line on each says how it was resolved, citing the `1.0.1` source.

### 3.1 README install section contradicts itself

- `README.md:116-120`: "That permission set grants 'View Setup and
  Configuration' (and its `ViewRoles` dependency) ... This is the minimum
  access the app needs". Twelve lines earlier, `README.md:104-107` says the
  package cannot grant it and `ViewSetup` "is `false` once installed";
  `README.md:122-130` repeats the caveat a third time. The permission set
  description subscribers see in Setup
  (`force-app/main/default/permissionsets/Audit_Trail_Viewer.permissionset-meta.xml:5`)
  leads with the same statement before qualifying it.
- **Why it matters:** the README is the user documentation reviewers read to
  set up their test user; two incompatible statements about the only
  authorisation control cost a round trip, and a subscriber reading line 116
  would skip step 2 and see access errors.
- **Fix:** delete lines 116-120 or rewrite to "Under a managed install the
  packaged permission set grants only the app, its tab and its Apex classes;
  the `ViewSetup`/`ViewRoles` entries in the source take effect only for
  source deploys." Fold the blockquote at 122-130 into "Two grants are
  required". Reword the permission set description to lead with what managed
  subscribers get (metadata change, new version).
- **Resolved** by the 2026-10-11 documentation pass (`c484205`); the
  permission set description was reworded in `1.0.1`
  (`Audit_Trail_Viewer.permissionset-meta.xml:4-5`).

### 3.2 Findings-disposition paragraph misdescribes the runAs tests

- `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md:162-169` says the tests prove
  denial "by both `@AuraEnabled` entry points, and that the shipped permission
  set alone is sufficient to grant access", and that the other tests are
  "pure logic (cursor arithmetic, filter compilation, CSV escaping)".
- **Why it matters:** "alone is sufficient" is the assertion of a deleted test
  that `CHANGELOG.md:68-73` records as "an outcome the managed platform
  forbids"; the current test asserts equivalence only
  (`AuditPermissionServiceTest.cls:114-118`). The controller has three
  `@AuraEnabled` methods, not two (`AuditQueryController.cls:17,47,59`). CSV
  escaping is a Jest test, not Apex. Of the 26 non-runAs Apex tests, eight
  depend on the running user holding `ViewSetup`. This is the document handed
  to the reviewer with the scan report, and it contradicts the README's
  "Two grants are required" on the central managed-packaging fact.
- **Fix:** rewrite the paragraph: runAs is used in the three gate tests
  (denial of `canViewSetup`/`assertCanViewSetup`; denial at `search` and
  `searchUsers`, the two data-returning entry points; and the permission-set
  equivalence test, which proves the gate opens exactly when the assigned
  permission set genuinely carries `ViewSetup`, which under managed packaging
  it does not). Of the remaining 26 tests, 15 are user-independent and 8
  require `ViewSetup` on the running user. Drop "alone is sufficient" and
  "CSV escaping". Align `docs/SECURITY-REVIEW-SOLUTION-DOC.md:211`.
- **Resolved** by the 2026-10-11 documentation pass (`c484205`). The test
  counts quoted above are those of `1.0.0.2`; `1.0.1` has 50 Apex tests.

### 3.3 Solution Doc overstates the positive runAs test

- `docs/SECURITY-REVIEW-SOLUTION-DOC.md:61-64`: "under `System.runAs`, a user
  on a profile granting ViewSetup returns `true` ... pins both cases with
  real users on real profiles." The only unconditional positive test,
  `AuditPermissionServiceTest.cls:78-83`, has no `runAs` and says "The
  running test user is an administrator". The production comment is accurate
  and narrower (`AuditPermissionService.cls:11-12`, "pins the negative case").
- **Fix:** either reword section 4 ("the negative case is pinned under
  `System.runAs` on Minimum Access - Salesforce; the positive case is
  exercised by the running test user and, where the packaging model allows
  it, by a Minimum Access user assigned the shipped permission set"), or add
  the test in 3.4 so the sentence becomes true.
- **Resolved** by the 2026-10-11 documentation pass (`c484205`); the test in
  3.4 now exists, so the stronger sentence is also true of `1.0.1`.

### 3.4 No deterministic positive-path test; `getContext` has no restricted-user test

- `AuditPermissionServiceTest.cls:110-124`: the only runAs positive branch is
  `if (grantsViewSetup) { AuditQueryController.search(null, null, 5); }`,
  which never executes in a managed org (`PermissionsViewSetup` is `false`,
  `docs/LIVE-ORG-VALIDATION.md:60`) and asserts nothing when it does.
  `AuditQueryControllerTest.cls:77-85` asserts only that `canViewSetup` is
  not null, which a primitive Boolean always satisfies. The deterministic
  check was written as a throwaway class "deliberately not part of this
  repository" (`docs/LIVE-ORG-VALIDATION.md:182-184`).
- **Fix (test change, new version):** build a Minimum Access user plus an
  in-test `PermissionSet` with `PermissionsViewSetup=true` and
  `PermissionsViewRoles=true`, assign it, and under `runAs` assert
  `canViewSetup()==true`, that `search` with a mock provider returns one row,
  that `searchUsers` finds the user, and that `getContext().get('canViewSetup')`
  is `true`; mirror `getContext` under the restricted user asserting `false`.
- **Resolved in 1.0.1** (`47bd65f`, shipped in `1.0.1.4`):
  `restrictedUserWithLocalViewSetupPermissionSetCanUseEveryEntryPoint`
  (`AuditPermissionServiceTest.cls:131-196`) inserts a Minimum Access user and
  an in-test permission set with `PermissionsViewSetup` and
  `PermissionsViewRoles`, and under `runAs` asserts `canViewSetup()` is
  `true`, that `search` returns the one mock row, that `getContext` reports
  `true` and that `searchUsers` finds the user;
  `restrictedUserGetContextReportsNoAccessWithoutThrowing` (`:107-122`)
  asserts `false` for the restricted user; the `grantsViewSetup` branch now
  asserts a positioned result and `contextExposesRetentionWindow` asserts
  `canViewSetup` is `true`.

### 3.5 `searchUsers` has no exception handling; the error policy is overstated

- `AuditQueryController.cls:59-89` has no try/catch; `search` (19-34) does.
  `AuditPermissionService.AuditPermissionException` from line 64 and any
  `QueryException` from 78-85 reach the client raw. The repository's own
  test pins the asymmetry (`AuditPermissionServiceTest.cls:68-73` catches the
  raw exception from `searchUsers` but `AuraHandledException` from `search`).
  `docs/SECURITY-REVIEW-SOLUTION-DOC.md:133-135` ("Every other exception is
  converted to a generic message") and `FINDINGS-DISPOSITION.md:180-184`
  are therefore false for this method. The LWC masks it by swallowing the
  rejection (`auditExplorer.js:311-313`).
- **Why it matters:** practical leak is small (no SOQL text, no data), but
  reviewers check that every `@AuraEnabled` method handles errors
  consistently, and the Solution Doc makes a categorical claim the code does
  not honour.
- **Fix:** wrap the body of `searchUsers` in the same handler as `search`
  (rethrow the permission error as `AuraHandledException` with `setMessage`,
  convert everything else via `genericFailure`), update the test to expect
  `AuraHandledException`, and surface the error in the LWC. If the code is
  not changed before submission, scope the Solution Doc sentence to `search()`.
- **Resolved in 1.0.1** (`47bd65f`, shipped in `1.0.1.4`): `searchUsers` and
  `getContext` are wrapped in the same handler as `search`
  (`AuditQueryController.cls:40-57,59-95`): the permission error is rethrown
  through `permissionFailure()`, an `AuraHandledException` with `setMessage`
  (`:101-107`), and everything else through `genericFailure()`;
  `blocksControllerEntryPointsForUnprivilegedUser` expects an
  `AuraHandledException` naming "View Setup and Configuration" from both
  entry points, and the LWC surfaces a type-ahead failure instead of
  swallowing it (`auditExplorer.js:391-396`).

### 3.6 `cacheable=true` on `getContext` and `searchUsers` versus "never cached"

- `AuditQueryController.cls:47,59` declare `cacheable=true`. `docs/PRIVACY.md:25-26`
  ("never stored, cached, or logged"), `docs/PRIVACY.md:36`,
  `docs/ARCHITECTURE.md:33-34` and `CHANGELOG.md:130` say the type-ahead
  results are never cached. The Solution Doc is correctly qualified ("Nothing
  is cached server-side", line 48); the other three are not.
- **Why it matters:** a reviewer diffing the privacy statement against the
  annotations sees a contradiction about personal data (user names and
  usernames). Behaviourally, a revoked `ViewSetup` keeps the filter UI and a
  cached user list visible until reload; the next `search()` is correctly
  denied, so there is no exposure.
- **Fix:** change line 59 (and preferably 47) to `cacheable=false`; both
  calls are imperative and per-call gated. Or keep caching and amend the
  three documents to "never cached server-side; held in the Lightning
  client-side action cache for the page session".
- **Resolved in 1.0.1** (`47bd65f`, shipped in `1.0.1.4`): both methods are
  `@AuraEnabled(cacheable=false)` (`AuditQueryController.cls:40,59`), so the
  "never cached" statements are true as written.

### 3.7 Seen-id cap silently truncates the exclusion set

- `AuditCursor.cls:36-43` appends every same-timestamp id without bound;
  `seenIdSet()` (50-53) copies only the first `MAX_SEEN_IDS` (5000). Above
  5,000 rows at one `CreatedDate`, `Id NOT IN :excludeIds`
  (`SetupAuditTrailProvider.cls:31`) no longer excludes consumed rows, the
  query has no `Id` tiebreak (line 33), consumed rows come back as
  duplicates, and the cursor stops advancing. This contradicts
  `AuditCursor.cls:7-8,14-15` and `SetupAuditTrailProvider.cls:28-29`. The
  5,000-id bind has never been executed (`AuditQueryServiceTest.cls:259-274`
  asserts only set size) and may exceed the SOQL statement length.
- **Why it matters:** not a security issue (bounded per call, self-inflicted
  only) but a silent correctness failure in an audit tool at a scale a large
  profile/FLS deploy can reach, with absolute "no duplicates" claims in code
  and docs.
- **Fix (code, new version):** preferred, replace the `NOT IN` exclusion with
  a two-column keyset: `ORDER BY CreatedDate DESC, Id DESC` and on
  continuation `WHERE (CreatedDate < :lastDate OR (CreatedDate = :lastDate
AND Id < :lastId))`, verified in a scratch org. Otherwise fail closed when
  the cap is exceeded and lower it to a value that fits the statement limit.
  Add a test with more than 5,000 mock rows at one timestamp. If deferred,
  soften the comments and `docs/ARCHITECTURE.md:70-77` to state the limit.
- **Resolved in 1.0.1** (`47bd65f`, continuation rules simplified in
  `f0ad675`, shipped in `1.0.1.4`): the `NOT IN` exclusion is gone. The query orders by
  `CreatedDate DESC, Id DESC` and a continuation adds
  `(CreatedDate < :upperBound OR Id < :lastId)`
  (`SetupAuditTrailProvider.cls:27,35`); the cursor carries one `lastId`
  instead of a list and has no cap (`AuditCursor.cls:24,53-65`), and
  `lastIdValue()` rejects a positioned cursor whose id is blank, malformed or
  not a `SetupAuditTrail` id. `sameTimestampRowsPageByIdAcrossBatches` pages
  250 same-timestamp rows across batch and page boundaries exactly once, and
  `realQueryExecutesWithEveryOptionalFilter` executes the keyset predicate
  against the real object.

### 3.8 The multi-batch scan path has never executed in any test or recorded run

- `AuditQueryService.cls:24-25` sets `SCAN_BATCH=1000` and
  `MAX_BATCHES_PER_CALL=10` (private). The largest test input is 25 rows
  (`AuditQueryServiceTest.cls:45`), so `batch.size() < SCAN_BATCH` is always
  true and lines 113-118 (slice advance) and the 10-batch exit never run. Live
  runs scanned 118 and 122 rows, both under one batch. Yet
  `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md:116-118` and
  `SOLUTION-DOC.md:225-226` say the behaviour "is pinned by tests", and the
  "governor limits never bind" claim (`AuditQueryService.cls:16-18`,
  `README.md:54-55`) is analytical, not evidenced.
- **Fix:** make the two constants `@TestVisible` (or build 2,500+ mock rows)
  and add tests for: a filter matching only the oldest of 2,500 rows
  (`fetchCount==3`, `done==true`); 1,500 same-timestamp rows across a batch
  boundary; more than 10,000 rows with a non-matching filter (`done==false`,
  `scannedCount==10000`, resume completes). Narrow the "pinned by tests"
  sentences to the cursor until then.
- **Resolved in 1.0.1** (`47bd65f`, renamed in `41e2a29`, shipped in
  `1.0.1.4`): the two constants became `@TestVisible` `scanBatch` and
  `maxBatchesPerCall` (`AuditQueryService.cls:34-37`); with
  `useSmallBatches()` (100 rows, 3 batches) the tests
  `multiBatchScanFindsAMatchInTheLastShortBatch` (250 rows, three fetches,
  the match in the short last batch, `done`),
  `sameTimestampRowsPageByIdAcrossBatches` and
  `ceilingStopsACallWithoutLosingProgress` (350 rows: 300 scanned, `done`
  `false`, the resume finishes the remaining 50) exercise the slice advance
  and the per-call ceiling (`AuditQueryServiceTest.cls:426-528`).

### 3.9 Test level recorded for the headline subscriber-org run cannot be right

- `docs/LIVE-ORG-VALIDATION.md:116-119` and `README.md:194-195` say
  `RunLocalTests` ran 29 tests "as namespaced `atexplorer.*` classes" in a
  clean scratch org. `RunLocalTests` excludes installed managed-package tests
  by definition, so in that org it would run zero tests. The earlier record
  correctly says `RunAllTestsInOrg` (line 127) and the 2026-09-10 record
  lists the classes (line 251).
- **Fix:** record the command actually used for run `707RK0000BPQrG1`
  (`RunAllTestsInOrg` or `--class-names ...`) in both places. The result is
  corroborated by two other runs, so this is a transcription error, not a
  missing result; but it is the headline figure and a reviewer can spot it.
- **Resolved** by the 2026-10-11 documentation pass (`c484205`).

### 3.10 Upper date bound comes from the browser clock

- `auditExplorer.js:129-131,144-146` always sends `endDateMillis = Date.now()`.
  The server substitutes its own clock only when the bound is null
  (`AuditQueryService.cls:44-46`), and the `nowMillis` it returns from
  `getContext` (`AuditQueryController.cls:52`) is never read (`js:79-82`).
- **Why it matters:** a workstation clock ten minutes slow silently hides the
  most recent events under every preset while the UI says "Search complete".
  In a compliance tool the newest events are the ones most often checked.
- **Fix (code):** send `endDateMillis: null` for presets so the server uses
  `Datetime.now()`, and derive the preset start from the server clock; keep
  explicit bounds for the custom range. Add a Jest assertion.
- **Resolved in 1.0.1** (`47bd65f`, cursor handling simplified in `f0ad675`,
  shipped in `1.0.1.4`): for a preset the client sends only `lastDays` and no
  bounds (`auditExplorer.js:199-203`); the server resolves end = now and
  start = now minus min(N, 180) from its own clock in `pinRange()` and pins
  both in the cursor (`AuditQueryService.cls:200-211`,
  `AuditCursor.rangeStartMillis`/`rangeEndMillis`), re-clamping them on every
  continuation rather than trusting the client (`AuditQueryService.cls:84-93`).
  A custom range still sends explicit bounds, with a blank "To" sent as null
  so the server supplies now. Pinned by `lastDaysUsesServerClockAndPinsRange`,
  `lastDaysIsCappedAtTheRetentionWindow`, `lastDaysZeroMeansExplicitDatesApply`,
  `negativeLastDaysMeansExplicitDatesApply`,
  `continuationBoundsAreReclampedFromAnUntrustedCursor` and the Jest test
  "sends lastDays and no explicit bounds for a preset range".

### 3.11 "Search further back" re-reads live filters but continues the old cursor

- `auditExplorer.js:160-162` calls `runSearch(false)`; `buildFilter()` at
  line 200 runs on every call, filter inputs are never disabled
  (`auditExplorer.html:17-42,93-102`), and only a new search resets rows and
  cursor (`js:189-198`). Editing the text or section and clicking "Search
  further back" appends rows matching the new filter under rows from the old
  one; count, facets (`js:248-249`), progress text and the CSV export then
  describe two filters. Because `now` is re-evaluated (`js:129,137`), the
  lower bound also creeps forward between pages.
- **Fix (code):** snapshot the filter when a new search starts and reuse it
  for every load-more; disable or re-label the button when any input changes;
  add a Jest test that the second call's `filterJson` equals the first.
- **Resolved in 1.0.1** (`47bd65f`, shipped in `1.0.1.4`): the filter is
  snapshotted as `activeFilterJson` when a new search starts and every
  "Search further back" call reuses it verbatim (`auditExplorer.js:252-273`);
  any edit sets `filtersDirty` and shows "Filters changed. Click Search to
  apply them; Search further back continues the current search."
  (`auditExplorer.html:127-129`), and the lower bound cannot creep because
  the range is pinned server-side (3.10). The Jest test "reuses the filter of
  the running search" asserts the second call's `filterJson` equals the
  first's; the behaviour was also seen in `ate-101` on 2026-10-12.

### 3.12 Removing a selected user pill does nothing

- `auditExplorer.js:326-329` reads `event.detail.name`; `lightning-pill-container`'s
  `itemremove` event carries `detail.item` and `detail.index`, so `id` is
  `undefined` and the filter keeps every user. The only way to drop a user is
  Reset, which clears every filter. Jest stubs the pill container and
  `docs/LIVE-ORG-VALIDATION.md:358` only records adding a user, never removing
  one.
- **Why it matters:** first thing a reviewer or customer who adds then removes
  a user filter will hit. Not a security item (verified medium; the original
  report rated it high).
- **Fix (code):** `const id = event.detail.item && event.detail.item.name;`
  with an index fallback, plus a Jest test dispatching
  `new CustomEvent('itemremove', { detail: { item: { name }, index: 0 } })`.
  Verify in an org by clicking the X on a user pill before building.
- **Resolved in 1.0.1** (`47bd65f`, shipped in `1.0.1.4`):
  `handleUserRemove` reads `event.detail.item.name` with a fallback to the
  pill at `detail.index` (`auditExplorer.js:411-421`); Jest dispatches
  `itemremove` with `{ item: { name }, index: 0 }` and with `{ index: 0 }`
  alone and checks that the next search drops the user. Clicking the pill's x
  in `ate-101` on 2026-10-12 removed the pill.

### 3.13 Solution Doc pins the wrong Code Analyzer version

- `docs/SECURITY-REVIEW-SOLUTION-DOC.md:164` says plugin 5.15.0; the
  authoritative latest run is 5.16.0 (`docs/CODE-ANALYZER-SCAN-RECORD.md:167`),
  identical rule for rule. Low on its own, listed here because the Solution
  Doc is uploaded with the submission.
- **Fix:** "5.15.0 (2026-09-10) and 5.16.0 (2026-09-19), identical rule set
  and results; see CODE-ANALYZER-SCAN-RECORD.md", and add the official-selector
  run from section 2.2 once it exists.
- **Resolved** by the 2026-10-11 documentation pass (`c484205`); the
  official-selector runs are in section 2.2.

### Decision on code changes before submission

Taken 2026-10-12: option (a). Salesforce asks partners to submit the exact
version they will distribute and, after a failed review, to "fix only the
security issues discovered", so the code fixes could not have followed a
submitted `1.0.0.2` without a fresh initial review. `1.0.1` was built from
the fixes above and is the version to submit, so the known user-visible
defect (3.12) is not the reviewer's first impression. The alternative, (b),
would have submitted `1.0.0.2` as is and shipped the fixes as the first
post-review version with `1.0.0.2` as ancestor.

What was built: four versions on 2026-10-12 from Dev Hub `00Dhm000004MOXjEAO`,
each with 96% coverage and `HasPassedCodeCoverageCheck` `true`. `1.0.1.1`
(`04thm000002tVurAAE`, from `47bd65f`), `1.0.1.2` (`04thm000002tVwTAAU`, from
`41e2a29`) and `1.0.1.3` (`04thm000002tVy5AAE`, from `f05ed25`) are
superseded betas, never promoted: their Graph Engine runs did not finish
cleanly (one false-positive null-pointer finding, then per-path timeouts
caused by the extra conditionals the new code had placed on the search path),
each fixed by the next commit. `1.0.1.4` (`04thm000002tWirAAE`, from
`f0ad675`) is the release: `sf package version promote` succeeded on
2026-10-12 and `sf package version report` shows Released `true`, Ancestor
Version `1.0.0.2`. Install URL
<https://login.salesforce.com/packaging/installPackage.apexp?p0=04thm000002tWirAAE>
(sandbox: `test.salesforce.com`); CLI
`sf package install --package 04thm000002tWirAAE --target-org my-org --wait 20`,
then
`sf org assign permset --name atexplorer__Audit_Trail_Viewer --target-org my-org`.

Validation of the released source (ids in section 1):

- Apex: 50 tests (was 29). Source deploy of `f0ad675` into the namespaced
  scratch org `ate-101`, `0Afh1000000NfiTCAS`, 50 run / 0 failed; managed
  `1.0.1.4` in the clean scratch org `ate-mgd` (install request
  `0Hfdi000002FyKTCA0`, an upgrade from `1.0.1.3`), `RunAllTestsInOrg` run
  `707di0000LCKGo0`, 50 passed / 0 failed. The installed
  `atexplorer__Audit_Trail_Viewer` again shows `PermissionsViewSetup=false`
  and `PermissionsViewRoles=false`, so the two-grant model is unchanged.
- LWC: Jest 26 tests (was 7); `npm run lint` and `npm run prettier:verify`
  clean; `auditExplorer.js` 95.16% statements, `csv.js` 100%.
- Code Analyzer on `f0ad675`: official command 62 rules, "Found 0
  violations." (report SHA-256 `03E6CE52...`, section 2.2); three-tag union
  310 rules, 0 Critical / 0 High / 13 Moderate / 106 Low, none Security- or
  AppExchange-tagged; Graph Engine alone 6,537 paths from 3/3 entry points,
  0 violations from the two Security rules.
- Manual UI check on 2026-10-12 (no screenshots kept): in `ate-101` as the
  administrator, the type-ahead, adding and removing a user pill, the
  "Filters changed" hint, "Search further back" continuing the original
  search while a pending term was not applied, and Enter applying it; in
  `ate-mgd`, a Minimum Access user holding only
  `atexplorer__Audit_Trail_Viewer` sees the denied message with no form and
  Export disabled, and sees data once a local permission set granting View
  Setup and View Roles is assigned.

Still true: do not create another version while a review is pending (section
5, step 17).

## 4. Known and accepted

Confirmed low and info items. None affects the review outcome. Most
documentation rows were applied on 2026-10-11 with section 3. The code rows
whose Disposition now starts "Fixed in 1.0.1" shipped in `1.0.1.4`; the
wording that waited on that decision (the error policy, "never cached", the
cursor guarantees, "pinned by tests", the permission set description and 2GP
ancestry) can now be stated as true of the `1.0.1` code. The remaining code
rows were deliberately left alone and stay accepted: SLDS hardcoded values
(22 scan hits after the new CSS), the type-ahead's listbox / live-region
semantics, browser-time-zone formatting in the detail panel and progress
text, the auto-search on connect, the permission set's `ViewSetup`/`ViewRoles`
entries (kept for source deploys), the publisher org ids, the unpinned CI
tool versions and the absent Jest `coverageThreshold`. The table keeps every
row as found, with the Disposition cell updated where `1.0.1` changed it.

| Item                                                                                                                   | Where                                                                                | Disposition                                                                                                                                                                                                                                                                           |
| ---------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| "Every Apex class ... declared `with sharing`" is false for the four test classes and the interface                    | `docs/SECURITY-REVIEW-SOLUTION-DOC.md:95`, `CONTRIBUTING.md:56`                      | Reword to "every production class and inner class"; interface cannot carry one                                                                                                                                                                                                        |
| "Every `@AuraEnabled` method calls this gate" contradicts the doc's own table ("Not gated, by design")                 | `SOLUTION-DOC.md:66` vs `:72`; `docs/ARCHITECTURE.md:9-10`                           | Reword to "both data-returning methods"; `getContext` is intentionally ungated and discloses nothing                                                                                                                                                                                  |
| Controller denial test asserts only the exception type; line 31 builds the permission error without `setMessage()`     | `AuditPermissionServiceTest.cls:64`, `AuditQueryController.cls:31,40-42`             | Fixed in 1.0.1: `permissionFailure()` calls `setMessage` (`AuditQueryController.cls:101-107`); `blocksControllerEntryPointsForUnprivilegedUser` asserts the message names View Setup and Configuration for both entry points                                                          |
| `searchText` term count is unbounded; CPU `LimitException` is uncatchable so "every other exception" is overstated     | `AuditQueryService.cls:182,208-212`                                                  | Fixed in 1.0.1: capped at 200 characters and 10 terms (`AuditQueryService.cls:47-48,266-270`), pinned by `searchTextHonoursOnlyTheFirstTenTerms` and `searchTextIsTruncatedToTwoHundredCharacters`; the "every other catchable exception" wording is a documentation edit             |
| PRIVACY.md says CSV escaping alters no data; `csv.js` prepends an apostrophe to triggered cells                        | `docs/PRIVACY.md:50-52`, `csv.js:44-47`                                              | Reword PRIVACY.md to name the apostrophe prefix as the only modification                                                                                                                                                                                                              |
| Server ships fields the UI never renders (`CreatedById`, `CreatedByContext`, `CreatedByIssuer`, facets, `nowMillis`)   | `SetupAuditTrailProvider.cls:18-19`, `AuditEventRow.cls:47-48`                       | Trim the SELECT/DTO or render them; list every selected field (incl. `DelegateUser`) in PRIVACY.md                                                                                                                                                                                    |
| Object URL revoked synchronously after `click()`; `setTimeout` deferral is barred by lint                              | `auditExplorer.js:376-381`                                                           | Fixed in 1.0.1: the URL is kept in `lastExportUrl` and revoked on the next export or in `disconnectedCallback` (`auditExplorer.js:94,112-114,484-489`); Jest "prefixes the BOM and defers revoking the object URL"                                                                    |
| CSV has no UTF-8 BOM; older Excel on Windows shows mojibake for non-ASCII names                                        | `auditExplorer.js:376`                                                               | Fixed in 1.0.1: `UTF8_BOM` is prepended (`auditExplorer.js:46,471`); the first cell is still the quoted header `"Date"`, so the formula guard is unaffected                                                                                                                           |
| 18 hardcoded colours/sizes do not follow SLDS 2 themes; detail panel can lose contrast in dark mode                    | `auditExplorer.css:3,7,13,23,47,59`                                                  | Wrap in `var(--slds-g-*, fallback)`; clears all 18 scan hits                                                                                                                                                                                                                          |
| Loading indicator is a 100% progress bar; type-ahead list has no live-region or combobox semantics                     | `auditExplorer.html:148-150,43-57`                                                   | Partly fixed in 1.0.1: a `lightning-spinner` replaces the progress bar (`auditExplorer.html:155-157,259-261`); the listbox / live-region semantics are unchanged and accepted                                                                                                         |
| Jest never exercises `handleExport`, the type-ahead, the 25-call cap, Stop, or the cursor round-trip                   | `__tests__/auditExplorer.test.js:242`; `jest.config.js:3-16` (no threshold)          | Partly fixed in 1.0.1: Jest now covers all five (26 tests: the "CSV export", "user type-ahead" and "search loop bounds" groups, and the cursor echo assertion in the progressive-search test); no `coverageThreshold` was added (accepted)                                            |
| Type-ahead fires per keystroke with no stale-response guard                                                            | `auditExplorer.js:300-314`                                                           | Fixed in 1.0.1: the term is captured in the closure and a response for a superseded term is dropped; failures are surfaced (`auditExplorer.js:374-398`); Jest "drops a stale response that arrives after the term changed"                                                            |
| Detail date, progress text and retention date use the browser time zone; the table uses the Salesforce user's          | `auditExplorer.js:352,406-408,419`                                                   | Format with `@salesforce/i18n/timeZone` and `locale`                                                                                                                                                                                                                                  |
| "Today" preset is a rolling 24 hours, not a calendar day                                                               | `auditExplorer.js:31,137`                                                            | Fixed in 1.0.1: relabelled "Last 24 hours" (`auditExplorer.js:33`); the range itself is now resolved on the server (3.10)                                                                                                                                                             |
| Disposition doc gives the rule count as 295 in one place and 310 everywhere else                                       | `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md:85` vs `:33`                           | Stale pre-Security-tag number; change to "three flags ... 310 rules"                                                                                                                                                                                                                  |
| LIKE-wildcard escaping in `searchUsers` has no test                                                                    | `AuditQueryController.cls:76`                                                        | Fixed in 1.0.1: `searchUsersTreatsPercentAsLiteral`, `searchUsersTreatsUnderscoreAsLiteral` and `searchUsersTreatsEscapedPercentAsLiteral` (`AuditQueryControllerTest.cls:196-250`), run against an inserted user with a distinctive last name                                        |
| `permissionCheckRunsRealQuery` runs no query and asserts a non-nullable Boolean; page-size clamp untested              | `AuditQueryControllerTest.cls:108-114`, `AuditQueryService.cls:138`                  | Fixed in 1.0.1: replaced by `pageSizeIsClampedToTheMaximumAndDefaulted` (999 clamps to 200; null and 0 fall back to the default); `contextExposesRetentionWindow` now asserts `canViewSetup` is `true`                                                                                |
| runAs tests depend on the English profile name and a spare licence; 8 tests assume the runner holds `ViewSetup`        | `AuditPermissionServiceTest.cls:13`                                                  | Select the profile by `UserLicense.Name`; document in CONTRIBUTING.md                                                                                                                                                                                                                 |
| Mock provider does not sort, though its comment says "descending"                                                      | `MockAuditTrailProvider.cls:10,23-43`                                                | Fixed in 1.0.1: sorted (`CreatedDate DESC, Id DESC`) in the constructor and implements the keyset exclusion (`MockAuditTrailProvider.cls:7-11,59-66`)                                                                                                                                 |
| CHANGELOG initial-unlocked entry credits that release with the 2026-09-10 scan and a 28-test count (was 22)            | `CHANGELOG.md:173-180`, `docs/LIVE-ORG-VALIDATION.md:107`                            | Move the scan bullet to the managed entry; state counts per version                                                                                                                                                                                                                   |
| CHANGELOG has two `[1.0.0]` headings sharing one link, no Unreleased section, stale bullets contradicting the preamble | `CHANGELOG.md:10,156,184,144-149,51-53`                                              | Rename the unlocked heading; add `[Unreleased]`; mark historical bullets as superseded                                                                                                                                                                                                |
| No 2GP ancestor and version not bumped past the released `1.0.0.2`                                                     | `sfdx-project.json:4-5`                                                              | Done for 1.0.1: `versionNumber` `1.0.1.NEXT`, `ancestorVersion` `HIGHEST` (`sfdx-project.json:4-6`); `1.0.1.4` reports Ancestor Version `1.0.0.2`                                                                                                                                     |
| Packaged permission set declares `ViewSetup`/`ViewRoles` that managed install strips                                   | `Audit_Trail_Viewer.permissionset-meta.xml:31-38`                                    | Design choice, kept; disclosed at `SOLUTION-DOC.md:74-87`. The description now leads with what managed subscribers get and says the install strips the two permissions (1.0.1, `Audit_Trail_Viewer.permissionset-meta.xml:4-5`); the strip was re-confirmed on `1.0.1.4` in `ate-mgd` |
| Shipped tests query `PermissionSet`/`ApexClass` by bare Name and insert a User                                         | `AuditPermissionServiceTest.cls:102-107,149-153,30`                                  | Partly fixed in 1.0.1: both lookups filter by `NamespacePrefix` (`AuditPermissionServiceTest.cls:218,251,269`); the User inserts remain, without a licence guard                                                                                                                      |
| Publisher org ids (Dev Hub/PBO, NamespaceRegistry, persistent DE org) in a public repo                                 | `docs/LIVE-ORG-VALIDATION.md:19,201-202,309,331`                                     | Not credentials; optional redaction (line 205-207 would need rewording)                                                                                                                                                                                                               |
| Workflows have no `permissions:` block; actions tag-pinned; CLI and plugin installed unpinned                          | `.github/workflows/ci.yml:18`, `.github/workflows/code-analyzer.yml:24,56-57`        | Add `permissions: contents: read`; pin versions from the scan record                                                                                                                                                                                                                  |
| README Layout table lists 4 of 14 classes and Uninstall points at it                                                   | `README.md:171-177,155-156`                                                          | Point Uninstall at the `sf project delete source` command only                                                                                                                                                                                                                        |
| CONTRIBUTING scratch-org command fails for any Dev Hub without the namespace                                           | `CONTRIBUTING.md:24`                                                                 | Add `--no-namespace`                                                                                                                                                                                                                                                                  |
| CHANGELOG says CI runs `test:unit`; it runs `test:unit:coverage`                                                       | `CHANGELOG.md:48-50`, `docs/LIVE-ORG-VALIDATION.md:275`                              | One-word fix                                                                                                                                                                                                                                                                          |
| Uninstall step names the un-namespaced permission set for the packaged install                                         | `README.md:152`                                                                      | Use `atexplorer__Audit_Trail_Viewer`                                                                                                                                                                                                                                                  |
| "Planned opt-in add-on" for >180-day retention is unsupported by anything in the repo                                  | `README.md:64-66` vs `docs/ARCHITECTURE.md:83-85`                                    | Align with ARCHITECTURE's conditional wording                                                                                                                                                                                                                                         |
| ">85% target" for LWC coverage is defined nowhere                                                                      | `docs/LIVE-ORG-VALIDATION.md:296`                                                    | Add `coverageThreshold` or reword                                                                                                                                                                                                                                                     |
| Stale checklist item: README already references the install URL                                                        | `docs/LIVE-ORG-VALIDATION.md:405-407`                                                | Reword to "add the listing URL and review status"                                                                                                                                                                                                                                     |
| Listing draft advertises an "action" filter the UI does not expose                                                     | `docs/APPEXCHANGE-LISTING.md:44-45`, `auditExplorer.js:148`                          | Drop "action" or add the control (Apex already binds it)                                                                                                                                                                                                                              |
| "122 records over 18 pages" paging claim has no recorded evidence                                                      | `SOLUTION-DOC.md:154-155,226`, `ARCHITECTURE.md:77`, `LIVE-ORG-VALIDATION.md:369`    | Record org/date/script or point to the evidenced 118-row run                                                                                                                                                                                                                          |
| Free-text search matches the literal word "null" against blank fields                                                  | `AuditQueryService.cls:199-206`                                                      | Fixed in 1.0.1: null fields are dropped through a set before the haystack is joined (`AuditQueryService.cls:286-289`); `blankFieldDoesNotMatchTheWordNull`                                                                                                                            |
| `canViewSetup` defaults to `true`; form renders before `getContext` resolves and after it rejects; Export outside gate | `auditExplorer.js:69,77-89`, `auditExplorer.html:3-13`                               | Fixed in 1.0.1: `canViewSetup` is tri-state (spinner until `getContext` answers, denied on `false`, error only on rejection; `auditExplorer.js:83,118-132`, `auditExplorer.html:14,258-280`); Export is enabled only with rows and confirmed access (`auditExplorer.js:534-536`)      |
| `jest.config.js` comment and validation record describe a "coverage gate" that does not exist                          | `jest.config.js:10-11`, `docs/LIVE-ORG-VALIDATION.md:280-282`                        | Add a threshold or say "coverage step"                                                                                                                                                                                                                                                |
| ARCHITECTURE says facets are computed in Apex over scanned rows; the browser recomputes over matched rows              | `docs/ARCHITECTURE.md:91-94`, `auditExplorer.js:242-249`, `AuditSearchResult.cls:25` | Correct the doc; drop or document the unused server facets                                                                                                                                                                                                                            |
| `searchUsersFindsActiveUsers` fails for a running user with a one-character surname                                    | `AuditQueryControllerTest.cls:97-105`                                                | Fixed in 1.0.1: inserts a user with last name `Aazyxwvutsrq` and searches that term (`AuditQueryControllerTest.cls:10-26,178-194`)                                                                                                                                                    |
| Info: CSV guard omits NFKC variants, DEL/C1, ZWNJ/ZWJ; Jest lacks a CR and a negative pipe case                        | `csv.js:25,36`                                                                       | Optional: test against `normalize('NFKC')`; add two Jest cases                                                                                                                                                                                                                        |
| Info: `AuditCursor.consume` dereferences `seenIdsAtLastDate` without a null guard (masked by the catch-all)            | `AuditCursor.cls:38`                                                                 | Moot in 1.0.1: `seenIdsAtLastDate` no longer exists; the cursor carries a single `lastId` and `lastIdValue()` validates it (`AuditCursor.cls:24,53-65`)                                                                                                                               |
| Info: ARCHITECTURE calls the cursor "opaque"; it is plain client-modifiable JSON, treated as untrusted                 | `docs/ARCHITECTURE.md:62`                                                            | Reword to "plain JSON cursor treated as untrusted input"                                                                                                                                                                                                                              |
| Info: the single `eslint-disable` (`no-await-in-loop`) is live, scoped and justified                                   | `auditExplorer.js:216`                                                               | Accept; disposition at `FINDINGS-DISPOSITION.md:136-146` is accurate. 1.0.1 adds a second, in the Jest helper `settle()`, for the same rule and the same reason (sequential cursor-driven calls)                                                                                      |
| Info: component auto-searches on every connect, including on Home pages (one bounded call per mount)                   | `auditExplorer.js:83`, `auditExplorer.js-meta.xml:8-10`                              | Optional `targetConfigs` switch                                                                                                                                                                                                                                                       |
| Info: completed searches report "back to <oldest row>" rather than the range boundary covered                          | `AuditQueryService.cls:87,121-123`                                                   | Fixed in 1.0.1: `scannedThroughMillis` is set to the lower bound once the range is exhausted (`AuditQueryService.cls:169-176`); `exhaustedScanReportsRangeBoundary`, `exhaustedScanWithRowsReportsRangeBoundaryNotOldestRow`                                                          |
| Info: `System.debug` content is clean; "logged for the administrator" should be qualified for managed packages         | `AuditQueryController.cls:38`, `FINDINGS-DISPOSITION.md:181`                         | Qualify the wording                                                                                                                                                                                                                                                                   |
| Info: malformed verification command in a YAML comment (stray `#`)                                                     | `code-analyzer.yml:66`                                                               | Split into two comment lines                                                                                                                                                                                                                                                          |
| Info: husky/lint-staged configured but no `.husky/pre-commit` is tracked                                               | `package.json:16-17`                                                                 | Commit the hook or remove the tooling; CI enforces the same gates                                                                                                                                                                                                                     |
| Info: "no DML of any kind" is false for the packaged test classes                                                      | `docs/SECURITY-REVIEW-SOLUTION-DOC.md:46`, `AuditPermissionServiceTest.cls:30,108`   | Scope to runtime code                                                                                                                                                                                                                                                                 |

## 5. Submission runbook

End to end, from today's state to a published listing. Steps marked [Owner]
need the Partner Console, legal or payment access; steps marked [Repo] can
be prepared from the repository and CLI. Steps 7-10 are done (9 on
2026-10-11; 7, 8 and 10 for `1.0.1.4` on 2026-10-12, with Dev Hub
`partner-pbo` and the two scratch orgs in section 1); the Partner Console
steps and the DE org remain for the owner's session. Steps 1-5 can proceed
in parallel.

1. **[Owner] Confirm ISV Partner Program enrollment and the distribution
   agreement.** Have a partner recruitment representative confirm both; a
   signed PADA with pricing model Free must exist before Start Review. Ensure
   your Partner Community user has the Manage Listings permission. Nothing in
   the repository records this; the Dev Hub alias `partner-pbo`
   (`docs/LIVE-ORG-VALIDATION.md:19`) suggests a PBO exists.
   <https://developer.salesforce.com/docs/platform/isvforce/guide/security-review-submit-solution.html>

2. **[Owner] Complete Company Info and designate contacts.** Company
   profile, the four internal contacts (Business, Marketing, Technical,
   Security Review) and the security leadership contacts the console
   re-confirms every six months. All review status emails go to the security
   review contact; use a monitored address (not a generic `security@`).
   <https://developer.salesforce.com/docs/platform/isvforce/guide/appexchange-designate-contacts.html>

3. **[Owner] Connect the PBO and the packaging Dev Hub to the Partner
   Console.** Publishing > Technologies > Solutions > Connect Technology >
   Connect Org, once with the PBO/LMA org and once with Dev Hub
   `00Dhm000004MOXjEAO`. Afterwards version `1.0.1.4` appears under Solutions
   with listing readiness "Security Review Required".
   <https://developer.salesforce.com/docs/platform/pkg2-dev/guide/sfdx-dev-dev2gp-publish-appexchange.html>

4. **[Owner, optional] Register the package with the LMA.** Solutions >
   Register Package > log in to the LMA org > default license Active,
   Site-wide. Optional for a Free listing (required only for Checkout); gives
   install telemetry and the Subscriber Support Console.
   <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/appexchange_publish_manage.htm>

5. **[Owner] Create the draft listing, price it Free, link version 1.0.1.4
   (`04thm000002tWirAAE`), attest Lightning Ready and the Security
   Requirements.** Listings > New
   Listing; copy from `docs/APPEXCHANGE-LISTING.md` plus the gaps in section 7. Linking the version is a hard prerequisite for Checkmarx. The app is
   LWC-only (`auditExplorer.js-meta.xml:7-11`), so Lightning Ready holds.
   <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/appexchange_link_solution.htm>

6. **[Owner] Run the Checkmarx Source Code Scanner.** Partner Security Portal
   `https://security.my.salesforce-sites.com/sourcescanner/`, logged in as the
   Dev Hub System Administrator (needs Author Apex; that email must be invited
   to the publisher account with the Listings permission). Scan `1.0.1.4`,
   export the report, and add any findings to the false-positive
   document. Three scans per review. If login fails, the documented fallback
   is a Partner Community case titled "Partner Security Portal Issue".
   <https://security.my.salesforce-sites.com/sourcescanner/SourceScannerHelp>

7. **[Repo] Verify the source matches the shipped version and tag it.**
   Done for `1.0.1.4` on 2026-10-12: it was built from `f0ad675`, and
   `force-app` has not changed since (the one later commit, `37c2ad9`,
   records the version alias and the Graph Engine path pin). The maintainer
   tags `v1.0.1` on the final commit of this documentation pass, so the tag
   will resolve to a commit whose `force-app` equals `f0ad675`'s
   (<https://github.com/muraliseelam/sf-audittrail-app/releases/tag/v1.0.1>
   once pushed).

    ```bash
    git diff --stat f0ad675..HEAD -- force-app     # must be empty (it is today)
    git diff --stat f0ad675..v1.0.1 -- force-app   # must be empty once tagged
    ```

    The scan in step 8 must run from source identical to that commit, because
    Salesforce requires the code to match the package. For `1.0.0.2` the
    equivalent anchors were tag `v1.0.0`, commit `934f200`.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_code_analyzer_scan.htm>

8. **[Repo] Generate `CodeAnalyzerReport.html` with the official command.**
   Done for `1.0.1.4` on 2026-10-12: from the release worktree at `f0ad675`,
   after `npm ci`, the selector resolved to 62 rules from 5 engines and the
   run exited 0 with "Found 0 violations." (HTML kept outside the repository,
   SHA-256 `03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`,
   64,954 bytes; section 2.2). The 2026-10-11 run for `1.0.0.2` from `934f200`
   (SHA-256 `5C05B155...`) is superseded. The commands, kept for
   reproducibility:

    ```bash
    sf code-analyzer rules --rule-selector AppExchange --rule-selector Recommended:Security
    sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security --output-file CodeAnalyzerReport.html
    ```

    Run from the package's top-level directory of a checkout whose
    `force-app` equals `f0ad675`'s. Confirm the rule count is greater than
    zero before trusting the result. Two gotchas, both environment errors
    rather than code findings, and both visible as a Critical
    `UninstantiableEngineError` in the report: the `flow` engine requires
    Python 3.10+ ("could not be instantiated ... Could not locate a Python
    v3.10.0+ install"; this workstation lacked it until 2026-10-11, GitHub's
    `ubuntu-latest` runner has it); and since commit `5c70c8c` the
    repository's `code-analyzer.yml`, which the CLI auto-loads from the
    current directory, sets `eslint_config_file: eslint.config.js`, so
    without `node_modules` the `eslint` engine fails with "Cannot find module
    'eslint/config'" (verified on a pristine checkout of `47bd65f`: 59 rules
    from 4 engines and that one engine error). Run `npm ci` first. Either
    error makes a `--severity-threshold 2` run exit 1.
    Keep the three-tag scan and the Graph Engine run as supporting evidence:

    ```bash
    sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
      --rule-selector Recommended --rule-selector Security --rule-selector AppExchange \
      --output-file CodeAnalyzerReport-union.html --output-file ca-report.json
    sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
      --rule-selector sfge --output-file ca-sfge.json
    ```

    On `f0ad675` these gave 119 violations (0 Critical / 0 High) and
    "analyzed 6537 path(s) from 3 entry point(s)" with 0 violations from the
    two Security rules (section 1); the Graph Engine run takes about 13
    minutes on an idle host at the committed 1,800,000 ms per-path budget,
    and CI fails unless the log shows the full 6537-path count. Record the
    run (plugin version, rule count, result) in
    `docs/CODE-ANALYZER-SCAN-RECORD.md`. Store the HTML outside the repo; it
    is gitignored and the CI copy expires 30 days after each run.
    <https://developer.salesforce.com/docs/platform/salesforce-code-analyzer/guide/appexchange.html>

9. **[Repo] Apply the documentation fixes** in sections 3.1, 3.2, 3.3,
   3.9, 3.13 and the one-line rows of section 4, then run:

    ```powershell
    $env:Path=[Environment]::GetEnvironmentVariable('Path','Machine')+';'+[Environment]::GetEnvironmentVariable('Path','User')
    npm run lint; npm run prettier:verify; npm run test:unit:coverage
    ```

10. **[Owner decides, Repo implements] Decide whether to ship the code
    fixes before submission.** Decided 2026-10-12: option (a), recorded at
    the end of section 3. Done: 3.4-3.8 and 3.10-3.12 fixed (`47bd65f` and
    its follow-ups); `sfdx-project.json` carries `versionNumber` `1.0.1.NEXT`
    and `"ancestorVersion": "HIGHEST"`; four versions built with
    `sf package version create` and code coverage (96% each), the last of
    them promoted:

    ```bash
    sf package version promote --package 04thm000002tWirAAE --target-dev-hub partner-pbo   # 2026-10-12: Released = true
    ```

    `1.0.1.4` reports Ancestor Version `1.0.0.2`. Validated as the end of
    section 3 summarises: source deploy with tests in `ate-101`, managed
    install and `RunAllTestsInOrg` in `ate-mgd`, the local gates, and Code
    Analyzer (steps 7-8 redone for `f0ad675`). Still open for the new
    version: the DE org reinstall (step 12) and the Partner Console steps 5-6.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_listing_readiness.htm>

11. **[Repo drafts, Owner signs] Prepare the upload set.** Export to PDF
    or DOCX: `docs/SECURITY-REVIEW-SOLUTION-DOC.md` (architecture, data
    handling, authorisation, injection defences, third-party = none at lines
    157-160), `docs/ARCHITECTURE.md`, `docs/PRIVACY.md`, the usage/reviewer
    guide (new), `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md` extended with
    the Checkmarx dispositions, the one-page security program statement
    (new), and a one-line statement that DAST does not apply because the
    package has no external endpoint (`SOLUTION-DOC.md:45`).
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_false_positives.htm>

    **Done on 2026-10-13 [Repo], except the Checkmarx part:** the DAST
    statement is `docs/DAST-STATEMENT.md`, and PDFs of the six documents and
    that statement, plus the official `CodeAnalyzerReport.html` for the
    `1.0.1.4` source, are in the maintainer's `submission-upload-set-2026-10-13`
    folder, kept outside the repository like the scan reports, with a
    `MANIFEST.md` that maps each file to its wizard upload. The security
    program statement PDF is a draft until the publisher fields are filled
    in and it is signed. Regenerate the false-positive PDF once the
    Checkmarx findings from step 6 are dispositioned.

12. **[Owner] Prepare the reviewer test environment.** In Developer Edition
    `00Dbm00000u2XaoEAE` (holds `04thm000002OtQPAA0`, `1.0.0.2`): first
    upgrade it to `1.0.1.4` with
    <https://login.salesforce.com/packaging/installPackage.apexp?p0=04thm000002tWirAAE>
    or `sf package install --package 04thm000002tWirAAE --target-org <alias> --wait 20`
    (the version installed here must be the one the listing links, scans and
    submits), then create
    a reviewer user holding `atexplorer__Audit_Trail_Viewer` plus a local
    permission set granting View Setup and Configuration (and View Roles),
    and a second user holding only `atexplorer__Audit_Trail_Viewer` so the
    gate can be seen closing; seed some setup changes so results are
    non-empty; keep the passwords valid for the whole review window; never
    commit them. Check the org's Setup Audit Trail for anything you would not
    want a reviewer to read.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_how_it_works.htm>

13. **[Owner, optional] Generate the solution-specific checklist** with the
    Security Review Submission Requirements Checklist Builder in the Partner
    Community (login required; returned HTTP 401 during research).
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_required_materials.htm>

14. **[Owner] Start Review in the wizard.** Publishing > Technologies >
    Solutions > solution name > Start Review. Contacts; Technical Details
    (managed package only; no external endpoints, callouts, data storage,
    Connected App, Flow connector or Agentforce component, so no DAST
    report); Documentation uploads (Code Analyzer HTML, Checkmarx report,
    false-positive document, solution/usage docs, security policy);
    Environments (DE org username/password, verified at entry); Review and
    Submit; Payment (should show no charge for a Free solution).
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_submit_solution.htm>

15. **[Owner] Book technical office hours immediately after submitting**, on
    the Partner Security Portal, 3-4 weeks out. Salesforce recommends this
    because slots are in demand and a failed result then already has a
    follow-up booked.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_submit_solution.htm>

16. **[Owner] Track the stages and answer any "Returned" status promptly.**
    Prepare and Submit > Submission Verification (1-2 weeks; incomplete
    materials cause "Returned", free to resubmit) > Testing (3-4 weeks) >
    Done. Status is under Solutions > Check Status; emails go to the security
    review contact. Verification feedback can be disputed free of charge.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_stages.htm>

17. **[Both] Do not create another package version while the review is
    pending.** Salesforce: "wait until it passes before you create more
    versions. Build new package versions by using the version that passed as
    a direct ancestor." The ancestry is already in place: `sfdx-project.json:6`
    carries `"ancestorVersion": "HIGHEST"`, set for the `1.0.1` build (where
    it resolved to `1.0.0.2`); Salesforce resolves `HIGHEST` to the highest
    released version, now `1.0.1.4`. Before the first post-review build
    the only change needed is to bump `versionNumber` past `1.0.1.NEXT`; submit only
    major and minor versions, not patches.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_listing_readiness.htm>

18. **[Both] If Failed:** fix only the reported security items in the same
    package id and namespace, rescan, build a new version with `1.0.1.4` as
    ancestor, resubmit (follow-up testing 2-3 weeks; no fee for a Free
    solution). False-positive-only disputes are added to the failed review
    at no cost. Functional changes bundled in force a fresh initial review.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_submit_followup.htm>

19. **[Owner] If Passed:** complete the listing's own review step (brand
    guidelines, program policies), sign whatever agreement the console
    requires for a Free non-Checkout listing (section 9), set installation
    method "Install from your AppExchange listing", set a lead org that is a
    standard org with Web-to-Lead on and reCAPTCHA off, then Publish; the
    listing is live about 30 minutes later.
    <https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/appexchange_listing_approvals.htm>

20. **[Repo, only after Passed] Update the repository claims.** `README.md:6-12,74-78,212-214`,
    `CHANGELOG.md:16-18`, `docs/APPEXCHANGE-LISTING.md:8-16`,
    `docs/LIVE-ORG-VALIDATION.md:403-418` and `docs/CODE-ANALYZER-SCAN-RECORD.md:11-14`
    currently say the package is not reviewed and not listed, which is
    correct today. Change them only when the outcome is recorded, and
    describe it in the words Salesforce uses for the result.

21. **[Owner] Keep the listing alive.** Periodic re-reviews are risk-based
    (Trailhead says typically yearly), notified to the security review
    contact, take up to 6 weeks, with a typical 60-day remediation window on
    failure; a missed re-review expires the result for all versions and
    removes the listing. Fees for re-review are waived while the listing
    stays Free.
    <https://developer.salesforce.com/docs/platform/isvforce/guide/security-review-periodic-reviews.html>

## 6. Artifact checklist

| Artifact                                                       | What reviewers expect                                                                             | Where it is in this repo                                                                                                                                                                                                                                                                                                                                                                                                        | Action                                                                      |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------- |
| Managed-Released package version                               | Not beta, not unmanaged; same version installed, linked, scanned and submitted                    | `1.0.1.4` / `04thm000002tWirAAE`, Released `true` (promoted 2026-10-12, Ancestor Version `1.0.0.2`; `sfdx-project.json:27`); scanned from its source commit `f0ad675` (section 2.2); linking it and the Checkmarx scan are owner steps 5-6                                                                                                                                                                                      | None                                                                        |
| Developer Edition test org with the version installed          | Reviewers pen-test it; login verified at submission                                               | `00Dbm00000u2XaoEAE` holds `1.0.0.2` (`LIVE-ORG-VALIDATION.md:301-317`); no install of `1.0.1.4` there is recorded; no reviewer users or instructions                                                                                                                                                                                                                                                                           | Owner: step 12 (upgrade to `1.0.1.4` first)                                 |
| `CodeAnalyzerReport.html` from the official command            | CLI-generated, official selector, code matching the version                                       | Present, outside the repository (gitignored, `.gitignore:55`): regenerated 2026-10-12 from `f0ad675` (the source of `1.0.1.4`) with the official command after `npm ci`, 62 rules, 0 violations, SHA-256 `03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`, 64,954 bytes (section 2.2); the 2026-10-11 report for `1.0.0.2` is superseded. Three-tag union and Graph Engine runs on the same commit: section 1 | None; regenerate only if source changes                                     |
| Checkmarx / Source Code Scanner report                         | Mandatory for any submission containing a Salesforce package (per materials table and portal FAQ) | MISSING (no mention anywhere)                                                                                                                                                                                                                                                                                                                                                                                                   | Owner: step 6                                                               |
| False-positive document                                        | One row per flagged finding explaining why it is not exploitable                                  | Partial: `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md` (Code Analyzer only; see 3.2 for a false paragraph)                                                                                                                                                                                                                                                                                                                     | Repo: fix 3.2, extend with Checkmarx findings                               |
| Solution architecture and security documentation               | Data touch points, authentication/authorisation, controls                                         | Present: `docs/SECURITY-REVIEW-SOLUTION-DOC.md`, `docs/ARCHITECTURE.md`, `docs/PRIVACY.md` (with the corrections in sections 3 and 4)                                                                                                                                                                                                                                                                                           | Repo: apply fixes, export                                                   |
| End-user / reviewer usage documentation                        | "Detailed solution user documentation"                                                            | Present since 2026-10-11: `docs/USER-GUIDE.md` (usage, reviewer test-user setup); the README contradiction in 3.1 is fixed                                                                                                                                                                                                                                                                                                      | None; export with step 11                                                   |
| Company information security policy                            | A security program statement scaled to company size                                               | Drafted 2026-10-11: `docs/SECURITY-PROGRAM-STATEMENT.md`; publisher values and signature read "(to be supplied by the publisher)"                                                                                                                                                                                                                                                                                               | Owner: fill in and sign                                                     |
| Third-party component inventory                                | Libraries in static resources, unminified; RetireJS clean                                         | Present: "None" (`SOLUTION-DOC.md:157-160`); no `staticresources` directory; RetireJS 0 findings                                                                                                                                                                                                                                                                                                                                | None                                                                        |
| DAST report                                                    | Only for external endpoints, mobile or API                                                        | Not applicable: no external endpoint and no callouts; statement in `docs/DAST-STATEMENT.md`                                                                                                                                                                                                                                                                                                                                     | None; its PDF is in the upload set (step 11)                                |
| External authentication details                                | URLs and credentials for any external system                                                      | Not applicable beyond the DE org login                                                                                                                                                                                                                                                                                                                                                                                          | None                                                                        |
| Lightning Ready attestation                                    | Console checkbox; app must work in Lightning Experience                                           | App is LWC-only (`auditExplorer.js-meta.xml:7-11`, `tabs/Audit_Trail_Explorer.tab-meta.xml:4`); attestation never mentioned                                                                                                                                                                                                                                                                                                     | Owner: step 5                                                               |
| Draft listing linked to the version                            | Needed before Checkmarx and Start Review                                                          | Copy only: `docs/APPEXCHANGE-LISTING.md`; nothing in the console                                                                                                                                                                                                                                                                                                                                                                | Owner: step 5; Repo: section 7 gaps                                         |
| ISV Partner Program enrollment, PADA, Partner Console contacts | Confirmed by a partner rep before Start Review                                                    | Not recorded anywhere                                                                                                                                                                                                                                                                                                                                                                                                           | Owner: steps 1-2                                                            |
| 2GP ancestry for post-review versions                          | Readiness inherits only from the declared ancestor                                                | Present: `ancestorVersion` `HIGHEST` and `versionNumber` `1.0.1.NEXT` (`sfdx-project.json:4-6`); `1.0.1.4` was built with `1.0.0.2` as ancestor                                                                                                                                                                                                                                                                                 | None now; bump `versionNumber` before the first post-review build (step 17) |

## 7. Listing assets

Concrete gaps between `docs/APPEXCHANGE-LISTING.md` and what the Listing
Builder asks for. Salesforce no longer publishes character or pixel limits
for the current builder; read them from the builder's own field help before
finalising, and treat every figure below as legacy guidance.

- **Visual assets: none exist.** No PNG, JPG or SVG is in the repository
  outside `node_modules/` and `coverage/`; the screenshot checklist is
  unticked (`docs/APPEXCHANGE-LISTING.md:94-97`); the live UI smoke test for
  assets is still open (`docs/LIVE-ORG-VALIDATION.md:398-399`). Legacy specs
  (only published numbers): small logo PNG 60x60 up to 100 KB; tile logo PNG
  280x205 up to 300 KB; high-resolution transparent PNG up to 10 MB; banner
  PNG 1200x300 up to 1 MB; up to eight screenshots PNG up to 1 MB each. A
  2017-era partner page disagrees (tile 224x164, screenshot 700x467). The app
  has no custom icon (tab motif `Custom53: Bell`,
  `tabs/Audit_Trail_Explorer.tab-meta.xml:5`). Do not screenshot
  `00DRK00000aOfV72AK`; its audit trail holds 65 seeded rows
  (`LIVE-ORG-VALIDATION.md:381-383`). Review the DE org's audit trail for
  usernames before publishing images.
- **Copy limits are unsourced.** The headings "Tagline (<= 10 words)" and
  "Short description (<= 250 characters)" (`APPEXCHANGE-LISTING.md:22,26`,
  repeated at `CHANGELOG.md:136-139`) cite no Salesforce source; the only
  published figures are the legacy editor's 255-character brief and
  1200-character full description. The copy itself (8 words, about 229
  characters) fits either way. Remove the limit claims or source them.
- **False capability:** "by free text, section, action, changed-by user, and
  date range" (`APPEXCHANGE-LISTING.md:44-45`); the UI has no action filter
  (`auditExplorer.js:148` sends `actions: []`). `README.md:16` is correct.
- **Missing fields:** Highlights; SEO description; Required and Compatible
  Salesforce Products; Supported Languages; Supported Features; Industries;
  Target User Persona; Business Needs (the three categories at lines 78-80
  may not match current picklist labels); installation method; lead org.
- **Missing legal and support items:** customer terms and conditions
  (`LICENSE` is the Apache-2.0 software licence, not customer terms); a
  hosted privacy-policy URL (`docs/PRIVACY.md` exists only in the repo); a
  support email, hours and SLA statement beyond "GitHub issues"
  (`APPEXCHANGE-LISTING.md:88-90`); company name, description, website and
  phone for the provider profile.
- **Already correct:** the claims policy (`APPEXCHANGE-LISTING.md:99-105`),
  the two-grant requirement (lines 68-74), edition exclusions (64-66) and
  Free pricing (84). Keep the Free model; switching to a paid add-on later
  (the archiving idea at `README.md:64-66`) would be a Paid Add-On listing
  with its own agreement and fees.

Sources: <https://developer.salesforce.com/docs/platform/isvforce/guide/appexchange-listing-builder-overview.html>,
<https://appexchange.my.salesforce-sites.com/appexchange/resource/help/Content/appexchange_publish_listings_upload_content.htm>,
<https://trailhead.salesforce.com/content/learn/modules/appexchange-partners-publishing/appexchange-listing-builder>

## 8. Fees and timeline

Researched on 2026-10-11 against the live ISVforce Guide, Trailhead, Help and
Partner Community pages.

**Fees for this package (Free, Apache-2.0):**

- Security review: $0. The current guide says "If you plan to distribute your
  solution for free, you don't pay the fee"
  (<https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_how_it_works.htm>).
  Resubmitting a "Returned" submission and false-positive-only disputes are
  explicitly free for everyone. Re-review fees "apply" in general but are
  waived while the solution is free.
- Checkmarx: three scans per review included.
- Revenue share: none on a free app (15% ISVforce / 25% OEM applies to
  revenue; Help article 000394757, 2026-09-22).
- Partner program membership fee: no current fee schedule was reachable. A
  2018-19 policy PDF (login required) refers to "Program Fees"; confirm with
  the partner representative.

**Fee for paid solutions, for context only:** the guide's fee page returns
404 today; Trailhead's current unit states $999 per attempt (initial and each
later attempt) and no annual fee. Two still-public Partner Community pages
carry stale figures ($2,700 or $2,550 plus $150 per year, copyright
2000-2017) and should not be used. No 2024-2026 announcement changing fees
was found; the free-solution waiver is long-standing, not new.

**Timeline (Salesforce publishes calendar weeks, not business days):**

| Stage                                         | Published estimate                |
| --------------------------------------------- | --------------------------------- |
| Submission verification (Security Review Ops) | 1-2 weeks                         |
| First Product Security test                   | 3-4 weeks ("up to 4 weeks")       |
| Initial review end to end                     | "Approximately 4-6 weeks"         |
| Follow-up test after a failed result          | 2-3 weeks                         |
| Periodic re-review                            | up to 6 weeks; 60-day remediation |
| Listing live after Publish                    | about 30 minutes                  |
| Listing review step and agreement signature   | no published SLA                  |

Realistic plan from today, assuming partner enrollment and the PADA are
already in place: about two weeks to produce the Checkmarx report and its
false-positive document (the official-selector report, the usage guide and
the security program statement exist since 2026-10-11) and the reviewer
users (the new package version, `1.0.1.4`, was built and promoted on
2026-10-12, section 3, so no further build gates submission); 4-6 weeks of
review; listing work in parallel. Roughly 6-9 weeks to a published listing
if it passes first time, i.e. late November to mid December 2026.

**Dates to watch:** the 2026-09-19 CI scan artifact expires about
2026-10-19; book office hours for 3-4 weeks after the submission date on the
day you submit.

Sources: <https://developer.salesforce.com/docs/platform/isvforce/guide/security-review-how-it-works.html>,
<https://trailhead.salesforce.com/content/learn/modules/isv_security_review/isv_security_review_submit>,
<https://help.salesforce.com/s/articleView?id=000394757&type=1>,
<https://developer.salesforce.com/docs/atlas.en-us.packagingGuide.meta/packageGuide/security_review_stages.htm>

## 9. Open questions

Things the research could not confirm from a primary source. Two earlier
items were closed on 2026-10-12 and removed: which commit built the submitted
version is now recorded (`1.0.1.4` from `f0ad675`, confirmed with
`sf package version report`; section 1), and the 5,000-id `NOT IN` bind no
longer exists (3.7).

1. **Is a Checkmarx report strictly required when a Code Analyzer report is
   supplied?** "Test Your Entire Solution" says managed packages use Code
   Analyzer and mentions Checkmarx only as a fallback; the Required Materials
   table, "Scan Your Managed Package", the portal page and the live portal FAQ
   all say it is mandatory in addition. Plan for both.
2. **Will the Partner Security Portal accept a login from a PBO-hosted Dev
   Hub?** The FAQ says to use the Dev Hub for 2GP packages and also says
   "Please use DevOrgs only". Verify by logging in; fall back to a Partner
   Community case.
3. **Current fee amount for paid solutions and the free-waiver mechanics.**
   The guide's fee page is a 404; $999 comes from Trailhead; some 2026 blogs
   mention a "fee waiver code" that no primary source describes.
4. **Does a Free, non-Checkout listing need a PADA, and how is it signed?**
   The listing-approvals page documents clickthrough for Checkout and offline
   signature for Paid, Freemium and Paid Add-On, and is silent on Free; the
   onboarding guide says a PADA is required before Security Review.
5. **Does a partner-program membership fee apply to an ISV with only a free
   app?** No current fee schedule was reachable.
6. **Must LMA registration be done before Start Review is enabled for a free
   app?** Docs present it as a pre-listing step, not a review prerequisite.
7. **Exact current Listing Builder limits** for tagline, descriptions,
   highlights and images; and the current Business Needs, feature, industry
   and persona picklist values.
8. **The exact Technical Details questions in the current wizard** and the
   accepted upload file types (login required; description comes from
   Trailhead and legacy help).
9. **Re-review cadence**: risk-based with no fixed period (guide), "typically
   once a year" (Trailhead), "6 months to 2 years" (2017 partner page).
10. **Partner-only pages not read** (HTTP 401): Security Review Requirements
    Checklist, Checklist Builder, Lightning Ready Guide, Partner Program
    Policies PDF.
11. **Whether the Secure Coding Guide's "all JavaScript in static resources,
    unminified" rule is enforced for pure LWC bundles with no third-party
    code.** Most plausibly it applies to bundled libraries only.
12. **Does a subscriber administrator see the `System.debug` line from
    managed code with a standard trace flag?** Affects only the wording at
    `FINDINGS-DISPOSITION.md:181`.

## 10. Evidence

Sixty-seven candidate findings were judged: 87 raw findings raised across
access control, data handling, injection, LWC client, tests, packaging,
robustness and documentation consistency were merged to 60 unique, and a
completeness critic added 7 more. Each was checked by three independent
verifiers against the source. Sixty-three were confirmed (0 blocker, 0 high,
12 medium, 41 low, 10 info) and appear in sections 2-4 under their verified
severity, which in several cases is lower than first reported. Four were
rejected:

- **Permission set grants Apex class access to three classes with no entry
  point** - accurate observation, no defect: class access on service classes
  is harmless and the entry point is gated.
- **`AuditFilter.userIds` and `actions` are bound without pre-validation or
  size limits** - bound variables cannot alter query structure; the only
  effect of oversized input is the caller's own request failing; style
  consistency note at most.
- **Claims that cannot be verified from the repository alone (run ids, org
  ids, build figures, Actions links)** - true but expected; the record cites
  them so they can be checked with org access, which is the correct practice.
- **Graph Engine rule names in the docs do not match the engine's
  identifiers** - refuted against the installed 5.16.0 engine; the names in
  the repository are correct for Code Analyzer v5.

Two further items were considered and kept at their verified level rather
than the originally proposed one: the pill-removal defect (3.12, proposed
high, verified medium) and the test-coverage gap for `handleExport` (section
4, proposed medium, verified low because the repository already discloses it
at `docs/LIVE-ORG-VALIDATION.md:295-299`).
