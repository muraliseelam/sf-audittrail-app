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

- **Current: package version `1.0.0.2` (`04tbm000000gaALAAY`)**, built from
  this exact source commit (package-version request `08cbm000000JDHhAAO`,
  43 metadata files), installs successfully into a **clean active QA scratch
  org** (alias `qa`, org ID `00DO500000q61ptMAA`, no packages installed
  beforehand; install request `0HfO50000041ge1KAA`), and the
  `Audit_Trail_Viewer` permission set assigns without error.
  `RunLocalTests` passed **28/28** with **0 failures** (test run
  `707O500002wjQxU`), **97% org-wide coverage**,
  `HasPassedCodeCoverageCheck=true`, and validation **not skipped**. Tooling
  API confirmed the installed LWC bundle includes the full-width-formula-
  trigger fix in `csv.js` and the accumulated-row `computeFacets` fix in
  `auditExplorer.js`.
- Superseded: package version `1.0.0.1` (`04tbm000000aeOjAAI`) installed
  successfully in a separate dev org and the `Audit_Trail_Viewer` permission
  set assigned without error. `RunLocalTests` passed 22/22 (test run
  `707bm00001DpAzr`) with 97% test-run coverage;
  `HasPassedCodeCoverageCheck=true`. (This build predates the four fixes
  above; the 22 vs. 28 test count reflects that earlier source, not a
  discrepancy in the current one.)
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
- Salesforce Code Analyzer scan (`Recommended` + `AppExchange` rule
  selectors, PMD, Graph Engine, ESLint, RetireJS, secrets-regex) with 0
  Critical/High findings; see `docs/SECURITY-REVIEW-*` for the full
  disposition of remaining Moderate/Low findings.

[Unreleased]: https://github.com/muraliseelam/sf-audittrail-app/compare/main...HEAD
