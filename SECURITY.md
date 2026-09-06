# Security Policy

Audit Trail Explorer is a read-only Salesforce app. It performs no DML, makes no
external callouts, and stores no data outside the standard `SetupAuditTrail`
object it reads. See [`docs/SECURITY-REVIEW-SOLUTION-DOC.md`](docs/SECURITY-REVIEW-SOLUTION-DOC.md)
for the full architecture and data-handling review prepared for the AppExchange
security review, and [`docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](docs/SECURITY-REVIEW-FINDINGS-DISPOSITION.md)
for the Salesforce Code Analyzer findings and their disposition.

## Supported versions

This is an unlocked/managed package distributed as a single current version.
Only the latest released package version is supported; install the latest
version to get security fixes.

## Reporting a vulnerability

Please **do not** open a public GitHub issue for a suspected security
vulnerability.

Instead, report it privately using one of these channels:

- GitHub: use the repository's **Security** tab → **Report a vulnerability**
  (private security advisory), or
- Open a draft security advisory at
  `https://github.com/muraliseelam/sf-audittrail-app/security/advisories/new`.

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
