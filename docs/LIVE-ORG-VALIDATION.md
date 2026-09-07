# Live-Org Validation Record

This file tracks validation steps that require a live Salesforce org/Dev Hub
and therefore cannot be run from this repository's CI. It is updated by
whoever performs each step, with the concrete evidence (org, test run id,
report values) rather than a bare pass/fail, so the record stays auditable.

**Status:** in progress. Nothing below constitutes an AppExchange security
review approval, certification, or managed-package release — see
[`docs/APPEXCHANGE-LISTING.md`](APPEXCHANGE-LISTING.md) for the claims policy.

## Package install validation

### Current: package version `1.0.0.2` (`04tbm000000gaALAAY`)

Built from this exact source commit.

| Item                         | Result                                                                                                  |
| ---------------------------- | ------------------------------------------------------------------------------------------------------- |
| Package version              | `1.0.0.2` (`04tbm000000gaALAAY`)                                                                        |
| Package-version request      | `08cbm000000JDHhAAO`                                                                                    |
| Metadata files               | 43                                                                                                      |
| Package coverage             | 97%                                                                                                     |
| `HasPassedCodeCoverageCheck` | `true`                                                                                                  |
| Validation skipped           | `false` (validation ran)                                                                                |
| Target org                   | Clean active QA scratch org, alias `qa`, org ID `00DO500000q61ptMAA` (no packages installed beforehand) |
| Install request              | `0HfO50000041ge1KAA`                                                                                    |
| Install result               | Succeeded                                                                                               |
| Permission set assigned      | `Audit_Trail_Viewer` — assigned successfully                                                            |

### Superseded: package version `1.0.0.1` (`04tbm000000aeOjAAI`)

Retained for historical traceability only; do not install this version - see
[README.md](../README.md#install-development-test-orgs-only--unreleased-beta).

| Item                    | Result                                       |
| ----------------------- | -------------------------------------------- |
| Target org              | `orgfarm-dev-ed`                             |
| Install result          | Succeeded                                    |
| Permission set assigned | `Audit_Trail_Viewer` — assigned successfully |

## Apex test run (RunLocalTests)

### Current: package version `1.0.0.2`

| Item                   | Result                                                                                               |
| ---------------------- | ---------------------------------------------------------------------------------------------------- |
| Test run id            | `707O500002wjQxU`                                                                                    |
| Tests passed           | **28 / 28 (0 failures)**                                                                             |
| Org-wide coverage      | 97%                                                                                                  |
| Package version report | `IsReleased=false`, `ValidationSkipped=false`, `CodeCoverage=97%`, `HasPassedCodeCoverageCheck=true` |

This reconciles the note below: the full 28 `@IsTest` methods present in this
source (across `AuditPermissionServiceTest`, `AuditQueryControllerTest`,
`AuditQueryServiceTest`, and `SetupAuditTrailProviderTest`) all ran and
passed against package version `1.0.0.2`, confirming the 22/22 result
recorded for `1.0.0.1` below reflected that earlier, superseded build rather
than any discrepancy in the current source.

Tooling API additionally confirmed the LWC bundle installed with this
package version includes both fixes from this PR: `csv.js` recognizes
full-width formula-trigger characters, and `auditExplorer.js` computes
facets from the accumulated row set (`computeFacets`).

### Superseded: package version `1.0.0.1`

| Item                         | Result                                                                                               |
| ---------------------------- | ---------------------------------------------------------------------------------------------------- |
| Test run id                  | `707bm00001DpAzr`                                                                                    |
| Tests passed                 | 22 / 22 (0 failures)                                                                                 |
| Test-run / org-wide coverage | 97%                                                                                                  |
| Package version report       | `IsReleased=false`, `ValidationSkipped=false`, `CodeCoverage=97%`, `HasPassedCodeCoverageCheck=true` |

## Namespace / managed (2GP) package status

| Item                                  | Result                                                                                                                                                                                                                                                                                                                                                                              |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Namespace registered                  | `atexplorer` (in the `nsorg` org)                                                                                                                                                                                                                                                                                                                                                   |
| Namespace linked to packaging Dev Hub | **Not yet** — `pbo2` (the Dev Hub used for packaging) currently has **zero** `NamespaceRegistry` records                                                                                                                                                                                                                                                                            |
| Root cause                            | A platform-level defect in the SalesforceDX Namespace Registry's OAuth/PKCE flow currently prevents linking the registered namespace to the packaging Dev Hub. This is a Salesforce platform issue, not a configuration mistake in this org or repository, and is outside the control of this codebase.                                                                             |
| Blocker                               | Namespace linkage to the Dev Hub is the current blocker for creating a new managed (2GP) package. As documented in the [README](../README.md#packaging-status) and [`docs/ARCHITECTURE.md`](ARCHITECTURE.md#packaging), the existing unlocked package **cannot be converted in place** — a new managed package must be created from this source only after the namespace is linked. |

## Remaining manual/live checklist

- [ ] Resolve the SalesforceDX Namespace Registry OAuth/PKCE issue (via a
      Salesforce support case, retry once the platform defect is fixed, or an
      alternate linkage path), then link the `atexplorer` namespace to the
      `pbo2` Dev Hub (`NamespaceRegistry` must show a record connecting them)
      before any managed package can be created.
- [ ] Create a new 2GP managed package from this source under the linked
      namespace; create and promote a release-candidate package version.
- [x] ~~Re-run `RunLocalTests` against the new package version and reconcile
      the 22 vs. 28 test count~~ - done for unlocked beta `1.0.0.2`
      (`04tbm000000gaALAAY`): 28/28 passed, 97% org-wide coverage, matching
      this source's full test suite. The eventual managed (2GP) package
      version should still get its own `RunLocalTests` run once created, as
      package version identity changes with each new version.
- [x] ~~Validate install of the new package version into a clean org~~ - done
      for unlocked beta `1.0.0.2`: installed successfully into a clean active
      QA scratch org (`00DO500000q61ptMAA`) with no packages installed
      beforehand. The eventual managed (2GP) package version should still be
      validated with its own clean-org install once created.
- [ ] Submit the managed package version for AppExchange Security Review.
- [ ] Only after security review approval: update `README.md`,
      `docs/APPEXCHANGE-LISTING.md`, and this file to reference the new
      managed package's install URL, and remove the unlocked-package install
      instructions.

**Current state: this is an unlocked beta package.** It has not been
converted to a managed package, has not been submitted for AppExchange
Security Review, and has no AppExchange listing. Do not describe it as
"managed", "AppExchange-approved", or "AppExchange-ready" in any listing,
documentation, or marketing copy until the steps above are complete.
