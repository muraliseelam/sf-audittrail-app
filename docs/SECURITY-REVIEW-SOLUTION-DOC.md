# Audit Trail Explorer — Solution Documentation

Prepared ahead of an eventual AppExchange/AgentExchange security review
submission. **This package has not yet been submitted for, or passed, that
review** — see [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for
its current unreleased-beta, unlocked-package status.

## 1. What the solution does

Audit Trail Explorer is a read-only UI over the standard Salesforce `SetupAuditTrail`
object. Salesforce retains setup audit records for 180 days and exposes them in Setup
only as a flat, barely filterable list with a 20-row page and a CSV download. This app
provides search, filtering, faceting, paging and export over that same data.

It adds no new data. It is a viewer.

## 2. Architecture

```
Browser (Lightning Web Component)
  |  imperative Apex
  v
AuditQueryController          @AuraEnabled facade - the ONLY external surface
  |  (every method calls AuditPermissionService first; also issues one SOQL
  |   query directly, against the standard User object, for the "changed by"
  |   type-ahead - see section 6)
  v
AuditQueryService             progressive, time-sliced scan; Apex-side filtering
  |
  v
SetupAuditTrailProvider       the only class that queries SetupAuditTrail
  |
  v
SetupAuditTrail (standard object, read-only)
```

There is no trigger, no scheduled job, no batch job, no platform event, no custom object,
and no custom setting.

## 3. Data handling

| Question                                         | Answer                                                                                                                                                                         |
| ------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Does the solution store data outside Salesforce? | **No.**                                                                                                                                                                        |
| Does the solution make external callouts?        | **No.** There is no `HttpRequest`, no named credential, and no remote site setting in the package.                                                                             |
| Does the solution create or modify any record?   | **No.** The package performs no DML of any kind.                                                                                                                               |
| Does the solution include a custom object?       | **No.**                                                                                                                                                                        |
| Where is data persisted?                         | Nowhere. Every request reads `SetupAuditTrail` (and, for the user type-ahead described below, `User`) live and returns the rows to the browser. Nothing is cached server-side. |
| Is any data sent to a third party?               | **No.**                                                                                                                                                                        |

Because nothing is stored, there is no data-retention, data-residency or data-deletion
surface. Uninstalling the package removes the code and leaves no residue.

## 4. Authentication and authorisation

The app has a single authorisation gate: the standard **View Setup and Configuration**
(`ViewSetup`) user permission, which is the same permission Salesforce itself requires to
view the Setup Audit Trail. The app grants no access that the user did not already have.

`AuditPermissionService.assertCanViewSetup()` enforces this by checking
`Schema.SObjectType.SetupAuditTrail.isAccessible()`. This was verified empirically rather
than assumed: under `System.runAs`, a user on a profile granting ViewSetup returns `true`,
and a user on **Minimum Access - Salesforce** returns `false`. `AuditPermissionServiceTest`
pins both cases with real users on real profiles.

Every `@AuraEnabled` method calls this gate before doing any work:

| Method        | Gated                | Notes                                                                                                                                                                                                                                    |
| ------------- | -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `search`      | Yes                  |                                                                                                                                                                                                                                          |
| `searchUsers` | Yes                  | Type-ahead over the User object for the "changed by" filter                                                                                                                                                                              |
| `getContext`  | Not gated, by design | Returns only compile-time constants, `Datetime.now()`, and the calling user's own access boolean. It discloses nothing the caller does not already know about themselves, and the UI needs it to render the "you lack permission" state. |

The shipped permission set `Audit_Trail_Viewer` grants `ViewSetup`, the app, the tab, and
Apex class access - nothing more.

## 5. CRUD/FLS and sharing enforcement

- The single production SOQL statement runs as
  `Database.query(soql, AccessLevel.USER_MODE)`, so CRUD and FLS are enforced by the
  platform rather than by hand-written describe checks.
- Every Apex class in the package is declared `with sharing`.
- `SetupAuditTrail` is a read-only platform-owned object, so there is no DML to enforce.

## 6. Injection defences

**SOQL.** `SetupAuditTrailProvider` is the only class that builds the
`SetupAuditTrail` query string; `AuditQueryController.searchUsers` is the
only other class that issues SOQL, against `User` (see section 3 and the
LIKE-wildcards note below). In both queries, every literal fragment is a
compile-time string literal - there is no path by which user input reaches
the query text. All user-supplied values (`CreatedById`, `Action`, date
bounds, excluded ids, row limit, the type-ahead search term) are passed as
bind variables. The row limit on the `SetupAuditTrail` query is bound from
the private constant `SCAN_BATCH`, not from the client.

**LIKE wildcards.** For the user type-ahead, the search term is bound (never
concatenated), and LIKE metacharacters are neutralised in the correct order: backslash
first, then `%`, then `_`. `String.escapeSingleQuotes` is deliberately **not** used on
bind values, because it corrupts legitimate names such as `O'Brien` without adding safety.

**Untrusted cursor.** The paging cursor round-trips through the browser and is therefore
treated as untrusted input. Malformed ids are discarded rather than cast, and the set of
"already seen" ids is capped so a crafted cursor cannot push an unbounded bind into the
query.

**XSS.** The LWC renders exclusively through `{}` template interpolation, which is
context-escaped by the framework. The package contains no `innerHTML`, no
`lwc:dom="manual"`, no `eval`, no `document.write`, and no Visualforce or Aura.

**CSV formula injection.** Audit descriptions echo admin-controlled text (renamed field
labels, for example), so an exported cell could otherwise carry a payload that executes
when the file is opened in Excel or Google Sheets. `csv.js` prefixes any cell beginning
with `=`, `+`, `-`, `@`, whitespace, a C0 control character or a zero-width space with a
single quote. The logic is isolated in its own module specifically so it can be unit
tested, and it is.

## 7. Error handling

Only the permission error is passed to the client verbatim, because it is the actionable,
user-facing case. Every other exception is converted to a generic message, with the detail
written to the debug log via `System.debug(LoggingLevel.ERROR, ...)`, so platform
exception text cannot leak query or limit internals to the browser. No secret, credential
or personal data is logged.

## 8. Testing

- 28 Apex tests; org-wide coverage **97%**, with no class below 95% (the managed-package
  requirement is 75%).
- `SetupAuditTrail` cannot be inserted in a test, so the service takes an injectable
  provider interface. `SetupAuditTrailProviderTest` nonetheless executes the real
  production query, so the SOQL is genuinely exercised rather than mocked away.
- 5 Jest tests covering the component, including the CSV escaping.
- Paging correctness was validated against real data: 122 records over 18 pages,
  **0 duplicates and 0 skipped rows**.

## 9. Third-party code

**None.** The package contains no third-party JavaScript library, no static resource, and
no npm dependency shipped to the runtime. RetireJS reports zero findings.

## 10. Editions and compatibility

Lightning Experience only (the app is Lightning Web Components). Professional Edition is
not supported, because it cannot run custom Apex.
