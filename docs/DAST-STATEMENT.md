# Dynamic Application Security Testing (DAST): not applicable

Audit Trail Explorer, managed package `atexplorer`, version `1.0.1.4`
(`04thm000002tWirAAE`), package `0Hohm0000000NHZCA2`.

A DAST report covers a solution's own web application, API, mobile app or other
endpoint outside the Salesforce Platform. Audit Trail Explorer has none, so
there is nothing for a DAST tool to scan.

## What the package is

- **Metadata.** Apex classes, one Lightning web component (`auditExplorer`),
  one permission set, one Lightning app and one tab. The package source holds
  no other metadata types (`force-app/main/default/applications`, `classes`,
  `lwc`, `permissionsets`, `tabs`).
- **No callouts.** No Apex HTTP callouts (`Http`, `HttpRequest`), no Named
  Credentials, External Credentials, Remote Site Settings or CSP Trusted
  Sites, and no network requests from the Lightning web component other than
  its own `@AuraEnabled` Apex methods.
- **No external service.** Nothing runs outside Salesforce: no web server,
  API, mobile app, browser extension or desktop agent is part of the solution.
- **No stored data and no integration users.** The app reads the standard
  `SetupAuditTrail` object at request time and stores nothing
  ([`PRIVACY.md`](PRIVACY.md)).

All of the solution's code runs on the Salesforce Platform and is covered by
the Salesforce Code Analyzer report and the Source Code Scanner report
submitted with this review.

## Evidence

- Architecture and data handling:
  [`SECURITY-REVIEW-SOLUTION-DOC.md`](SECURITY-REVIEW-SOLUTION-DOC.md),
  sections 2 and 3.
- Data handling statement: [`PRIVACY.md`](PRIVACY.md).
- Package source: `force-app/` at tag `v1.0.1`.

Publisher: (to be supplied by the publisher)

Date: (to be supplied by the publisher)
