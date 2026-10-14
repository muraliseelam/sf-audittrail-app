# Information Security Program Statement

- **Publisher:** Murali Mohan Reddy Seelam (individual publisher)
- **Product:** Audit Trail Explorer, managed 2GP package `atexplorer`
  (`0Hohm0000000NHZCA2`), released version `1.0.1.4` (`04thm000002tWirAAE`)
- **Source:** <https://github.com/muraliseelam/sf-audittrail-app>, Apache
  License 2.0
- **Statement date:** 2026-10-14

This statement describes how Audit Trail Explorer is developed, released and
supported. It accompanies the AppExchange Security Review submission of
version `1.0.1.4`. No version of the package has completed that review, and
its AppExchange listing is an unpublished draft. Every practice below is one
the public repository evidences; the references point at that evidence.

## 1. Scope and organisation

The publisher is an individual developer distributing an open-source
Salesforce package. There is no separate security team; the publisher owns
every function below, and the contacts in section 8 reach the publisher
directly. No
third-party certification, external penetration test or cyber insurance is
claimed. In scope: the metadata under `force-app/` (14 Apex classes, of which
four are test classes and one is a test-only mock provider, one Lightning web
component, one permission set, one app, one tab), the build, test and scan
tooling committed beside it, and the release and support process.

## 2. What the package handles

- **Reads only.** The standard `SetupAuditTrail` object and, for a user
  type-ahead, `Id`, `Name` and `Username` of active users (`docs/PRIVACY.md`).
  No custom object, Big Object, file or custom setting; the runtime code
  performs no DML (the nine DML statements in `force-app/`, all `insert`, are
  inside test classes: eight in
  `AuditPermissionServiceTest.cls:49,74,112,145,153,154,212,221` and one in
  `AuditQueryControllerTest.cls:24`).
- **No external surface.** No callout, named credential, remote site setting,
  Connected App or endpoint; no telemetry; no browser storage
  (`docs/PRIVACY.md`, "What the app does not do"). The publisher holds no
  subscriber data or credentials at any time.
- **No privilege added.** Both data-returning entry points are gated on the
  caller's own "View Setup and Configuration" permission, both production
  queries run in `USER_MODE` (`SetupAuditTrailProvider.cls:42`,
  `AuditQueryController.cls:83`), and under managed packaging the shipped
  permission set grants no system permission (`README.md`, "Two grants are
  required").

## 3. Secure development

- **Public source**, Apache-2.0 (`LICENSE`). Version `1.0.1.4` was built from
  commit `f0ad675`; the release is tagged `v1.0.1`, and the tagged
  `force-app/` is identical to that commit
  (`git diff --stat f0ad675..v1.0.1 -- force-app` is empty).
- **Coding standard** (`CONTRIBUTING.md`, "Code style"): `with sharing` on
  every production class, bind variables only, `USER_MODE` for CRUD/FLS, no
  `innerHTML`, `eval` or `lwc:dom="manual"`. The CSV export escapes formula
  triggers in its own unit-tested module, `csv.js`.
- **CI gates** on every push to `main` and every pull request
  (`.github/workflows/ci.yml`): ESLint with the Salesforce LWC configuration,
  Prettier, and Jest with coverage (2026-10-12: 26/26 tests, `csv.js` 100%,
  `auditExplorer.js` 95.16% statements, measured with the v8 coverage
  provider).
- **Apex tests** need a live org, so they run outside CI: 50 tests, 96%
  coverage at package build, re-run 50/50 in three orgs: a namespaced scratch
  org by source deploy (`0Afh1000000NfiTCAS`), a subscriber org on the
  installed version (test run `707di0000LCKGo0`) and the reviewer test org
  (test run `707i800000BHk65`); see `docs/LIVE-ORG-VALIDATION.md`.

## 4. Static analysis

- **Cadence.** Salesforce Code Analyzer runs weekly (Mondays 06:00 UTC) and on
  demand (`.github/workflows/code-analyzer.yml`). The workflow fails unless
  the selector resolves to 310 rules from 6 engines, fails on any Critical or
  High finding in that three-tag scan, and accepts the standalone Graph Engine
  run only at 6,537 paths across 3/3 entry points with no internal error. A
  clean result is accepted only with its counts (`code-analyzer.yml`).
- **Records.** Dated results are kept in `docs/CODE-ANALYZER-SCAN-RECORD.md`;
  the report files are not committed (`.gitignore:55`). Every Moderate and Low
  finding is dispositioned in `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`;
  none is suppressed in `code-analyzer.yml`, and the two inline suppressions
  (`auditExplorer.js:289` and `__tests__/auditExplorer.test.js:81`, both
  `no-await-in-loop` on sequential cursor-driven calls) are themselves
  reported by the scan and dispositioned.
- **Current results** (2026-10-12, plugin 5.16.0, commit `f0ad675`, the
  source of `1.0.1.4`): repository selector, 310 rules from 6 engines, 119
  findings (13 Moderate, 106 Low), 0 Critical, 0 High, none tagged `Security`
  or `AppExchange`; Salesforce's official AppExchange command (62 rules from 5
  engines), 0 violations, with the resulting `CodeAnalyzerReport.html` (64,954
  bytes, SHA-256
  `03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C`)
  attached to this submission; Graph Engine alone, 6,537 paths from 3/3
  entry points with no internal error, 0 violations on the two Security rules
  (`ApexFlsViolation`, `DatabaseOperationsMustUseWithSharing`) and one
  accepted Performance finding (`AvoidDatabaseOperationInLoop`, the bounded
  batch loop; dispositioned in
  `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`).
- **Source Code Scanner** (Partner Security Portal, Checkmarx; job
  `a0BKX000000pcxh2AA`, submitted 2026-10-14 02:04 UTC, on `1.0.1.4`; report
  attached to this submission): no Critical, High or Serious issue and no
  quality issue; three Medium issues, all in one test class, dispositioned as
  false positives in `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`.

## 5. Change management and release

- Every change to `main` runs the CI gates; external contributions arrive as
  pull requests and follow the `CONTRIBUTING.md` checklist (tests for changed
  behaviour, Apex results reported against an org, no new object, trigger,
  job, callout or stored data without discussion).
- A managed version is built from a specific commit, which is tagged; before
  submission the source is checked against the tag and the version is
  re-verified by static analysis, a source deploy with tests, and the
  installed version in a subscriber org (`docs/LIVE-ORG-VALIDATION.md`,
  "2026-10-12 - Release 1.0.1 validation").
- Versions built after a review declare the reviewed version as their 2GP
  ancestor in `sfdx-project.json`, a resubmission carries only the security
  fixes asked for, and no version is created while a review is pending. No
  version has completed review yet; `1.0.1.4` declares the previous release,
  `1.0.0.2`, as its ancestor (`sfdx-project.json`, `ancestorVersion`
  `HIGHEST`).

## 6. Dependencies

The package ships no third-party code: no static resource, library or npm
package reaches the runtime (`docs/SECURITY-REVIEW-SOLUTION-DOC.md`,
"Third-party code"). `package.json` declares `devDependencies` only (lint,
Prettier, Jest), installed in CI with `npm ci` from the committed lockfile.
The RetireJS engine runs in every Code Analyzer scan and has reported 0
findings on every recorded run.

## 7. Vulnerability handling and incident response

- **Reporting.** Email `muralirseelam+sf-audittrail-security@gmail.com`, an
  inbox monitored for this project; not public issues, and not GitHub private
  vulnerability reporting, which is not enabled (`SECURITY.md`). Scope and
  exclusions are stated there.
- **Process** (`SECURITY.md`, "What to expect"): acknowledge and confirm with
  the reporter; fix; publish a new package version; credit the reporter in
  `CHANGELOG.md` unless anonymity is requested. Fixes are issued against the
  current released version only. No paid bounty is offered.
- **Targets** (also stated in `SECURITY.md`). Acknowledgement: within 5
  business days of a report. Fix release: a fixed package version within 30
  days for a confirmed Critical or High issue.
- **Incidents.** The publisher holds no subscriber data, credentials or org
  access, so a compromise of the publisher's systems cannot expose subscriber
  data through this package. An incident is a vulnerability in shipped code
  or a compromise of the repository or packaging Dev Hub; it follows the
  process above, is disclosed in `CHANGELOG.md` and the repository, and,
  where Salesforce requires it, is reported through the Security Review
  contact designated in the Partner Console (`muralirseelam@gmail.com`).

## 8. Contacts and signature

| Role                                      | Contact                                          |
| ----------------------------------------- | ------------------------------------------------ |
| Security reports                          | `muralirseelam+sf-audittrail-security@gmail.com` |
| Questions and bugs                        | GitHub issues at the repository above            |
| Security review contact (Partner Console) | `muralirseelam@gmail.com`                        |

- Publisher name: Murali Mohan Reddy Seelam
- Title: Independent Developer
- Company: Murali Mohan Reddy Seelam (individual publisher)
- Date: 2026-10-14
- Signature: /s/ Murali Mohan Reddy Seelam
