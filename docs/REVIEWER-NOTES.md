# Notes for the Security Reviewer

Text for the "testing instructions" / notes fields of the AppExchange Security
Review wizard. Credentials are **not** in this file; they are entered only in
the wizard.

---

**Solution.** Audit Trail Explorer, managed 2GP package `atexplorer`, released
version `1.0.0.2` (`04thm000002OtQPAA0`). A read-only Lightning app that
searches the org's own Setup Audit Trail. It stores nothing, makes no callouts,
and has no external endpoint, named credential, remote site setting, static
resource, custom object, trigger or scheduled job. No class is `global`.

**Read this before logging in: access needs two grants, by design.**
Salesforce strips system permissions from a managed package's permission sets
on install, so the packaged `atexplorer__Audit_Trail_Viewer` arrives with
`ViewSetup = false` even though the source declares it. A user therefore needs:

1. `atexplorer__Audit_Trail_Viewer` - app, tab and Apex class access; and
2. "View Setup and Configuration" from the subscriber's own org. In the test
   org this is the permission set `ATE_Reviewer_View_Setup`, created there by
   the administrator, as any subscriber must.

With only grant 1 the app loads and every search returns an access error
naming the missing permission. That is the intended behaviour, not a defect.

**Users in the test org.**

| User                     | Profile                     | Grants                                                       | Expect               |
| ------------------------ | --------------------------- | ------------------------------------------------------------ | -------------------- |
| Administrator            | System Administrator        | Profile carries ViewSetup; Audit_Trail_Viewer assigned       | Searches return rows |
| Security Reviewer (test) | Minimum Access - Salesforce | `atexplorer__Audit_Trail_Viewer` + `ATE_Reviewer_View_Setup` | Searches return rows |

The test user is the meaningful one: it shows the app grants nothing beyond
what the platform already allows. To see the negative path, remove
`ATE_Reviewer_View_Setup` from the test user and search again.

**Where to start.** App Launcher -> Audit Trail Explorer. The org contains
seeded audit history (permission sets created, relabelled and deleted) so
searches, paging, facets and CSV export all return data.

**Server entry points.** Three `@AuraEnabled` methods on
`AuditQueryController`:

| Method        | Gate                                                                    | Data access                                                     |
| ------------- | ----------------------------------------------------------------------- | --------------------------------------------------------------- |
| `search`      | `AuditPermissionService.assertCanViewSetup()`                           | `SetupAuditTrail`, `Database.query(..., USER_MODE)`, binds only |
| `searchUsers` | `assertCanViewSetup()`                                                  | `User`, `WITH USER_MODE`, LIKE wildcards escaped                |
| `getContext`  | none; returns only retention constants and the caller's own access flag | No record data                                                  |

All classes are `with sharing`. Unexpected exceptions are returned to the
client as a fixed generic message; detail stays in the server debug log.

**Scans submitted.**

- Salesforce Code Analyzer v5, selectors `Recommended` + `Security` +
  `AppExchange` (310 rules, 6 engines): 0 Critical, 0 High. Graph Engine:
  14,503 paths on 3/3 entry points, 0 violations. This selector is a strict
  superset of the one in the ISVforce Guide, which engages no Graph Engine rule;
  see `SECURITY-REVIEW-SOLUTION-DOC.md`. Remaining findings are code-quality
  rules, dispositioned in `SECURITY-REVIEW-FINDINGS-DISPOSITION.md`.
- Source Code Scanner (Checkmarx): report and false-positive notes attached
  separately.
- DAST: not applicable; the solution has no external endpoint.

**Supported editions.** Enterprise, Unlimited, Performance and Developer.
Professional and Base Edition cannot run custom Apex and cannot install it.

**Source.** <https://github.com/muraliseelam/sf-audittrail-app> (Apache-2.0).
