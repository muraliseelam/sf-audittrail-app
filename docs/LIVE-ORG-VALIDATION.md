# Live-Org Validation Record

This file tracks validation steps that require a live Salesforce org/Dev Hub
and therefore cannot be run from this repository's CI. It is updated by
whoever performs each step, with the concrete evidence (org, test run id,
report values) rather than a bare pass/fail, so the record stays auditable.

**Status:** in progress. Nothing below constitutes an AppExchange security
review approval, certification, or managed-package release — see
[`docs/APPEXCHANGE-LISTING.md`](APPEXCHANGE-LISTING.md) for the claims policy.

## Package install validation

### Current: managed 2GP beta `1.0.0.2` (`04thm000002OtQPAA0`)

Built from this exact source commit, under the `atexplorer` namespace.

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

### Current: managed beta `1.0.0.2` in the subscriber org

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

### Current: source deploy of the same commit

| Item         | Result                            |
| ------------ | --------------------------------- |
| Org          | Clean scratch org, alias `src-qa` |
| Test level   | `RunLocalTests`                   |
| Tests passed | **29 / 29 (0 failures)**          |

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
- [ ] Promote a managed package version from beta to released.
- [ ] Submit the released managed package version for AppExchange Security
      Review.
- [ ] Only after security review approval: update `README.md`,
      `docs/APPEXCHANGE-LISTING.md`, and this file to reference the released
      managed package's install URL.

**Current state: this is an unreleased managed beta.** It has not been
promoted to a released version, has not been submitted for AppExchange
Security Review, and has no AppExchange listing. Do not describe it as
"released", "AppExchange-approved", or "AppExchange-ready" in any listing,
documentation, or marketing copy until the steps above are complete.
