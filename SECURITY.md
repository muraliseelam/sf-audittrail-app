# Security Policy

Audit Trail Explorer is a read-only Salesforce app. It performs no DML, makes no
external callouts, and stores no data outside the standard `SetupAuditTrail`
object it reads (plus one type-ahead query against the standard `User` object -
see [`docs/PRIVACY.md`](docs/PRIVACY.md)). See
[`docs/SECURITY-REVIEW-SOLUTION-DOC.md`](docs/SECURITY-REVIEW-SOLUTION-DOC.md)
for the full architecture and data-handling review prepared ahead of an
eventual AppExchange security review, and
[`docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md)
for the Salesforce Code Analyzer findings and their disposition.

> **Package status:** the current package version is **released managed 2GP
> `1.0.0.2`** (`04thm000002OtQPAA0`, namespace `atexplorer`), promoted
> 2026-09-09. "Released" is the Salesforce packaging state: it installs into
> any org type including production. The package has **not** been submitted
> for, or passed, AppExchange Security Review, and has **no** AppExchange
> listing. See
> [`docs/LIVE-ORG-VALIDATION.md`](docs/LIVE-ORG-VALIDATION.md) for the exact
> current status.

## Supported versions

Security fixes are issued against the current released managed version only.

| Version   | Package version id   | Lineage                       | Supported            |
| --------- | -------------------- | ----------------------------- | -------------------- |
| `1.0.0.2` | `04thm000002OtQPAA0` | Managed (`atexplorer`)        | **Yes** — current    |
| `1.0.0.1` | `04thm000002OtOnAAK` | Managed (`atexplorer`)        | No — superseded beta |
| `1.0.0.2` | `04tbm000000gaALAAY` | Unlocked (superseded lineage) | No                   |
| `1.0.0.1` | `04tbm000000aeOjAAI` | Unlocked (superseded lineage) | No                   |

The unlocked lineage is a separate, non-namespaced package that could not be
converted in place into the managed one; it is retained in `sfdx-project.json`
for traceability only. If you found an issue on any version above, please
still report it — just say which package version id you tested, because the
two lineages differ.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a suspected security
vulnerability.

Instead, report it privately by emailing:

**`muralirseelam+sf-audittrail-security@gmail.com`**

This inbox is monitored specifically for this project. GitHub's private
vulnerability reporting (the Security tab's "Report a vulnerability" flow) is
**not currently enabled** for this repository, so please use the email
address above rather than that GitHub flow. If that changes, this section
will be updated to reflect it.

Please include:

- A description of the vulnerability and its potential impact.
- Steps to reproduce it (a minimal repro org configuration, permission set
  assignment, or input that triggers the issue).
- The package version and Salesforce API version you tested against.

## What to expect

- We will acknowledge new reports within a reasonable time and work with you
  to confirm the issue.
- Once a fix is available, we will publish a new package version and credit
  the reporter (unless anonymity is requested) in the [CHANGELOG](CHANGELOG.md).
- We do not currently offer a paid bug bounty.

## Scope

In scope:

- The Apex classes, Lightning web component, permission set, and other
  metadata under `force-app/`.
- CRUD/FLS/sharing enforcement, SOQL/SOSL injection, XSS, CSV/formula
  injection in the exported report, and authorization bypass of the
  `AuditQueryController` Apex endpoints.

Out of scope:

- The security of the Salesforce platform itself (report those to
  Salesforce directly at `https://www.salesforce.com/company/security/`).
- Denial of service against your own org's governor limits.
- Issues that require an attacker to already have the "Customize Application"
  or "Author Apex" system permission (equivalent to admin) in the target org.
