# Audit Trail Explorer

A Salesforce app that gives admins and auditors a fast, filterable UI over the
**Setup Audit Trail** — with **zero storage footprint**.

> **Package status: released managed version `1.0.0.2`.** This is distributed as
> a **released** managed 2GP version under the `atexplorer` namespace, so it
> installs into any org including production. It has **not** been submitted for
> or passed AppExchange Security Review, and has **no AppExchange listing** —
> "released" here is the Salesforce packaging state, not a marketplace
> listing. Installation is by direct URL only. See
> [Packaging status](#packaging-status) below.

## What it does

- Search 180 days of setup/config changes by **description text, section, user and date range**
- Streaming results with live progress ("examined 4,300 events back to 12 May")
- Top sections / top users breakdown over the matched results
- Row detail (delegate user, namespace)
- One-click CSV export of the current result set

## Why it costs nothing to run

The app reads Salesforce's own `SetupAuditTrail` object directly. There is:

- no custom object, Big Object or file storage
- no scheduled job, trigger or background process
- nothing that counts against any org allocation

It is entirely read-only.

## The constraints this works around

`SetupAuditTrail` is unusually limited, which is why a plain SOQL-backed list view
isn't enough. Verified against a live org:

| Field                                  | Filterable in SOQL |
| -------------------------------------- | ------------------ |
| `CreatedDate`, `Action`, `CreatedById` | yes                |
| **`Section`**                          | **no**             |
| **`Display`** (description)            | **no**             |

It also supports **no aggregate functions** — `COUNT(Id)`, `MIN(CreatedDate)` and
`GROUP BY` all fail.

So the two fields users most want to search on cannot be filtered by the database,
and no counts can be computed by the database. Naively loading six months of audit
data into Apex to filter it would exceed the 50,000 SOQL row and heap limits in any
large org.

**Solution: progressive, time-sliced search.** `AuditQueryService` walks backwards
through time in bounded batches, pushes what it can into SOQL (date, action, user),
applies the rest in Apex, and returns as soon as a page is filled — handing back a
cursor so the client can resume. Each call is its own transaction with a hard scan
ceiling, so governor limits never bind no matter how much history the org has.

The cursor tracks both the timestamp **and** the ids already consumed at that
timestamp, because a single metadata deployment writes many audit rows sharing one
timestamp — date-only paging would skip or duplicate them.

## Retention

Salesforce keeps Setup Audit Trail for **180 days**; older data is permanently gone.
The app clamps every request to that floor and states the limit in the UI. Retention
beyond 180 days would require archiving, which this package deliberately does not
do; any such add-on, if ever built, would be **opt-in**, so orgs that don't need it
never pay for storage.

## Install

Released managed version **`1.0.0.2`** (`04thm000002OtQPAA0`). Being a
released version, it installs into any org type, including production, and
carries the normal managed-package upgrade guarantees.

It has **not** passed AppExchange Security Review and is not listed on
AppExchange. Satisfy yourself that it meets your own org's review bar before
installing it into production — the source is in this repository, and
[`docs/SECURITY-REVIEW-SOLUTION-DOC.md`](docs/SECURITY-REVIEW-SOLUTION-DOC.md)
documents the security design and static-analysis results in full.

> The earlier unlocked builds (`04tbm000000aeOjAAI`, `04tbm000000gaALAAY`)
> are superseded and belong to a different, non-namespaced package lineage.
> They are retained in [`sfdx-project.json`](sfdx-project.json)'s package
> aliases for traceability only. Install `04thm000002OtQPAA0` below.

```
https://login.salesforce.com/packaging/installPackage.apexp?p0=04thm000002OtQPAA0
```

For a sandbox, swap `login.salesforce.com` for `test.salesforce.com`. Or use the CLI:

```bash
sf package install --package 04thm000002OtQPAA0 --target-org my-org --wait 20
sf org assign permset --name atexplorer__Audit_Trail_Viewer --target-org my-org
```

### Two grants are required — the app does not work with only one

Installing is not enough. An administrator must do **both** of the following:

1. Assign the packaged permission set **`atexplorer__Audit_Trail_Viewer`**.
2. Separately grant **"View Setup and Configuration"** to the same user,
   through their profile or through a permission set created in your own org.

Step 2 is not optional and cannot be done by the package. Under a managed
install the packaged permission set grants only the app, its tab and its Apex
classes — no object CRUD/FLS and no system permission. Salesforce **strips
system permissions from a managed package's permission sets on install**, as
an anti-privilege-escalation measure, so the `ViewSetup` and `ViewRoles`
entries declared in this package's source
([`Audit_Trail_Viewer.permissionset-meta.xml`](force-app/main/default/permissionsets/Audit_Trail_Viewer.permissionset-meta.xml))
are `false` once installed. Those two entries take effect only for a source
deploy or the superseded unlocked package, where the shipped permission set is
sufficient on its own. The strip is verified empirically against the released
version — see [`docs/LIVE-ORG-VALIDATION.md`](docs/LIVE-ORG-VALIDATION.md).

Without step 2 the app installs cleanly, the tab appears, and every search
returns an access error. With both grants it works. "View Setup and
Configuration" (with its `ViewRoles` prerequisite) is what Salesforce requires
to read the audit trail, and the app needs nothing beyond it; see
[`docs/PRIVACY.md`](docs/PRIVACY.md) for the full data-handling statement.

Then open **Audit Trail Explorer** from the App Launcher.

> Editions that cannot run custom Apex are not supported, because this package
> requires it. That rules out **Professional Edition** and **Base Edition** —
> installing into a Base Edition org fails with
> `Missing feature: Apex Classes` (verified 2026-09-13, see
> [`docs/LIVE-ORG-VALIDATION.md`](docs/LIVE-ORG-VALIDATION.md)). Enterprise,
> Unlimited, Performance and Developer Edition all work.

### Deploying from source instead

```bash
sf project deploy start --source-dir force-app --target-org my-org
sf org assign permset --name Audit_Trail_Viewer --target-org my-org
```

## Uninstall

The package stores no data, so uninstalling leaves no residue to clean up.

- **Packaged install:** Setup → Installed Packages → Audit Trail Explorer →
  **Uninstall**. This removes the app, tab, Apex classes, and permission set.
  Unassign the `atexplorer__Audit_Trail_Viewer` permission set first if you
  assigned it to users (Salesforce will otherwise warn about the dependency
  during uninstall).
- **Source deploy:** `sf project delete source --source-dir force-app --target-org my-org`.

No custom object, custom setting, or Big Object is created, so there is no
data-retention step and nothing to archive before removal.

## Development

```bash
npm install
npm run test:unit                                   # LWC Jest tests
sf project deploy start --source-dir force-app --test-level RunLocalTests
```

### Key classes

| Path                                  | Purpose                                                              |
| ------------------------------------- | -------------------------------------------------------------------- |
| `classes/AuditQueryService.cls`       | Progressive search engine                                            |
| `classes/AuditQueryController.cls`    | `@AuraEnabled` facade                                                |
| `classes/AuditTrailProvider.cls`      | Data-source seam (`SetupAuditTrail` rows can't be inserted in tests) |
| `classes/SetupAuditTrailProvider.cls` | Production provider: the SOQL against `SetupAuditTrail`              |
| `classes/AuditPermissionService.cls`  | "View Setup and Configuration" check                                 |
| `lwc/auditExplorer`                   | The UI (`csv.js` holds the CSV cell formatting and formula guard)    |

The remaining classes under `force-app/main/default/classes` are the DTOs
(`AuditCursor`, `AuditEventRow`, `AuditFilter`, `AuditSearchResult`) and test
support (`MockAuditTrailProvider`, an in-memory `AuditTrailProvider`, plus the
four `*Test` classes) — 14 classes in all.

## Packaging status

This repository builds a **managed 2GP package** under the `atexplorer`
namespace (`sfdx-project.json` → `"namespace": "atexplorer"`, package
`0Hohm0000000NHZCA2`). The current build is **released version `1.0.0.2`**
(`04thm000002OtQPAA0`), promoted on 2026-09-09.

A released managed version installs into any org type, including production,
and carries normal managed-package upgrade guarantees. "Released" is the
Salesforce **packaging** state — it says nothing about AppExchange review or
listing (see below).

**Verified in a live org:** the released version installs cleanly into a fresh
scratch org (`rel-qa`, `00DRK00000aOfV72AK`) with no packages installed
beforehand; the namespaced `atexplorer__Audit_Trail_Viewer` permission set
assigns successfully; and the package's 29 Apex tests, running as namespaced
`atexplorer.*` classes in that subscriber org, pass **29/29** (run
`707RK0000BPQrG1`). The package build reported **97% coverage** with
`HasPassedCodeCoverageCheck=true` across 43 metadata files. A source deploy of
the same commit passes `RunLocalTests` **29/29** (run `707Ru00002A7gs1`).

The install-time strip of `ViewSetup`/`ViewRoles` was re-confirmed against the
released version, not carried over from the beta — see
[`docs/LIVE-ORG-VALIDATION.md`](docs/LIVE-ORG-VALIDATION.md) for the full
evidence and remaining checklist.

> The earlier **unlocked** package lineage (`0Hobm0000005681CAA`, versions
> `04tbm000000aeOjAAI` and `04tbm000000gaALAAY`) is superseded. An unlocked
> package cannot be converted in place into a namespaced managed package, so
> the managed lineage above was created fresh from the same source. The
> unlocked aliases are retained in `sfdx-project.json` for traceability only
> and should not be installed.

**This package has not undergone AppExchange security review, has not been
submitted for it, and has no AppExchange listing.** Nothing in this
repository should be read as claiming otherwise.

## More documentation

| Document                                                                                       | Covers                                                                |
| ---------------------------------------------------------------------------------------------- | --------------------------------------------------------------------- |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md)                                                 | Component design, why progressive search is needed, known limitations |
| [`docs/USER-GUIDE.md`](docs/USER-GUIDE.md)                                                     | Using the app; setting up a test user for reviewers                   |
| [`docs/PRIVACY.md`](docs/PRIVACY.md)                                                           | What data the app reads, what it never stores/sends                   |
| [`docs/LIVE-ORG-VALIDATION.md`](docs/LIVE-ORG-VALIDATION.md)                                   | Live-org install/test/namespace validation evidence and checklist     |
| [`docs/SECURITY-REVIEW-SOLUTION-DOC.md`](docs/SECURITY-REVIEW-SOLUTION-DOC.md)                 | Full security architecture review (CRUD/FLS, injection, auth)         |
| [`docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md) | Code Analyzer findings and their disposition                          |
| [`docs/SECURITY-REVIEW-SUBMISSION.md`](docs/SECURITY-REVIEW-SUBMISSION.md)                     | Security Review submission status, findings and runbook               |
| [`docs/SECURITY-PROGRAM-STATEMENT.md`](docs/SECURITY-PROGRAM-STATEMENT.md)                     | Publisher security program statement                                  |
| [`docs/CODE-ANALYZER-SCAN-RECORD.md`](docs/CODE-ANALYZER-SCAN-RECORD.md)                       | Dated Code Analyzer run records: rule counts, results, validity       |
| [`docs/APPEXCHANGE-LISTING.md`](docs/APPEXCHANGE-LISTING.md)                                   | Draft AppExchange listing copy                                        |
| [`SECURITY.md`](SECURITY.md)                                                                   | How to report a vulnerability                                         |
| [`CONTRIBUTING.md`](CONTRIBUTING.md)                                                           | Development setup and PR checklist                                    |
| [`CHANGELOG.md`](CHANGELOG.md)                                                                 | Notable changes by version                                            |

## License

Apache License 2.0 - see [`LICENSE`](LICENSE).
