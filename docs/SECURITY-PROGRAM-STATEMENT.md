# Information Security Program Statement

- **Publisher:** (to be supplied by the publisher)
- **Product:** Audit Trail Explorer, managed 2GP package `atexplorer`
  (`0Hohm0000000NHZCA2`), released version `1.0.0.2` (`04thm000002OtQPAA0`)
- **Source:** <https://github.com/muraliseelam/sf-audittrail-app>, Apache
  License 2.0
- **Statement date:** 2026-10-11

This statement describes how Audit Trail Explorer is developed, released and
supported, for upload with an AppExchange Security Review submission. The
package has **not** been submitted for that review, has **not** been reviewed
and has **no** AppExchange listing. Every practice below is one the public
repository evidences; the references point at that evidence.

## 1. Scope and organisation

The publisher is a single maintainer distributing an open-source Salesforce
package. There is no separate security team; the maintainer owns every
function below, and the contacts in section 8 reach that person directly. No
third-party certification, external penetration test or cyber insurance is
claimed. In scope: the metadata under `force-app/` (14 Apex classes, of which
four are test classes and one is a test-only mock provider, one Lightning web
component, one permission set, one app, one tab), the build, test and scan
tooling committed beside it, and the release and support process.

## 2. What the package handles

- **Reads only.** The standard `SetupAuditTrail` object and, for a user
  type-ahead, `Id`, `Name` and `Username` of active users (`docs/PRIVACY.md`).
  No custom object, Big Object, file or custom setting; the runtime code
  performs no DML (the four `insert` statements in `force-app/` are all in
  `AuditPermissionServiceTest.cls:30,55,100,108`, inside tests).
- **No external surface.** No callout, named credential, remote site setting,
  Connected App or endpoint; no telemetry; no browser storage
  (`docs/PRIVACY.md`, "What the app does not do"). The publisher holds no
  subscriber data or credentials at any time.
- **No privilege added.** Both data-returning entry points are gated on the
  caller's own "View Setup and Configuration" permission, both production
  queries run in `USER_MODE` (`SetupAuditTrailProvider.cls:40`,
  `AuditQueryController.cls:82`), and under managed packaging the shipped
  permission set grants no system permission (`README.md`, "Two grants are
  required").

## 3. Secure development

- **Public source**, Apache-2.0 (`LICENSE`). Version `1.0.0.2` was built from
  commit `934f200`, tagged `v1.0.0`; `force-app/` is unchanged since
  (`git diff --stat v1.0.0..HEAD -- force-app` is empty on 2026-10-11).
- **Coding standard** (`CONTRIBUTING.md`, "Code style"): `with sharing` on
  every production class, bind variables only, `USER_MODE` for CRUD/FLS, no
  `innerHTML`, `eval` or `lwc:dom="manual"`. The CSV export escapes formula
  triggers in its own unit-tested module, `csv.js`.
- **CI gates** on every push to `main` and every pull request
  (`.github/workflows/ci.yml`): ESLint with the Salesforce LWC configuration,
  Prettier, and Jest with coverage (2026-10-11: 7/7 tests, `csv.js` 100%,
  `auditExplorer.js` 70.64% statements).
- **Apex tests** need a live org, so they run outside CI: 29 tests, 97%
  coverage at package build, re-run 29/29 in three orgs with the run ids in
  `docs/LIVE-ORG-VALIDATION.md`.

## 4. Static analysis

- **Cadence.** Salesforce Code Analyzer runs weekly (Mondays 06:00 UTC) and on
  demand (`.github/workflows/code-analyzer.yml`). The workflow fails unless
  the selector resolves to 310 rules from 6 engines, fails on any Critical or
  High finding, and accepts the Graph Engine only at 14,503 paths across 3/3
  entry points with no internal error. A clean result is accepted only with
  its counts (`code-analyzer.yml`).
- **Records.** Dated results are kept in `docs/CODE-ANALYZER-SCAN-RECORD.md`;
  the report files are not committed (`.gitignore:55`). Every Moderate and Low
  finding is dispositioned in `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`;
  none is suppressed in `code-analyzer.yml`, and the single inline suppression
  (`auditExplorer.js:216`) is itself reported by the scan and dispositioned.
- **Current results** (2026-10-11, plugin 5.16.0, source as built):
  repository selector, 85 code findings, 0 Critical, 0 High, none tagged
  `Security` or `AppExchange` (the one Critical entry in that run is a `flow`
  engine-instantiation error with no file, recorded in the scan record, not a
  code finding); Graph Engine, 0 violations at the full path count;
  Salesforce's AppExchange selector (62 rules), run from a clean checkout of
  `934f200`, 0 violations.

## 5. Change management and release

- Every change to `main` runs the CI gates; external contributions arrive as
  pull requests and follow the `CONTRIBUTING.md` checklist (tests for changed
  behaviour, Apex results reported against an org, no new object, trigger,
  job, callout or stored data without discussion).
- A managed version is built from a specific commit, which is tagged; before
  submission the source is checked against the tag and the version is
  re-verified by static analysis, a source deploy with tests, and the
  installed version in a subscriber org (`docs/LIVE-ORG-VALIDATION.md`,
  "Pre-submission re-verification").
- Versions built after a review declare the reviewed version as their 2GP
  ancestor in `sfdx-project.json`, a resubmission carries only the security
  fixes asked for, and no version is created while a review is pending
  (`docs/SECURITY-REVIEW-SUBMISSION.md`, steps 10, 17 and 18). No ancestor is
  declared today because no version has been reviewed.

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
- **Targets.** `SECURITY.md` commits to acknowledgement "within a reasonable
  time" and states no numeric target. Acknowledgement: (to be supplied by the
  publisher). Fix release: (to be supplied by the publisher).
- **Incidents.** The publisher holds no subscriber data, credentials or org
  access, so a compromise of the publisher's systems cannot expose subscriber
  data through this package. An incident is a vulnerability in shipped code
  or a compromise of the repository or packaging Dev Hub; it follows the
  process above, is disclosed in `CHANGELOG.md` and the repository, and,
  where Salesforce requires it, is reported through the Security Review
  contact designated in the Partner Console (to be supplied by the
  publisher).

## 8. Contacts and signature

| Role                                      | Contact                                          |
| ----------------------------------------- | ------------------------------------------------ |
| Security reports                          | `muralirseelam+sf-audittrail-security@gmail.com` |
| Questions and bugs                        | GitHub issues at the repository above            |
| Security review contact (Partner Console) | (to be supplied by the publisher)                |

- Publisher name: (to be supplied by the publisher)
- Title: (to be supplied by the publisher)
- Company: (to be supplied by the publisher)
- Date: (to be supplied by the publisher)
- Signature: (to be supplied by the publisher)
