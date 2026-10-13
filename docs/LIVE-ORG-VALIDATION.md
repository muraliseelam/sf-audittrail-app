# Live-Org Validation Record

This file tracks validation steps that require a live Salesforce org/Dev Hub
and therefore cannot be run from this repository's CI. It is updated by
whoever performs each step, with the concrete evidence (org, test run id,
report values) rather than a bare pass/fail, so the record stays auditable.

**Status:** managed 2GP version `1.0.1.4` (`04thm000002tWirAAE`) is the
current **released** package version, promoted 2026-10-12; `1.0.0.2`
(`04thm000002OtQPAA0`), promoted 2026-09-09, remains released as the previous
version. Nothing below constitutes an AppExchange security review approval,
certification, or listing — "released" is the Salesforce packaging state only.
See [`docs/APPEXCHANGE-LISTING.md`](APPEXCHANGE-LISTING.md) for the claims
policy. The 1.0.1 record is under
[2026-10-12 - Release 1.0.1 validation](#2026-10-12---release-101-validation).

## Package install validation

The install record for the current released version, `1.0.1.4`, is under
[2026-10-12 - Release 1.0.1 validation](#2026-10-12---release-101-validation)
below; the entries here are the `1.0.0.2` lineage.

### Previous release: managed 2GP `1.0.0.2` (`04thm000002OtQPAA0`) — 2026-09-09

Version `1.0.0.2` was promoted to a released version on **2026-09-09**
(`sf package version promote`, Dev Hub `partner-pbo` / `00Dhm000004MOXjEAO`).
`IsReleased` is now `true`. Promotion is irreversible and consumes the version
number permanently.

**Released is a Salesforce packaging state, not an AppExchange listing.** This
package has not been submitted for or passed AppExchange Security Review and
has no listing. What changed is that it now installs into any org type,
including production, and carries normal managed upgrade guarantees.

Validated end to end in a **fresh scratch org created for this purpose**, with
no packages installed beforehand:

| Item                         | Result                                                                                                 |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| Package (2GP, managed)       | `Audit Trail Explorer` — `0Hohm0000000NHZCA2`                                                          |
| Package version              | `1.0.0.2` (`04thm000002OtQPAA0`)                                                                       |
| Namespace                    | `atexplorer`                                                                                           |
| `IsReleased`                 | **`true`** (promoted 2026-09-09)                                                                       |
| Metadata files               | 43                                                                                                     |
| Package coverage             | 97% (authoritative figure, measured at package build time)                                             |
| `HasPassedCodeCoverageCheck` | `true`                                                                                                 |
| Target org                   | Clean scratch org, alias `rel-qa`, org ID `00DRK00000aOfV72AK`, created 2026-09-09, expires 2026-09-16 |
| Install command              | `sf package install --security-type AdminsOnly --no-prompt`                                            |
| Installed package record     | `0A3RK000007krZy0AI`                                                                                   |
| Install result               | `SUCCESS`                                                                                              |
| Permission set assigned      | `atexplorer__Audit_Trail_Viewer` — assigned successfully (namespaced, confirming the managed install)  |
| Apex tests                   | **29 / 29 passed**, 100% pass rate, run ID `707RK0000BPQrG1`                                           |

The Apex tests ran as namespaced `atexplorer.*` classes, i.e. the managed
package's own tests executing inside the subscriber org. Code coverage is not
meaningfully reported for managed code in a subscriber org; the authoritative
97% figure comes from package build time and is recorded above.

#### The system-permission strip still applies to the released version

Re-verified against the released version rather than assumed from the beta:

| Field                  | Value on the installed permission set in `rel-qa` |
| ---------------------- | ------------------------------------------------- |
| `Name`                 | `Audit_Trail_Viewer`                              |
| `NamespacePrefix`      | `atexplorer`                                      |
| `PermissionsViewSetup` | **`false`**                                       |
| `PermissionsViewRoles` | **`false`**                                       |

Both permissions are declared `true` in this repository's source. Promotion to
a released version does **not** change the behaviour: managed packaging strips
system permissions on install either way, so a subscriber administrator must
still grant **"View Setup and Configuration"** separately, through a profile or
a permission set created in their own org. This is now stated in the install
section of `README.md`.

### Earlier: the same version `1.0.0.2` while still a beta, in `mgd-qa2`

The same version id, validated in a different clean org before it was
promoted. Retained because it is the record that first established the
system-permission strip. Built from this exact source commit.

| Item                         | Result                                                                                                |
| ---------------------------- | ----------------------------------------------------------------------------------------------------- |
| Package (2GP, managed)       | `Audit Trail Explorer` — `0Hohm0000000NHZCA2`                                                         |
| Package version              | `1.0.0.2` (`04thm000002OtQPAA0`)                                                                      |
| Namespace                    | `atexplorer`                                                                                          |
| Metadata files               | 43                                                                                                    |
| Package coverage             | 97%                                                                                                   |
| `HasPassedCodeCoverageCheck` | `true`                                                                                                |
| `IsReleased`                 | `false` (beta)                                                                                        |
| Target org                   | Clean scratch org, alias `mgd-qa2`, org ID `00DRL00000Vkme62AB` (no packages installed beforehand)    |
| Installed package record     | `0A3RL000006C6HY0A0`                                                                                  |
| Install result               | Succeeded                                                                                             |
| Permission set assigned      | `atexplorer__Audit_Trail_Viewer` — assigned successfully (namespaced, confirming the managed install) |

### Superseded: managed 2GP beta `1.0.0.1` (`04thm000002OtOnAAK`)

The first managed build. It installed cleanly, but **failed 1 of 28 Apex
tests** in the subscriber org. That failure was not a packaging accident — it
surfaced a real, permanent platform constraint, recorded under
[Managed packaging strips system permissions](#managed-packaging-strips-system-permissions)
below. Superseded by `1.0.0.2`, which contains the fix.

### Superseded: unlocked package versions

The unlocked lineage (`0Hobm0000005681CAA`) is a different, non-namespaced
package and **cannot be converted in place** into the managed lineage above.
Retained for historical traceability only; do not install these.

| Version                          | Target org                         | Result                                               |
| -------------------------------- | ---------------------------------- | ---------------------------------------------------- |
| `1.0.0.2` (`04tbm000000gaALAAY`) | `qa`, `00DO500000q61ptMAA` (clean) | Installed; `Audit_Trail_Viewer` assigned; 28/28, 97% |
| `1.0.0.1` (`04tbm000000aeOjAAI`) | `orgfarm-dev-ed`                   | Installed; `Audit_Trail_Viewer` assigned; 22/22, 97% |

## Apex test runs

### Previous release: managed `1.0.0.2` in the subscriber org — 2026-09-09

| Item              | Result                                                      |
| ----------------- | ----------------------------------------------------------- |
| Org               | `rel-qa` (`00DRK00000aOfV72AK`), released package installed |
| Tests selected    | The installed package's 29 tests — see correction below     |
| Tests passed      | **29 / 29 (0 failures)**, 100% pass rate                    |
| Test run ID       | `707RK0000BPQrG1`                                           |
| Test classes      | Ran as namespaced `atexplorer.*` classes                    |
| Org-wide coverage | Not meaningfully reported for managed code — see note below |

**Correction, 2026-10-11.** The test level originally recorded in this table
was wrong for a subscriber org and has been removed; the result stands: the
package's 29 tests ran and passed under run id `707RK0000BPQrG1`. Installed
managed-package tests are selected only by `RunAllTestsInOrg` or by naming the
classes explicitly, as the `mgd-qa2` record below and the 2026-09-10 record
(`707RK0000BPbjPq`) already state.

### Earlier: managed beta `1.0.0.2` in the subscriber org

| Item              | Result                                                      |
| ----------------- | ----------------------------------------------------------- |
| Org               | `mgd-qa2` (`00DRL00000Vkme62AB`), managed package installed |
| Test level        | `RunAllTestsInOrg`                                          |
| Tests passed      | **29 / 29 (0 failures)**                                    |
| Org-wide coverage | Reported as 0% — see note below                             |

> Salesforce does **not** expose managed package code coverage to subscriber
> orgs, so a subscriber-side coverage figure of 0% is expected and is not a
> regression. The authoritative figure is the **97%** measured at package
> build time, with `HasPassedCodeCoverageCheck=true`.

### Previous release: source deploy of the same commit — 2026-09-09

| Item         | Result                                             |
| ------------ | -------------------------------------------------- |
| Org          | Scratch org, alias `src-qa` (`00DRu00000Xnmy8MAB`) |
| Test level   | `RunLocalTests`                                    |
| Tests passed | **29 / 29 (0 failures)**, 100% pass rate           |
| Test run ID  | `707Ru00002A7gs1`                                  |

This confirms the shipped permission set remains sufficient on its own
outside managed packaging, so the constraint below is specific to managed
installs rather than a defect in the permission set.

## Managed packaging strips system permissions

**This is a permanent Salesforce platform constraint, not a bug in this
app.** Salesforce removes system permissions from a managed package's
permission sets when the package is installed, as an anti-privilege-
escalation measure. The subscriber's own administrator must grant them.

Verified empirically from identical source:

| Install type             | `PermissionsViewSetup` on the installed permission set |
| ------------------------ | ------------------------------------------------------ |
| Source deploy / unlocked | `true`                                                 |
| **Managed**              | **`false`** (stripped on install)                      |

Consequences, all now reflected in the shipped app and docs:

- The shipped `Audit_Trail_Viewer` permission set still grants the app, its
  tab, and its Apex classes under managed packaging — **only** the system
  permissions are stripped.
- Subscribers must be granted **View Setup and Configuration** through their
  own profile or permission set, in addition to assigning
  `atexplorer__Audit_Trail_Viewer`.
- The Apex error message, the LWC empty state, the permission set
  description, and `README.md` state this explicitly.
- `AuditPermissionServiceTest` asserts the access gate opens _exactly when_
  the assigned permission set genuinely carries `ViewSetup`, which holds
  under both packaging models.

### The administrator workaround is verified, not just documented

Run in the managed subscriber org `00DRL00000Vkme62AB` against installed
managed beta `1.0.0.2`, using a throwaway local test class and a freshly
created **Minimum Access - Salesforce** user (not the org administrator, who
already holds `ViewSetup` via profile and would mask the result). The class
was deployed only to that scratch org and is deliberately not part of this
repository.

| Scenario                                                                           | Gate (`SetupAuditTrail.isAccessible()`) | Result |
| ---------------------------------------------------------------------------------- | --------------------------------------- | ------ |
| Installed `Audit_Trail_Viewer` alone (`PermissionsViewSetup` asserted `false`)     | closed                                  | Pass   |
| `Audit_Trail_Viewer` **plus** a separate local permission set granting `ViewSetup` | **open**                                | Pass   |

2 / 2 passed. This confirms end-to-end that a subscriber administrator
granting "View Setup and Configuration" separately does open the app, and
that the packaged permission set on its own does not — exactly as the README,
the listing draft, and the in-app messaging now state.

## Namespace / managed (2GP) package status

| Item                                  | Result                                             |
| ------------------------------------- | -------------------------------------------------- |
| Namespace registered                  | `atexplorer`                                       |
| Namespace linked to packaging Dev Hub | **Yes** — `NamespaceRegistry` `1NRhm0000000dcTGAQ` |
| Packaging Dev Hub                     | `00Dhm000004MOXjEAO`                               |
| Managed 2GP package created           | `0Hohm0000000NHZCA2`                               |

The namespace linkage that previously blocked managed packaging is
**resolved**. Note that the managed package lineage is permanently bound to
the Dev Hub above and cannot be moved to another Dev Hub later.

## Pre-submission re-verification — 2026-09-10

Everything below was re-run against the **released** version on 2026-09-10, at
source commit `934f200`, ahead of an AppExchange Security Review submission.
Three independent directions were used deliberately, because each can pass
while another fails: static analysis never executes the code, source-level
tests never exercise managed packaging, and subscriber-side tests never see
the source.

### Direction 1 — static analysis (code as written)

Salesforce Code Analyzer, 310 rules across 6 engines. **0 Critical, 0 High,
11 Moderate, 74 Low (85 total)**, no finding tagged `Security`, `AppExchange`
or `ErrorProne`. The Graph Engine completed **14,503 paths across 3/3 entry
points with 0 violations**, so `ApexFlsViolation` and
`DatabaseOperationsMustUseWithSharing` genuinely executed.

Full run records, including a first attempt whose Graph Engine result was
invalid and discarded, are in
[`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

### Direction 2 — source-level behaviour (unpackaged)

| Item              | Result                                             |
| ----------------- | -------------------------------------------------- |
| Org               | Scratch org, alias `src-qa` (`00DRu00000Xnmy8MAB`) |
| Deploy            | `force-app` deployed from commit `934f200`         |
| Test level        | `RunLocalTests`, with `--code-coverage`            |
| Tests passed      | **29 / 29 (0 failures)**, 100% pass rate           |
| Test run ID       | `707Ru00002ALud2`                                  |
| Org-wide coverage | **97%**                                            |
| Lowest class      | 95% (`AuditCursor`, `AuditQueryService`)           |

This independently confirms the "97%, no class below 95%" figure previously
known only from package build time.

### Direction 3 — packaged subscriber behaviour (managed install)

| Item                   | Result                                                        |
| ---------------------- | ------------------------------------------------------------- |
| Org                    | `rel-qa` (`00DRK00000aOfV72AK`)                               |
| Installed version      | `04thm000002OtQPAA0` — confirmed by query, the released one   |
| Test classes run       | The four `atexplorer.*` managed test classes                  |
| Tests passed           | **29 / 29 (0 failures)**, 100% pass rate                      |
| Test run ID            | `707RK0000BPbjPq`                                             |
| `PermissionsViewSetup` | **`false`** on the installed `atexplorer__Audit_Trail_Viewer` |
| `PermissionsViewRoles` | **`false`** on the same permission set                        |

The install-time system-permission strip is therefore re-confirmed against the
released version on this date, not inferred from the beta.

### Packaging state, read back from the Dev Hub

`sf package version report` against Dev Hub `partner-pbo`:

| Field                | Value                |
| -------------------- | -------------------- |
| Version              | `1.0.0.2`            |
| Subscriber version   | `04thm000002OtQPAA0` |
| `Released`           | **`true`**           |
| `Code Coverage`      | **97.00%**           |
| `Code Coverage Met`  | `true`               |
| `Validation Skipped` | `false`              |

**Superseded 2026-10-12.** `1.0.0.2` is no longer the latest released
version: `1.0.1.4` (`04thm000002tWirAAE`) was promoted on 2026-10-12 and the
same report now shows `Released = true` for it, with `1.0.0.2` as its
ancestor; see
[Packaging state after promotion](#packaging-state-after-promotion-read-back-from-the-dev-hub).
The values above still describe `1.0.0.2`, which remains released as the
previous version.

### Deterministic gate (what CI runs)

`npm run lint` clean, `npm run prettier:verify` clean,
`npm run test:unit:coverage` (the command the `Run LWC Jest tests` step in
`.github/workflows/ci.yml` runs) **7 / 7 Jest tests passing**.

**LWC coverage, fixed 2026-09-12.** `npm run test:unit:coverage` previously
instrumented nothing: it emitted an empty `coverage-final.json` (`{}`) and
reported 0% for every file while still exiting 0, so the CI coverage step
(`npm run test:unit:coverage`, which reports coverage and enforces no
threshold; `jest.config.js` sets no `coverageThreshold`) was green and
measuring nothing. Cause: the `sfdx-lwc-jest` preset's default
`collectCoverageFrom` globs every file under `lwc/` and negates only `.html`
and `.css`, leaving `.js-meta.xml` in the set; Istanbul cannot instrument
those and the whole run collapses to an empty report. `jest.config.js` now
restricts the glob to `.js` and excludes `__tests__`.

Measured result:

| File               | % Stmts   | % Branch | % Funcs | % Lines |
| ------------------ | --------- | -------- | ------- | ------- |
| `auditExplorer.js` | 70.64     | 64.78    | 55.73   | 71.50   |
| `csv.js`           | **100**   | **100**  | **100** | **100** |
| **All files**      | **72.16** | 68.75    | 57.81   | 73.09   |

`csv.js` — the CSV formula-injection control — is fully covered. The component
itself is not: **72.16% statements**, and the uncovered ranges in
`auditExplorer.js` (notably 301-332 and 342-381) are untested UI paths. No
coverage threshold is configured anywhere in this repository (`jest.config.js`
has no `coverageThreshold`), so this figure is reported, not enforced. It is
now a measured, visible number rather than a silent zero; raising it is
outstanding work, not something this change addressed.

## Install into a persistent Developer Edition org — 2026-09-13

Every managed install recorded above was into a **scratch** org, which expires
in days. This one is a persistent Developer Edition org, which is the shape of
org a security reviewer is given.

| Item                   | Result                                                         |
| ---------------------- | -------------------------------------------------------------- |
| Target org             | Developer Edition, `00Dbm00000u2XaoEAE` (not a sandbox)        |
| Installed version      | `04thm000002OtQPAA0` (subscriber package `033hm0000004c8LAAQ`) |
| Install result         | Succeeded                                                      |
| Namespaced classes     | 14 `atexplorer` Apex classes present                           |
| App / tab              | `atexplorer__Audit_Trail_Explorer` available                   |
| Permission set         | `atexplorer__Audit_Trail_Viewer` assigned successfully         |
| `PermissionsViewSetup` | **`false`**                                                    |
| `PermissionsViewRoles` | **`false`**                                                    |
| Apex tests             | **29 / 29 passed**, 100% pass rate, run ID `707bm00001FTsEQ`   |

This is the **third independent confirmation** of the install-time system
permission strip (after `00DRL00000Vkme62AB` and `00DRK00000aOfV72AK`), and
the first in a non-scratch org — so the behaviour is a property of managed
packaging, not of scratch orgs.

The org's System Administrator profile carries `PermissionsViewSetup = true`,
so that user satisfies both required grants: the packaged permission set for
app/tab/Apex access, and the profile for "View Setup and Configuration".

### Editions without custom Apex cannot install this package

Attempted install of the same version into a **Base Edition** org
(`00Dao00001QqmInEAJ`) failed:

```
Error (PackageInstallError): Encountered errors installing the package!
1) Apex Classes(classes/AuditPermissionService.cls) Missing feature,
   Details: Installing this package requires the following feature and its
   associated permissions: Apex Classes
```

This is an edition limitation, not a package defect — the same root cause that
rules out Professional Edition. `README.md`, `docs/ARCHITECTURE.md` and the
listing draft now name Base Edition explicitly.

## Functional UI verification of the managed install — 2026-09-13

Driven through the browser against the **installed managed package** in
`00DRK00000aOfV72AK` (not source, not a mock). To exercise paging honestly,
65 permission sets were inserted in a single Apex transaction, producing 65
audit rows sharing one identical timestamp, so the 50-row page boundary fell
**inside** that block — the case date-only paging would duplicate or skip.

| Check                       | Result                                                               |
| --------------------------- | -------------------------------------------------------------------- |
| App loads from App Launcher | `atexplorer__Audit_Trail_Explorer` renders                           |
| Default search              | 50 events, streaming progress message                                |
| Section filter              | 53 examined → 6 events; all 6 rows genuinely `Manage Users`          |
| Free-text search            | "transaction security" → 2 events                                    |
| User filter (type-ahead)    | → 15 events, matching the org's true count for that user             |
| Facets                      | Top sections / top users correct, recomputed per search              |
| Row detail                  | Date, User, Section, Action, Description, Delegate user, Namespace   |
| Paging to completion        | 50 → 100 → **118**, "Search complete"                                |
| CSV export                  | **118 data rows, 0 duplicate rows**, CRLF, every cell quoted         |
| Escaping                    | `"quoted"` → `""quoted""`; comma and unicode labels preserved        |
| Empty state                 | "No audit events matched your filters in this range."                |
| Retention notice            | "Salesforce retains Setup Audit Trail for 180 days…" shown in the UI |

118 exported rows against 118 rows in the org, with zero duplicates, was a live
confirmation of the `1.0.0.2` cursor's seen-ids design. `1.0.1` replaced that
design with keyset paging on `(CreatedDate, Id)`; see "2026-10-12 - Release
1.0.1 validation" below.

Two observations, neither a defect:

- The section facet lists **8** entries while the org had 10 distinct sections
  (102 non-blank rows). That is `auditExplorer.js`'s deliberate
  `.slice(0, 8)` cap plus `computeFacets` skipping blank keys, not a miscount.
- The CSV formula-injection guard never fires on real audit text: trigger
  characters appear mid-string ("Created permission set … =1+1 …"), and the
  guard matches position 0 only. It is defence-in-depth for values such as a
  display name beginning with `=`, and is covered by Jest at 100% of `csv.js`.

> The audit trail of `00DRK00000aOfV72AK` permanently contains the ~65 seeded
> "ATE Bulk" entries; Setup Audit Trail is append-only. Do not use that org for
> listing screenshots.

## 2026-10-11 - Local reproduction and pre-submission audit

Everything in this section was run on one Windows 11 workstation (7.72 GB RAM)
at source commit `f27a009`. **No Salesforce org was authenticated on that
workstation, so nothing org-dependent was re-run**: the install records, Apex
test runs and permission-set observations above stand as recorded on their own
dates. Nothing here is a review outcome; the package remains not submitted,
not reviewed and not listed.

### Toolchain

| Item                 | Value                                                    |
| -------------------- | -------------------------------------------------------- |
| Node / npm           | 24.20.0 / 11.19.0                                        |
| Salesforce CLI       | `@salesforce/cli` 2.153.5 win32-x64                      |
| Code Analyzer plugin | 5.16.0                                                   |
| JDK                  | OpenJDK 21.0.12.1 (Microsoft build)                      |
| Python               | 3.12.10, installed after scans A and B and before scan C |

### Source is unchanged since the released build

`git diff --stat v1.0.0..HEAD -- force-app sfdx-project.json` is empty. Tag
`v1.0.0` is commit `934f200`, the source that built released version `1.0.0.2`
(`04thm000002OtQPAA0`); the seven commits since the tag (`4f50909` through
`f27a009`) touch documentation, CI and configuration only. Every org-side
result recorded above therefore still describes the shipped code.

### Deterministic gates

`npm run lint` passes, `npm run prettier:verify` passes and
`npm run test:unit:coverage` passes: Jest **7 / 7**, `auditExplorer.js` 70.64%
statements, `csv.js` 100%. These are the figures already tabulated under
"Deterministic gate" above; nothing moved.

### Code Analyzer

Three scans, recorded in full in
[`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

**Scan A — repository selector, all engines (18:41-18:51 local).**
`sf code-analyzer run --config-file code-analyzer.yml --workspace force-app
--rule-selector Recommended --rule-selector Security --rule-selector
AppExchange --severity-threshold 2` ran against a selector that resolved to
**310 rules from 6 engines** (eslint 202, pmd 94, regex 6, retire-js 4, cpd 2,
sfge 2; the same count before and after Python was installed) and produced the
**85 code violations identical rule-for-rule and count-for-count to the
2026-09-19 record** (0 Critical, 0 High, 11 Moderate, 74 Low). It also
reported one Critical `UninstantiableEngineError` from the `flow` engine
("Could not locate a Python v3.10.0+ install"), an engine-instantiation error
with no file rather than a code finding, which is why the run exited 1 with 86
entries in `ca-report.json`. Inside this same run the Graph Engine completed —
"analyzed 14503 path(s) from 3 entry point(s). Detected 0 violation(s)" — with
a 2g heap and 4 threads while host free memory was about 0.7-0.8 GB.

**Scan B — Graph Engine alone (18:51-19:01 local).** Same configuration with
`--rule-selector sfge`: "Detected 0 violation(s) from 14503 path(s) on 3/3
entry point(s)", which meets this repository's validity bar (full path count,
3/3 entry points, no `Internal execution error`). The only violation it
printed was the same flow `UninstantiableEngineError`.

**Scan C — Salesforce's official AppExchange command.** Run after Python
3.12.10 was installed, from a clean git worktree at commit `934f200` (no
`node_modules`, no `--config-file`, no `--workspace`, from the package
top-level directory): `sf code-analyzer rules --rule-selector AppExchange
--rule-selector Recommended:Security` resolved to **62 rules from 5 engines**
(pmd 51, retire-js 4, eslint 3, flow 3, regex 1; no sfge, no cpd), and
`sf code-analyzer run --rule-selector AppExchange --rule-selector
Recommended:Security --output-file CodeAnalyzerReport.html` finished with exit
0 and **"Found 0 violations."** (regex, retire-js, pmd and eslint executed;
flow had no Flow files to scan). The report is kept by the maintainer outside
the repository (`CodeAnalyzerReport.html` is gitignored); its SHA-256 is
`5C05B155418A8A1BE3FA2FF77132260F3B62E628380B25AFA4DC293D93C9169E`.

**Why CI never saw the flow error.** The Code Analyzer flow engine needs
Python 3.10+, which GitHub's `ubuntu-latest` runner preinstalls and this
workstation did not have; with `--workspace force-app` the flow engine is not
eligible anyway (no Flow metadata), so the repository selector still counts
310 rules from 6 engines on CI and locally.

### Readiness audit

A pre-submission audit reviewed the code, metadata and documents across eight
dimensions (access control, injection, LWC client, data handling, tests,
packaging, documentation consistency, runtime robustness), and every candidate
finding was judged by three independent verifiers against the source. **67
candidates: 63 confirmed (0 blocker, 0 high, 12 medium, 41 low, 10 info), 4
rejected.** The confirmed items, their fixes and the submission procedure are
in [`SECURITY-REVIEW-SUBMISSION.md`](SECURITY-REVIEW-SUBMISSION.md).

## 2026-10-12 - Release 1.0.1 validation

Release 1.0.1 is the first code change since `1.0.0.2`. The released version,
`1.0.1.4`, was built from commit `f0ad675` on branch `release/1.0.1`. The
commit tagged `v1.0.1` differs from it only outside `force-app` (the
`1.0.1.4` alias in `sfdx-project.json`, the pinned path count in
`.github/workflows/code-analyzer.yml`, and the documentation;
`git diff --stat f0ad675..v1.0.1 -- force-app` is empty), so every result
below describes the tagged code. The LWC is byte-identical across all
four 1.0.1 builds (`git diff 47bd65f..HEAD -- force-app/main/default/lwc` is
empty); the three rebuilds after `1.0.1.1` changed Apex and configuration
only.

Nothing in this section is a review outcome. The package remains **not
submitted** for AppExchange Security Review, **not reviewed** and **not
listed**; "released" below is the Salesforce packaging state only.

### What the validation exercises

The behaviour changes the steps below touch, located in the shipped source:

- Paging is keyset-based on `(CreatedDate, Id)`. The cursor carries the last
  consumed `lastDateMillis`/`lastId` pair instead of a list of seen ids
  (`AuditCursor.cls`), the query resumes with
  `AND (CreatedDate < :upperBound OR Id < :lastId)` and orders by
  `CreatedDate DESC, Id DESC` (`SetupAuditTrailProvider.cls:27`, `:35`), and a
  continuation cursor whose id is blank, malformed or not a `SetupAuditTrail`
  id is rejected before any query runs (`AuditCursor.cls:53`).
- The date range is owned by the server. A preset sends `AuditFilter.lastDays`
  (`AuditFilter.cls:22`); the first call of a search resolves the window from
  the server clock and pins it in the cursor (`AuditQueryService.cls:200`);
  continuation calls page over that window after re-clamping it to the
  retention floor (`AuditQueryService.cls:67` onwards). Free text is bounded
  to 200 characters and 10 terms (`AuditQueryService.cls:47-48`).
- Every controller entry point throws only `AuraHandledException`: the
  permission message is passed through with `setMessage`
  (`AuditQueryController.cls:101`), everything else collapses to the generic
  text, and `getContext` and `searchUsers` are `cacheable=false`
  (`AuditQueryController.cls:40`, `:59`).
- In the LWC, removing a user pill works because the `itemremove` handler
  reads `detail.item` and `detail.index` (`auditExplorer.js:411`); the filter
  of the running search is snapshotted (`auditExplorer.js:269`) so "Search
  further back" continues it, and edits made since show the hint "Filters
  changed. Click Search to apply them; Search further back continues the
  current search." (`auditExplorer.js:47`, `auditExplorer.html:127`); access
  is tri-state - a spinner until `getContext` answers, the denied message, or
  the error alone (`auditExplorer.html:258` onwards); Export CSV is enabled
  only with rows and confirmed access (`auditExplorer.js:534`); the CSV starts
  with the UTF-8 BOM (`auditExplorer.js:46`); "Today" is now "Last 24 hours"
  (`auditExplorer.js:33`).
- The shipped permission set still declares `ViewSetup` and `ViewRoles` for
  source deploys; its description now says a managed install strips them
  (`Audit_Trail_Viewer.permissionset-meta.xml:4-5`).
- 50 Apex test methods (was 29) across the four test classes; 26 Jest tests
  (was 7).

### Source deploy of the final commit - `ate-101`

| Item               | Result                                                                                                                                                                                 |
| ------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Org                | Namespaced scratch org, alias `ate-101`, org ID `00Dh100000146fmEAA`, created 2026-10-11, expires 2026-10-19                                                                           |
| Deploy             | `force-app` from commit `f0ad675`, deploy ID `0Afh1000000NfiTCAS`                                                                                                                      |
| Components         | 18 / 18                                                                                                                                                                                |
| Test level         | `RunLocalTests`                                                                                                                                                                        |
| Tests passed       | **50 / 50 (0 failures)**                                                                                                                                                               |
| Per-class coverage | `AuditCursor` 100%, `AuditQueryController` 92%, `AuditSearchResult` 100%, `AuditQueryService` 96%, `AuditPermissionService` 100%, `AuditEventRow` 100%, `SetupAuditTrailProvider` 100% |

`AuditFilter` has had no executable lines since `f05ed25` removed its two
unused date helpers, so it no longer appears in the coverage table. The lowest
class is `AuditQueryController` at 92%.

Earlier `RunLocalTests` deploys of the branch into the same org, for
traceability:

| Source                                                | Deploy ID                                                                         | Result                                                                                                                   |
| ----------------------------------------------------- | --------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `f27a009` (`main`, the `1.0.0.2` baseline)            | `0Afh1000000N46ACAS`                                                              | 18 / 18 components, 29 run, 0 failed                                                                                     |
| `47bd65f` (the 1.0.1 code release)                    | `0Afh1000000N92fCAC`                                                              | 50 run, 0 failed                                                                                                         |
| Branch, before two cursor-validation tests were added | `0Afh1000000NFpZCAW`                                                              | 48 run, 0 failed                                                                                                         |
| `41e2a29` (source of `1.0.1.2`)                       | `0Afh1000000NGdZCAW`                                                              | 18 / 18 components, 50 run, 0 failed; `AuditQueryService` 97%, `AuditFilter` 100%, every other class as in the final run |
| `f05ed25` (source of `1.0.1.3`)                       | `0Afh1000000NLdGCAW` (restructuring), `0Afh1000000NI7XCAW` (dead helpers removed) | 50 run, 0 failed, each                                                                                                   |

### Manual UI smoke test - 2026-10-12

Performed with browser automation - not by a human - against the source
deploy in `ate-101` and the managed install in `ate-mgd`. No screenshots were
kept, so this pass produced no listing assets; the checklist records that part
separately.

**In `ate-101` (source deploy of the 1.0.1 code), as the administrator:**

| Check                                     | Result                                                                                                                                                                    |
| ----------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tab loads                                 | Renders with data                                                                                                                                                         |
| User type-ahead                           | Returns active users; selecting one adds a pill                                                                                                                           |
| Pill removal                              | Clicking the pill's x removes it - the `1.0.0.2` defect is gone                                                                                                           |
| Filter edited after a search              | The hint "Filters changed. Click Search to apply them; Search further back continues the current search." appears                                                         |
| "Search further back" with a pending edit | Continued the original search: rows 50 -> 64, progress "Search complete - examined 64 events back to <range boundary>"; the pending non-matching term was **not** applied |
| Enter in the search box                   | Applied the pending term: 0 events, the empty state, hint cleared                                                                                                         |

**In `ate-101` via Login As, as a Minimum Access - Salesforce user holding only
the packaged `Audit_Trail_Viewer` permission set:** the full app loads. In a
source deploy the permission set's `ViewSetup` entry is honoured, as the
documentation says - the source-deploy row of the table under
[Managed packaging strips system permissions](#managed-packaging-strips-system-permissions),
now seen in the UI.

**In `ate-mgd` (managed install of `1.0.1.1`) via Login As, as the same kind of
user holding only `atexplorer__Audit_Trail_Viewer`:**

| Grants held                                                                                                   | Result                                                                                                             |
| ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `atexplorer__Audit_Trail_Viewer` only                                                                         | The denied message that names "View Setup and Configuration" in place of the form; Export CSV disabled; no spinner |
| Plus a local permission set `ATE_Local_View_Setup` (`PermissionsViewSetup=true`, `PermissionsViewRoles=true`) | The app loaded with data (50 events) for that user                                                                 |

This is the two-grant sequence `README.md` describes, observed in the UI
rather than only through the throwaway test class recorded under
[The administrator workaround is verified, not just documented](#the-administrator-workaround-is-verified-not-just-documented).
The LWC installed by `1.0.1.1` is the one shipped in `1.0.1.4` (see the diff
note at the top of this section), so the UI behaviour carries over; the Apex
behind it was re-tested in the same org on `1.0.1.4` (below).

**Org setup this test needs.** A Minimum Access - Salesforce user in a scratch
or Developer Edition org also needs the **Lightning Experience User**
permission before Lightning Experience itself loads; without it the login
ends at "You can't access Lightning Experience". Login As requires
**Administrators Can Log in as Any User** (Setup > Login Access Policies).
`docs/USER-GUIDE.md` ("Setting up a test user for reviewers") covers the rest
of the test-user setup.

### Package version `1.0.1.4` (`04thm000002tWirAAE`)

| Item                         | Result                                                                     |
| ---------------------------- | -------------------------------------------------------------------------- |
| Package (2GP, managed)       | `Audit Trail Explorer` — `0Hohm0000000NHZCA2`, namespace `atexplorer`      |
| Package version              | `1.0.1.4` (`04thm000002tWirAAE`; `Package2VersionId` `05ihm0000001CK5AAM`) |
| Built                        | 2026-10-12, from commit `f0ad675`                                          |
| Ancestor                     | `1.0.0.2` (`04thm000002OtQPAA0`)                                           |
| Package coverage             | 96% (authoritative figure, measured at package build time)                 |
| `HasPassedCodeCoverageCheck` | `true`                                                                     |
| Dev Hub                      | `partner-pbo` / `00Dhm000004MOXjEAO`                                       |

Install URL (for a sandbox, swap `login.salesforce.com` for
`test.salesforce.com`):

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04thm000002tWirAAE
```

Or from the CLI:

```bash
sf package install --package 04thm000002tWirAAE --target-org my-org --wait 20
sf org assign permset --name atexplorer__Audit_Trail_Viewer --target-org my-org
```

#### Superseded 1.0.1 betas

Three earlier 1.0.1 builds were created on 2026-10-12, each at 96% coverage
with `HasPassedCodeCoverageCheck=true`, each a beta that was never promoted.
They are kept in `sfdx-project.json`'s package aliases for traceability; the
subscriber org below was upgraded through all four in sequence.

| Version   | Id                   | Source                                         | Why it was superseded                                                                                                                                                                                                                                                                                                                                   |
| --------- | -------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `1.0.1.1` | `04thm000002tVurAAE` | `d931ba7` (`force-app` identical to `47bd65f`) | Its Graph Engine run flagged `sfge:ApexNullPointerException` on `working.lastIdValue()`, a false positive from a null check that had moved into a separate Boolean the path analysis cannot correlate; fixed in `41e2a29`.                                                                                                                              |
| `1.0.1.2` | `04thm000002tVwTAAU` | `41e2a29`                                      | The standalone Graph Engine run could not finish: `AuditQueryController.search` timed out at the stock 600 s per-path budget and again at a diagnostic 1,800 s, printing a vacuous "0 violations". Cause: path explosion from conditionals 1.0.1 had added inside the per-row scan loop; fixed in `f05ed25` with the same behaviour and fewer branches. |
| `1.0.1.3` | `04thm000002tVy5AAE` | `f05ed25`                                      | Still timed out at 1,800 s; the remaining multipliers were in the cursor normalisation before the scan loop. Fixed in `f0ad675`, which also sizes the Graph Engine budget for the code (`code-analyzer.yml` `java_thread_timeout` 1,800,000 ms).                                                                                                        |

### Managed install into a clean subscriber org - `ate-mgd`

| Item                                            | Result                                                                                                                                                   |
| ----------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Target org                                      | Clean, un-namespaced scratch org, alias `ate-mgd`, org ID `00Ddi00000EXdFSEA1`, created 2026-10-12, expires 2026-10-19, no packages installed beforehand |
| Install `1.0.1.1`                               | Request `0Hfdi000002FareCAC`, `SUCCESS`                                                                                                                  |
| Upgrade to `1.0.1.2`                            | Request `0Hfdi000002FhebCAC`, `SUCCESS`                                                                                                                  |
| Upgrade to `1.0.1.3`                            | Request `0Hfdi000002FiKYCA0`, `SUCCESS`; `InstalledSubscriberPackage` showed `04thm000002tVy5AAE`, build 3                                               |
| Upgrade to `1.0.1.4`                            | Request `0Hfdi000002FyKTCA0`, `SUCCESS`; `InstalledSubscriberPackage` shows `04thm000002tWirAAE`, build 4                                                |
| `PermissionsViewSetup` / `PermissionsViewRoles` | **`false` / `false`** on the installed `atexplorer__Audit_Trail_Viewer` after every one of the four installs                                             |

The install-time system-permission strip is therefore re-confirmed on 1.0.1,
against the released `1.0.1.4` as well as the three betas.

Apex tests in the subscriber org, run with `RunAllTestsInOrg` (the test level
that selects installed managed tests, per the 2026-10-11 correction above):

| Installed version | Test run ID       | Result                  |
| ----------------- | ----------------- | ----------------------- |
| `1.0.1.1`         | `707di0000LCGPxR` | 50 passed, 0 failed     |
| `1.0.1.2`         | `707di0000LCGvO4` | 50 passed, 0 failed     |
| `1.0.1.3`         | `707di0000LCHRya` | 50 passed, 0 failed     |
| `1.0.1.4`         | `707di0000LCKGo0` | **50 passed, 0 failed** |

Org-wide coverage reads 0% in `ate-mgd` because Salesforce does not expose
managed-package coverage to subscriber orgs; the build-time 96% is the
meaningful figure. The denied-then-granted UI sequence for a Minimum Access
user in this org is recorded under the smoke test above.

**Operational note.** For about 15 minutes after `sf package version create`
the new version was not yet visible to the subscriber org, and
`sf package install` failed with "No record found ... FROM
SubscriberPackageVersion". The install succeeded once the Tooling API in that
org returned the version (`InstallValidationStatus` `NO_ERRORS_DETECTED`).

### Promotion to released - 2026-10-12

`sf package version promote --package 04thm000002tWirAAE --target-dev-hub
partner-pbo` succeeded on 2026-10-12 at 19:23 local time (America/Chicago).
Promotion is irreversible and consumes the version number permanently.

#### Packaging state after promotion, read back from the Dev Hub

`sf package version report` against Dev Hub `partner-pbo`:

| Field               | Value                |
| ------------------- | -------------------- |
| Version             | `1.0.1.4`            |
| Subscriber version  | `04thm000002tWirAAE` |
| `Released`          | **`true`**           |
| `Ancestor Version`  | `1.0.0.2`            |
| `Code Coverage`     | **96%**              |
| `Code Coverage Met` | `true`               |

`1.0.1.4` is therefore the current released managed version and the version
to submit for AppExchange Security Review. `1.0.0.2` remains released as the
previous version; `1.0.1.1`, `1.0.1.2` and `1.0.1.3` remain unreleased betas.
"Released" is the Salesforce packaging state only: the package is still **not
submitted** for, **not reviewed** by and **not listed** on AppExchange.

### Customer upgrade path: `1.0.0.2` to `1.0.1.4` - `ate-upg`

`ate-mgd` reached `1.0.1.4` through the three 1.0.1 betas. Existing customers
will upgrade directly from the previous released version, so that path was
exercised separately after promotion, in a fresh org.

| Item                                            | Result                                                                                                                                                     |
| ----------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Target org                                      | Clean, un-namespaced scratch org, alias `ate-upg`, org ID `00Dcb00000QrxpMEAR`, created 2026-10-12 (02:31 UTC 2026-10-13), expires 2026-10-16, no packages |
| Install `1.0.0.2` (`04thm000002OtQPAA0`)        | Request `0Hfcb000003fCBZCA2`, `SUCCESS`                                                                                                                    |
| Upgrade to `1.0.1.4` (`04thm000002tWirAAE`)     | Request `0Hfcb000003fCDBCA2`, `SUCCESS`; `InstalledSubscriberPackage` shows `04thm000002tWirAAE`, `1.0.1.4`, `IsBeta` `false`                              |
| Apex classes after the upgrade                  | The same 14 `atexplorer` classes as `1.0.0.2`; 1.0.1 adds and removes none                                                                                 |
| `PermissionsViewSetup` / `PermissionsViewRoles` | **`false` / `false`** on the upgraded `atexplorer__Audit_Trail_Viewer`, whose description now reads as in 1.0.1 (managed installs strip both)              |
| `RunAllTestsInOrg` after the upgrade            | Run `707cb00001ioLh6`: **50 passed, 0 failed** (the 1.0.1 test suite, as upgraded)                                                                         |

### Deterministic gates and static analysis on the same source

`npm run lint` clean, `npm run prettier:verify` clean, Jest **26 / 26** (was
7). Measured with Jest's v8 coverage provider, `auditExplorer.js` is at 95.16%
statements, 79.34% branches, 95.65% functions and 94.84% lines, and `csv.js`
at 100%; the stock Babel provider reports an empty table when run inside a git
worktree on this machine, a measurement quirk rather than a code problem. No
coverage threshold is enforced, as before.

Salesforce Code Analyzer on `f0ad675` (plugin 5.16.0, run 2026-10-12 after
`npm ci`, which the repository's `code-analyzer.yml` needs for its ESLint
config): Salesforce's official AppExchange command resolved 62 rules from 5
engines and reported **"Found 0 violations."**; the repository's three-tag
union (310 rules, 6 engines) exited 0 with 0 Critical, 0 High, 13 Moderate and
106 Low, none tagged `Security`, `AppExchange` or `ErrorProne`; and the
standalone Graph Engine run completed **6,537 paths over 3/3 entry points**
(down from 14,503 on `1.0.0.2` because of the branch trimming; the workflow
now pins 6537) with 0 violations from the two Security-tagged rules. Its
single `AvoidDatabaseOperationInLoop` finding is the bounded, time-sliced
batch loop the application exists for, and is accepted. The
`CodeAnalyzerReport.html` to upload for `1.0.1.4` has SHA-256
`03E6CE52D69C7A26A3D5EA2F40B68AF7EA6655A17957F5CE95FA6C534532BA1C` (64,954
bytes) and is kept by the maintainer outside the repository. Scan records live
in [`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).

## Remaining manual/live checklist

- [x] ~~Link the `atexplorer` namespace to the packaging Dev Hub~~ — done
      (`1NRhm0000000dcTGAQ`).
- [x] ~~Create a 2GP managed package from this source under the linked
      namespace~~ — done (`0Hohm0000000NHZCA2`).
- [x] ~~Validate install of the managed package version into a clean org~~ —
      done for managed beta `1.0.0.2` into `00DRL00000Vkme62AB`; done again
      2026-10-12 for `1.0.1.4` (`04thm000002tWirAAE`) into `ate-mgd`
      (`00Ddi00000EXdFSEA1`), install request `0Hfdi000002FyKTCA0`.
- [x] ~~Run Apex tests against the managed package version in a subscriber
      org~~ — done: 29/29 on `1.0.0.2`; 50/50 on `1.0.1.4`, run
      `707di0000LCKGo0`.
- [x] ~~Live verification that the documented administrator workaround
      actually works~~ — done in the managed subscriber org
      `00DRL00000Vkme62AB`, see below; observed again through the UI on
      2026-10-12 in `ate-mgd` (managed `1.0.1.1`): denied with the packaged
      permission set alone, open after a local permission set granting
      `ViewSetup` was added.
- [x] ~~Live UI smoke test of the managed install~~ — done 2026-10-12 to this
      extent: the source deploy in `ate-101` (as the administrator, and as a
      Minimum Access user via Login As) and the managed install of `1.0.1.1`
      in `ate-mgd` (Minimum Access user via Login As, denied then granted),
      performed with browser automation rather than by a human; no screenshots were kept. See
      [Manual UI smoke test](#manual-ui-smoke-test---2026-10-12).
- [ ] Human-driven UI pass of the managed install for screenshots and listing
      assets - the part of the previous item that the 2026-10-12 pass did not
      produce.
- [x] ~~Promote a managed package version from beta to released~~ — done
      2026-09-09: `1.0.0.2` (`04thm000002OtQPAA0`), and 2026-10-12: `1.0.1.4`
      (`04thm000002tWirAAE`), both on Dev Hub `partner-pbo`. Irreversible; the
      version numbers are permanently consumed.
- [ ] Submit the released managed package version `1.0.1.4`
      (`04thm000002tWirAAE`) for AppExchange Security Review.
- [ ] After review approval: add the listing URL and the review outcome, in
      Salesforce's own words, to `README.md`, `docs/APPEXCHANGE-LISTING.md`
      and this file. (The install URL for `04thm000002tWirAAE` is recorded
      under "Package version `1.0.1.4`" above.)

**Current state: released managed 2GP version `1.0.1.4`
(`04thm000002tWirAAE`), promoted 2026-10-12; `1.0.0.2` remains released as the
previous version. Not submitted for AppExchange Security Review. No
AppExchange listing.**

"Released" is the Salesforce packaging state and nothing more: the version
installs into any org type including production and carries normal managed
upgrade guarantees. It is not a review outcome and confers no Salesforce
endorsement. Do not describe this package as "certified", "approved",
"security reviewed", or "on AppExchange" in any listing, documentation, or
marketing copy — none of those are true today, and only the AppExchange
review process can make them true.
