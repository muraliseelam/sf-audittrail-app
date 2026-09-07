# Live-Org Validation Record

This file tracks validation steps that require a live Salesforce org/Dev Hub
and therefore cannot be run from this repository's CI. It is updated by
whoever performs each step, with the concrete evidence (org, test run id,
report values) rather than a bare pass/fail, so the record stays auditable.

**Status:** in progress. Nothing below constitutes an AppExchange security
review approval, certification, or managed-package release — see
[`docs/APPEXCHANGE-LISTING.md`](APPEXCHANGE-LISTING.md) for the claims policy.

## Package install validation

| Item                    | Result                                         |
| ----------------------- | ---------------------------------------------- |
| Package installed       | Existing unlocked package `04tbm000000aeOjAAI` |
| Target org              | `orgfarm-dev-ed`                               |
| Install result          | Succeeded                                      |
| Permission set assigned | `Audit_Trail_Viewer` — assigned successfully   |

## Apex test run (RunLocalTests)

| Item                         | Result                                                                                               |
| ---------------------------- | ---------------------------------------------------------------------------------------------------- |
| Test run id                  | `707bm00001DpAzr`                                                                                    |
| Tests passed                 | 22 / 22 (0 failures)                                                                                 |
| Test-run / org-wide coverage | 97%                                                                                                  |
| Package version report       | `IsReleased=false`, `ValidationSkipped=false`, `CodeCoverage=97%`, `HasPassedCodeCoverageCheck=true` |

> **Note for reconciliation:** the source in this repository contains 28
> `@IsTest` methods across `AuditPermissionServiceTest`,
> `AuditQueryControllerTest`, `AuditQueryServiceTest`, and
> `SetupAuditTrailProviderTest`. The org run above reported 22/22. This may
> simply reflect which package version/test scope `RunLocalTests` selected
> in that org (for example, an older installed package version predating
> some tests) rather than a discrepancy in this source — worth confirming
> against the exact package version installed the next time this is run,
> but it does not indicate a failing test.

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
- [ ] Re-run `RunLocalTests` against the _new_ managed package version and
      reconcile the 22 vs. 28 test count above against that version's exact
      Apex class set.
- [ ] Validate install of the new managed package version into a clean org
      (fresh org, not `orgfarm-dev-ed`, to catch any dependency the existing
      unlocked-package org may be masking).
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
