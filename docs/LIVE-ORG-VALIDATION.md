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

## Install into a persistent Developer Edition org — 2026-09-13

Every managed install recorded above was into a **scratch** org, which expires
in days. This one is a persistent Developer Edition org, so it demonstrates the
install on the _class_ of org a security reviewer is given.

> **This org is not the submission org, and cannot be.** Inspected on
> 2026-09-20 it proved unsuitable for handover on four counts — see
> [Why this org cannot be handed to a reviewer](#why-this-org-cannot-be-handed-to-a-reviewer--2026-09-20)
> below. What follows is install evidence only.

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

### Why this org cannot be handed to a reviewer — 2026-09-20

Read-only inspection of `00Dbm00000u2XaoEAE`, made while assembling the
submission materials. The install evidence above stands; what fails is the
org's fitness as the Developer Edition org submitted _with_ the review.

| Check                  | Finding                                                                                            |
| ---------------------- | -------------------------------------------------------------------------------------------------- |
| Other packages present | **`devedapp` 0.9.0.2** (`04tfn000001PPYvAAO`) is also installed — an unrelated managed package     |
| Org registration       | Provisioned through orgfarm; the org user and administrator are **not** this project's author      |
| Test user              | **None.** Two System Administrators plus the standard platform users; no user on a minimal profile |
| Audit data             | Newest row 2026-09-16, and the history is essentially the package install itself                   |

Each is disqualifying on its own:

- Salesforce pen-tests the submitted org and determines scope by following the
  data. A second, unrelated managed package in that org is at best a
  distraction and at worst pulls foreign code into the review's scope.
- The org is not registered to the submitting party, so it is not this
  project's to hand over.
- With no minimally-privileged test user, a reviewer cannot exercise the
  two-grant requirement that is this app's central access-control behaviour —
  and the administrator users mask it, because their profile already carries
  `ViewSetup`.
- With almost no audit history, every search returns nothing. A reviewer would
  see an app that appears not to work.

The submission therefore needs a **purpose-built Developer Edition org**,
registered to the author, containing this package and nothing else, with a
non-administrator test user carrying both required grants and enough seeded
audit history for searches to return results. Tracked in the checklist below.

Two claims elsewhere in this repository were re-verified live during the same
inspection, against the released package in this org:

- `atexplorer__Audit_Trail_Viewer` still reports `PermissionsViewSetup = false`
  and `PermissionsViewRoles = false` — the install-time strip, confirmed on
  2026-09-20 rather than carried forward from September 13.
- `SELECT COUNT(Id) FROM SetupAuditTrail` is rejected by the platform with
  `field Id does not support aggregate operator COUNT`, confirming the
  no-aggregates constraint that the progressive-scan design exists to work
  around.

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

118 exported rows against 118 rows in the org, with zero duplicates, is a live
confirmation of the cursor's seen-ids design on a harder dataset than the
122-record check recorded elsewhere.

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

## Remaining work before an AppExchange Security Review submission

This checklist previously tracked only steps needing a live org or Dev Hub, and
so read as though submission were the single remaining step. It is not. The
AppExchange submission has a second half — Partner Console prerequisites and
submission materials — that no live-org evidence can satisfy, and that half is
tracked below alongside the first. Requirements are taken from the ISVforce
Guide, "Prepare for the AgentExchange Security Review", read 2026-09-20.

### Live-org validation — complete

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
      `00DRL00000Vkme62AB`.
- [x] ~~Promote a managed package version from beta to released~~ — done
      2026-09-09: `1.0.0.2` (`04thm000002OtQPAA0`), Dev Hub `partner-pbo`.
      Irreversible; the version number is permanently consumed.
- [x] ~~Live UI smoke test of the managed install by a human~~ — done
      2026-09-13 against the managed install in `00DRK00000aOfV72AK`; see
      [Functional UI verification](#functional-ui-verification-of-the-managed-install--2026-09-13).
      Screenshots were **not** produced and remain outstanding below.

### Partner Console prerequisites — status unverified

Ordered steps for these, and for everything else outstanding, are in
[`SUBMISSION-RUNBOOK.md`](SUBMISSION-RUNBOOK.md).

None of these can be read from this repository; they live in the Partner
Console and the Partner Community. Each is marked unverified rather than
assumed. Check them at Partner Console → Technologies / Company Info; accessing
the console at all requires the **Manage Listings** permission.

- [ ] **unverified** — ISV Partner Program enrolment and a Partner Business Org.
      The packaging Dev Hub alias `partner-pbo` (`00Dhm000004MOXjEAO`) implies
      this exists, but that is an inference, not evidence.
- [ ] **unverified** — Lightning Ready certification. Mandatory for all new
      submissions.
- [ ] **unverified** — packaging org connected to the Partner Console.
- [ ] **unverified** — company / provider profile created.
- [ ] **unverified** — security leadership contacts designated in Partner
      Console → Company Info. Re-confirmed every six months.
- [ ] **unverified** — package version shows `Ready to List` or
      `Security Review Required` under Technologies → Solutions.

### Submission materials — incomplete

Required for this architecture ("Salesforce Native Solution with Lightning
Components").

- [x] ~~Managed—Released package version~~ — `1.0.0.2`
      (`04thm000002OtQPAA0`). Beta and unmanaged packages are not accepted.
- [x] ~~Salesforce Code Analyzer report~~ — see
      [`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).
- [x] ~~Solution documentation~~ —
      [`SECURITY-REVIEW-SOLUTION-DOC.md`](SECURITY-REVIEW-SOLUTION-DOC.md).
- [ ] **Checkmarx (Source Code Scanner) report.** Required _in addition to_ the
      Code Analyzer scan, and run from the Partner Security Portal rather than
      locally. Not started. Note that the three runs provisioned per package
      version are described as coming "with the security review fee", and no fee
      is payable for a free solution — confirm entitlement at Partner Security
      Portal office hours before planning around it.
- [ ] **False-positives document** in Salesforce's sense, i.e. scanner findings
      claimed to be non-issues. `SECURITY-REVIEW-FINDINGS-DISPOSITION.md`
      disposes of code-quality findings and is not a substitute; the document
      Salesforce asks for principally covers Checkmarx output, which does not
      exist yet.
- [ ] **Developer Edition org prepared as the reviewer's test environment.**
      Must be a **new** org: `00Dbm00000u2XaoEAE` was inspected on 2026-09-20
      and disqualified on four counts — a second unrelated managed package, no
      registration to the author, no test user, and almost no audit history.
      See [Why this org cannot be handed to a reviewer](#why-this-org-cannot-be-handed-to-a-reviewer--2026-09-20).
      The replacement needs this package and nothing else, a non-administrator
      test user carrying **both** required grants, seeded audit history so
      searches return rows, and a handover note stating the two-grant
      requirement up front. Steps in
      [`SUBMISSION-RUNBOOK.md`](SUBMISSION-RUNBOOK.md).
- [x] ~~Company security-program documentation~~ — done:
      [`SECURITY-PROGRAM.md`](SECURITY-PROGRAM.md), covering SDLC, vulnerability
      management and remediation targets, supplier and dependency security,
      breach response, sensitive-data handling and security contacts. Written to
      the scale of a single-maintainer open-source project, with the controls a
      larger organisation would hold stated as explicit gaps rather than
      omitted.

### Submission and after

- [ ] Submit the released managed package version for AppExchange Security
      Review, via the security review wizard in the Partner Console. No fee is
      payable for a free solution. Expect 1–2 weeks to verify the submission
      and 3–4 weeks for first testing.
- [ ] Listing screenshots and demo assets. These need a **fresh** org:
      `00DRK00000aOfV72AK` permanently contains the ~65 seeded "ATE Bulk"
      entries, as noted above.
- [ ] Only after security review approval: create the AppExchange listing, get
      it approved against brand and program policy, sign the Partner
      Application Distribution Agreement, and register the package with the
      License Management App.
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
