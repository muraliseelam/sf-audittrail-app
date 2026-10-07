# Security Program

Prepared for the AppExchange Security Review submission, which requires a
partner to have "a security program that demonstrates your company's commitment
to security" and to share that program with customers. The headings below follow
Salesforce's "Security Policy Requirements" page in the ISVforce Guide.

**Scale statement, stated plainly up front.** Audit Trail Explorer is maintained
by one person as an open-source project, not by a company with a security
function. Salesforce states that it factors company size and maturity into what
it expects here. This document therefore describes what is actually done, and
says so explicitly where a control a larger organisation would have does not
exist. Nothing below is aspirational; every practice described is in effect
today and verifiable from this repository.

## 1. Security ownership

Murali Mohan Reddy Seelam is the maintainer and the designated security contact,
and is solely responsible for design, implementation, review and remediation.

There is no separate security reviewer. The compensating controls are that the
entire source is public and independently auditable, that every change goes
through automated static analysis before release, and that the application's
attack surface is deliberately minimal — see section 3.

## 2. Security policy

The product-level security posture is documented in full:

| Document                                                                             | Covers                                                    |
| ------------------------------------------------------------------------------------ | --------------------------------------------------------- |
| [`SECURITY-REVIEW-SOLUTION-DOC.md`](SECURITY-REVIEW-SOLUTION-DOC.md)                 | Architecture, authorisation, CRUD/FLS, injection defences |
| [`PRIVACY.md`](PRIVACY.md)                                                           | What is read, what is never stored, transmitted or logged |
| [`ARCHITECTURE.md`](ARCHITECTURE.md)                                                 | Component design and known limitations                    |
| [`../SECURITY.md`](../SECURITY.md)                                                   | Vulnerability reporting and supported versions            |
| [`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md) | Every static-analysis finding and its disposition         |

The governing principle is that the application must not be able to grant any
user access they do not already hold. Every user who can read audit data through
this app could already read it natively in Setup.

### What the customer must do

The package cannot secure itself on the subscriber's behalf in one respect, and
subscribers need to know it:

- Assign `atexplorer__Audit_Trail_Viewer`, **and** separately grant "View Setup
  and Configuration" through the subscriber's own profile or permission set.
  Salesforce strips system permissions from managed packages on install, so the
  packaged permission set cannot grant it.
- Grant both only to users who should see setup change history. The app applies
  no access of its own and adds no filtering beyond the platform's.

## 3. Services and artifacts

The complete solution is one managed package. There is nothing else.

| Artifact                | Detail                                                    |
| ----------------------- | --------------------------------------------------------- |
| Managed 2GP package     | `0Hohm0000000NHZCA2`, namespace `atexplorer`, v `1.0.0.2` |
| Apex classes            | 10 production, 4 test                                     |
| Lightning web component | `auditExplorer`                                           |
| Custom app, tab         | `Audit_Trail_Explorer`                                    |
| Permission set          | `Audit_Trail_Viewer`                                      |

There is **no** web application, hosted service, API, SDK, mobile client,
connected app, external client app, named credential, remote site setting,
static resource, custom object, custom setting, trigger, batch job, scheduled
job or platform event. No class is declared `global`, so the package exposes no
callable surface outside its own namespace.

## 4. Third-party library inventory

**None ship to the runtime.** The package contains no third-party JavaScript,
no static resource and no bundled dependency. RetireJS reports zero findings on
every scan.

Development-time dependencies are Salesforce and community tooling only —
ESLint, Prettier, Jest via `@salesforce/sfdx-lwc-jest`, Husky, lint-staged — and
none of them reach a subscriber org. Exact resolved versions are pinned in
`package-lock.json`, and CI installs with `npm ci` so builds are reproducible
from the lockfile rather than from range resolution.

## 5. Architecture diagrams

Component diagram, data flow and trust boundaries are in
[`ARCHITECTURE.md`](ARCHITECTURE.md), with the authorisation model and each SOQL
path in section 2 of
[`SECURITY-REVIEW-SOLUTION-DOC.md`](SECURITY-REVIEW-SOLUTION-DOC.md).

The data flow is one direction and one hop: browser → `@AuraEnabled` controller
→ query service → `SetupAuditTrail`, returning rows to the browser. Nothing is
persisted at any point.

## 6. Certifications

**None.** No HIPAA, PCI DSS, SOC 2 or ISO 27001 certification is held or
claimed. These attest to organisational controls that a single-maintainer
open-source project does not have, and claiming otherwise would be false.

The project processes no payment, health or regulated personal data of its own —
see section 9.

## 7. Independent third-party audit

**None has been commissioned.** The substitutes, which are real but are not the
same thing and are not presented as such:

- The complete source is public at
  <https://github.com/muraliseelam/sf-audittrail-app> under Apache-2.0 and can
  be audited by anyone, including any prospective subscriber.
- Salesforce Code Analyzer runs across six engines and 310 rules, including the
  Graph Engine's path-sensitive CRUD/FLS analysis, with results recorded per run
  in [`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md).
- The AppExchange Security Review itself is an independent assessment by
  Salesforce Product Security.

## 8. Security-assurance activities

### Software development lifecycle

Trunk-based, with `main` protected by automated checks. Every change arrives by
pull request; CI runs ESLint, a Prettier format check and the Jest suite on each
pull request and on each push to `main`. A Husky pre-commit hook runs
`lint-staged`, so formatting and lint failures surface before a commit exists.

Design precedes implementation for substantive changes, and interfaces and tests
precede implementation. Apex tests run against a live org before a package
version is built, because `SetupAuditTrail` rows cannot be inserted in a test
context and the data source is therefore exercised through an injected provider.

### Static analysis

Salesforce Code Analyzer runs weekly (Mondays 06:00 UTC) and on demand, not on
every pull request — deliberately, because the Graph Engine needs an otherwise
idle machine and reports a vacuous "0 violations" when starved of memory. The
workflow therefore verifies every run by its **counts**: the rule selector must
resolve to 310 rules across 6 engines, and the Graph Engine must report the full
14,503 paths across 3/3 entry points, or the job fails. Any Critical or High
finding fails the job outright.

This guards a specific failure mode found in this project's own history: a
selector that silently resolved to zero rules, and a Graph Engine run abandoned
part-way, each reporting a clean result that proved nothing.

### Vulnerability management and remediation

Reports are received privately at the address in
[`../SECURITY.md`](../SECURITY.md); public issues are explicitly discouraged for
suspected vulnerabilities. Reports are acknowledged, reproduced, fixed, and
released as a new managed package version, with the reporter credited in
`CHANGELOG.md` unless anonymity is requested.

**Target remediation times.** These are the maintainer's commitments for a
single-person project, not an enterprise SLA, and are stated as targets rather
than guarantees:

| Severity                                         | Acknowledge | Fix released |
| ------------------------------------------------ | ----------- | ------------ |
| Critical — data exposure or authorisation bypass | 3 days      | 14 days      |
| High                                             | 7 days      | 30 days      |
| Moderate / Low                                   | 14 days     | Next release |

Security fixes are issued against the current released managed version only.
Superseded versions and the retired unlocked lineage are not patched.

### Supplier and dependency security

The runtime dependency tree is empty, so the supply-chain surface is limited to
build-time tooling that never reaches a subscriber. Dependencies are added
sparingly and justified before adoption. `npm ci` installs from the committed
lockfile.

**Known gap:** dependency updates are reviewed manually rather than by automated
alerting, and GitHub's private vulnerability reporting is not currently enabled
on the repository. Both are recorded as gaps rather than described as controls.

### Security-awareness training

**No formal training program exists**, which would be meaningless for a
single-maintainer project. The maintainer works professionally as a software
engineer and tracks Salesforce's secure-coding guidance, the AppExchange
security requirements, and the Code Analyzer rule set — the last of which is
enforced mechanically on every scan rather than relied on as knowledge.

### Breach response

No customer data is held, so there is no data-breach surface of the usual kind:
the package stores nothing, transmits nothing externally, and retains nothing
after uninstall. A compromise would have to take one of two forms, and both are
handled by the same path:

1. **A vulnerability in the package** — handled as above, with a fixed version
   released and subscribers notified through `CHANGELOG.md`, the GitHub
   repository and, where the severity warrants it, directly.
2. **Compromise of the publishing account or package lineage** — Salesforce
   Product Security and Security Review Operations are contacted immediately
   through the security leadership contacts registered in the Partner Console,
   and the listing is withdrawn pending investigation.

Subscribers can verify independently that no data left their org: the package
contains no callout, no named credential and no remote site setting, so there is
no egress path to audit.

## 9. Sensitive data

The app **processes** but never **stores** the following, all of which already
exist in the subscriber's org and are already visible to the same users through
Setup:

| Data                                                          | Source                    | Retained |
| ------------------------------------------------------------- | ------------------------- | -------- |
| Setup change descriptions, sections, actions, timestamps      | `SetupAuditTrail`         | No       |
| Names and usernames of users who made setup changes           | `SetupAuditTrail`, `User` | No       |
| Id, Name, Username of active users, for the filter type-ahead | `User`                    | No       |

No payment instrument data, no health data, no government identifiers, no
credentials and no session data are read, processed or logged. The only
server-side log write is an exception type and message on an unexpected failure,
which deliberately excludes audit row content.

## 10. Data storage locations and providers

**None.** No data is stored outside the subscriber's own Salesforce org, so
there are no data-residency questions, no cloud providers to disclose, and no
sub-processors. The CSV export is assembled in the browser and written to the
user's own device by the browser; it is never uploaded.

## 11. Third-party data sharing

**None.** No data is shared with any third party. The package contains no
telemetry, no analytics and no callout of any kind.

Any future adoption analytics will use Salesforce's own AppExchange App
Analytics or License Management App rather than custom telemetry, will be
opt-in, will not include audit row content, and will be documented in
[`PRIVACY.md`](PRIVACY.md) before being enabled.

## 12. Security contacts for Salesforce

Security leadership contacts are maintained in the Partner Console under Company
Info, per Salesforce's requirement, and re-confirmed when the console prompts —
every six months. Salesforce uses these only for security incident response;
they are not published.

## 13. Customer-facing contact

| Purpose                  | Channel                                                    |
| ------------------------ | ---------------------------------------------------------- |
| Security vulnerability   | Private email, see [`../SECURITY.md`](../SECURITY.md)      |
| Support, bugs, questions | <https://github.com/muraliseelam/sf-audittrail-app/issues> |
| Privacy questions        | [`PRIVACY.md`](PRIVACY.md), or a GitHub issue              |

---

## Summary of stated gaps

Collected here so a reviewer does not have to assemble them, and so they are not
mistaken for omissions:

| Gap                                                | Why                                                    |
| -------------------------------------------------- | ------------------------------------------------------ |
| No SOC 2 / ISO 27001 / PCI / HIPAA certification   | Single-maintainer open-source project                  |
| No independent third-party security audit          | Not commissioned; source is public and scanned instead |
| No separate security reviewer                      | One maintainer; compensated by public source and CI    |
| No formal security-awareness training program      | Not meaningful at this scale                           |
| Dependency updates reviewed manually               | No automated alerting configured                       |
| GitHub private vulnerability reporting not enabled | Private email channel used instead                     |
| LWC test coverage 72.16%, below the 85% target     | Measured and published rather than left unstated       |
