# Changelog

All notable changes to Audit Trail Explorer are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project uses the packaging version number (`versionNumber` in
`sfdx-project.json`) rather than strict SemVer, consistent with how
Salesforce packages are versioned.

## [Unreleased]

### Added

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

### Verified in a live org (not run in CI)

- Existing unlocked package `04tbm000000aeOjAAI` installs successfully in a
  clean dev org and the `Audit_Trail_Viewer` permission set assigns without
  error.
- `RunLocalTests` passed 22/22 (test run `707bm00001DpAzr`) with 97% test-run
  coverage; the package version report shows
  `HasPassedCodeCoverageCheck=true`.
- Namespace `atexplorer` is registered, but is **not yet linked** to the Dev
  Hub used for packaging (`pbo2` has zero `NamespaceRegistry` records).
  Linkage is currently blocked by a platform-level defect in the
  SalesforceDX Namespace Registry's OAuth/PKCE flow (not a configuration
  error in this org or repository), which remains the blocker for creating a
  new managed (2GP) package. See
  [`docs/LIVE-ORG-VALIDATION.md`](docs/LIVE-ORG-VALIDATION.md) for the full
  checklist. **This package is currently an unlocked beta package - it is
  not yet a managed package and has not undergone AppExchange security
  review.**

### Fixed

- `.prettierrc` was missing `tabWidth`/`printWidth`/`singleQuote`, so
  `npm run prettier:verify` failed on every source file even though no file
  had actually drifted from the project's real style. The settings now match
  the codebase, and `package-lock.json` (npm-managed, always 2-space) is
  excluded from Prettier formatting to avoid churn on every `npm install`.

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
- Salesforce Code Analyzer scan (`Recommended` + `AppExchange` rule
  selectors, PMD, Graph Engine, ESLint, RetireJS, secrets-regex) with 0
  Critical/High findings; see `docs/SECURITY-REVIEW-*` for the full
  disposition of remaining Moderate/Low findings.

[Unreleased]: https://github.com/muraliseelam/sf-audittrail-app/compare/main...HEAD
