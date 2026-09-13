# Live-Org Validation Record

This file tracks validation steps that require a live Salesforce org/Dev Hub
and therefore cannot be run from this repository's CI. It is updated by
whoever performs each step, with the concrete evidence (org, test run id,
report values) rather than a bare pass/fail, so the record stays auditable.

**Status:** managed 2GP version `1.0.0.2` is a **released** package version,
promoted 2026-09-09. Nothing below constitutes an AppExchange security review
approval, certification, or listing — "released" is the Salesforce packaging
state only. See
[`docs/APPEXCHANGE-LISTING.md`](APPEXCHANGE-LISTING.md) for the claims policy.

## Package install validation

### Current: RELEASED managed 2GP `1.0.0.2` (`04thm000002OtQPAA0`) — 2026-09-09

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

### Current: RELEASED managed `1.0.0.2` in the subscriber org — 2026-09-09

| Item              | Result                                                      |
| ----------------- | ----------------------------------------------------------- |
| Org               | `rel-qa` (`00DRK00000aOfV72AK`), released package installed |
| Test level        | `RunLocalTests`                                             |
| Tests passed      | **29 / 29 (0 failures)**, 100% pass rate                    |
| Test run ID       | `707RK0000BPQrG1`                                           |
| Test classes      | Ran as namespaced `atexplorer.*` classes                    |
| Org-wide coverage | Not meaningfully reported for managed code — see note below |

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

### Current: source deploy of the same commit — 2026-09-09

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

### Deterministic gate (what CI runs)

`npm run lint` clean, `npm run prettier:verify` clean, `npm run test:unit`
**7 / 7 Jest tests passing**.

**LWC coverage, fixed 2026-09-12.** `npm run test:unit:coverage` previously
instrumented nothing: it emitted an empty `coverage-final.json` (`{}`) and
reported 0% for every file while still exiting 0, so the CI coverage step was
green and measuring nothing. Cause: the `sfdx-lwc-jest` preset's default
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
itself is not: **72.16% statements is below this project's >85% target**, and
the uncovered ranges in `auditExplorer.js` (notably 301-332 and 342-381) are
untested UI paths. This is now a measured, visible number rather than a silent
zero; raising it is outstanding work, not something this change addressed.

## Remaining manual/live checklist

- [x] ~~Link the `atexplorer` namespace to the packaging Dev Hub~~ — done
      (`1NRhm0000000dcTGAQ`).
- [x] ~~Create a 2GP managed package from this source under the linked
      namespace~~ — done (`0Hohm0000000NHZCA2`).
- [x] ~~Validate install of the managed package version into a clean org~~ —
      done for managed beta `1.0.0.2` into `00DRL00000Vkme62AB`.
- [x] ~~Run Apex tests against the managed package version in a subscriber
      org~~ — done: 29/29.
- [x] ~~Live verification that the documented administrator workaround
      actually works~~ — done in the managed subscriber org
      `00DRL00000Vkme62AB`, see below.
- [ ] Live UI smoke test of the managed install by a human, for
      screenshots and listing assets.
- [x] ~~Promote a managed package version from beta to released~~ — done
      2026-09-09: `1.0.0.2` (`04thm000002OtQPAA0`), Dev Hub `partner-pbo`.
      Irreversible; the version number is permanently consumed.
- [ ] Submit the released managed package version for AppExchange Security
      Review.
- [ ] Only after security review approval: update `README.md`,
      `docs/APPEXCHANGE-LISTING.md`, and this file to reference the released
      managed package's install URL.

**Current state: released managed 2GP version `1.0.0.2`. Not submitted for
AppExchange Security Review. No AppExchange listing.**

"Released" is the Salesforce packaging state and nothing more: the version
installs into any org type including production and carries normal managed
upgrade guarantees. It is not a review outcome and confers no Salesforce
endorsement. Do not describe this package as "certified", "approved",
"security reviewed", or "on AppExchange" in any listing, documentation, or
marketing copy — none of those are true today, and only the AppExchange
review process can make them true.
