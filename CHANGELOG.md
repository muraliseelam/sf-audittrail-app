# Changelog

All notable changes to Audit Trail Explorer are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses the packaging version number (`versionNumber` in
`sfdx-project.json`) rather than strict SemVer, consistent with how
Salesforce packages are versioned.

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
  `npm run prettier:verify`, and `npm run test:unit` on every push and pull
  request.
- `docs/LIVE-ORG-VALIDATION.md` recording live-org validation performed
  outside CI (package install, `RunLocalTests` results, and the current
  namespace-linkage blocker for a managed 2GP package).

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
  AppExchange listing.** The managed versions above are betas, not promoted
  releases.

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
- Corrected `docs/APPEXCHANGE-LISTING.md`: shortened the tagline to fit the
  documented ≤10-word limit and the short description to fit the documented
  ≤250-character limit; removed a false claim that row detail shows
  "context, issuer" (the UI renders only delegate user and namespace);
  reworded the access-control claim so it does not imply the runtime itself
  bypasses permissions - assigning the packaged permission set is what
  grants `ViewSetup` and its `ViewRoles` prerequisite.
- Corrected the same false "row detail" claim in `README.md`'s feature list.
- Corrected beta/release wording throughout `README.md`, `SECURITY.md`, and
  `docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`: the installed package is
  an unreleased unlocked beta, not production-installable, not managed, not
  AppExchange-reviewed/submitted, and not upgrade-equivalent to a future
  released version. `README.md` install guidance is now restricted to
  Developer Edition orgs, sandboxes, and trial/scratch orgs.
- `SECURITY.md`'s vulnerability-reporting channel previously pointed to
  GitHub's private vulnerability reporting flow, which is **not enabled**
  for this repository. It now publishes a monitored email address
  (`muralirseelam+sf-audittrail-security@gmail.com`) as the reporting
  channel and no longer implies GitHub PVR is available.

## [1.0.0] - Initial unlocked package release

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
- 28 Apex tests (~97% org-wide coverage) and 5 Jest tests, including paging
  correctness against real data and CSV formula-injection escaping.
- Salesforce Code Analyzer scan across all six engines (PMD, Graph Engine,
  ESLint, CPD, RetireJS, secrets-regex) using the `Recommended` + `Security` +
  `AppExchange` rule selectors, which resolve to **310 rules**. Result: **0
  Critical, 0 High**, 11 Moderate, 74 Low, and no finding carrying the
  `Security`, `AppExchange` or `ErrorProne` tag. The Graph Engine analysed
  14,503 paths across 3/3 entry points with 0 violations. See
  `docs/SECURITY-REVIEW-*` for the per-rule disposition of the Moderate/Low
  items.

[1.0.0]: https://github.com/muraliseelam/sf-audittrail-app/releases/tag/v1.0.0
