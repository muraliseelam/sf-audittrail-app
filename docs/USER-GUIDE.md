# User Guide

How to set up and use **Audit Trail Explorer**, managed package version
`1.0.0.2` (`04thm000002OtQPAA0`, namespace `atexplorer`). It is written for
the administrators who assign access, the auditors who use the app, and the
reviewers who test it. Every statement about behaviour carries a marker such
as `[E4]` that points to the file and line in this repository where the
behaviour is implemented; the markers are resolved in the
[Evidence](#evidence) list at the end.

**Status:** the package is a released managed version in the Salesforce
packaging sense. It has not been submitted for AppExchange Security Review,
has not been reviewed, and has no AppExchange listing.

## 1. What it is

Audit Trail Explorer is a read-only search screen over the standard
`SetupAuditTrail` object: the same setup-change history that Setup shows
under **View Setup Audit Trail**, with search by free text, section, user
and date range added `[E1]`. It stores nothing: no custom object, custom
setting, Big Object, file, cache, scheduled job or callout; every search
queries `SetupAuditTrail` live, in the running user's own context, and the
results live only in the browser page until it is reloaded `[E2]`. Salesforce
keeps Setup Audit Trail for 180 days, so the app never looks further back
than that and tells you the date before which nothing is available `[E3]`.

## 2. Before you start - the two grants

Installing the package is not enough. A user needs **both** of the following
before the app works `[E4]`:

1. **The packaged permission set `atexplorer__Audit_Trail_Viewer`** (label
   "Audit Trail Viewer"). It grants the Audit Trail Explorer app, its tab and
   its four Apex classes, and nothing else: no object or field permissions
   `[E5]`.
2. **The system permission "View Setup and Configuration"**, granted
   separately, through the user's profile or through a permission set created
   in your own org. "View Setup and Configuration" requires "View Roles and
   Role Hierarchy", which Setup enables with it `[E6]`.

**Why the package cannot do step 2 for you.** The permission set in the
package source does declare `ViewSetup` and `ViewRoles` `[E6]`, but Salesforce
removes system permissions from a managed package's permission sets when the
package is installed, as an anti-privilege-escalation measure. On the
installed `atexplorer__Audit_Trail_Viewer`, `PermissionsViewSetup` and
`PermissionsViewRoles` are `false`; this was verified in three different
orgs, including a persistent Developer Edition org `[E7]`.
The declared entries take effect only when the source is deployed directly,
not through the managed package.

**What a user sees with only step 1.** The app and tab are visible and open,
but instead of the search form the page shows one message, which begins:

> You need the "View Setup and Configuration" permission to use the Audit
> Trail Explorer. Ask your administrator to grant it to your user.

and goes on to explain that an installed package cannot grant it `[E8]`. Only
the card title and a disabled **Export CSV** button remain on the page `[E9]`.
The gate is the platform's own object-level check,
`Schema.SObjectType.SetupAuditTrail.isAccessible()`, which is `true` exactly
when the running user holds "View Setup and Configuration" `[E10]`. The same
check runs again on the server at the start of every search and every user
type-ahead call, so the message is a convenience, not the control `[E11]`.

**What a user sees with only step 2.** Nothing: without the packaged
permission set the app does not appear in the App Launcher and the Apex
classes are not accessible to that user `[E5]`.

## 3. Setting up a test user for reviewers

These steps create a user who can use the app, and a second user who
demonstrates the access gate closing. Both use the stock profile **Minimum
Access - Salesforce**, which grants neither the app nor "View Setup and
Configuration", so each result is attributable to the grants you add `[E12]`.
Both users need a licence that offers that profile (the Salesforce user
licence); check **Setup > Company Information > User Licenses** for spare
seats first. If only one seat is spare, create the restricted user (step C)
first, observe the denial, then add the local permission set from step B to
the same user and observe the app open.

**A. Create the user**

1. **Setup > Users > Users > New User.** Choose User License **Salesforce**
   and Profile **Minimum Access - Salesforce**. Give it an email address you
   can read, and save. Set the password from the welcome email, or with
   **Reset Password** on the user record.
2. Assign the packaged permission set: on the user record, **Permission Set
   Assignments > Edit Assignments**, move **Audit Trail Viewer**
   (`atexplorer__Audit_Trail_Viewer`) to Enabled Permission Sets, save. From
   the CLI the equivalent is:

    ```bash
    sf org assign permset --name atexplorer__Audit_Trail_Viewer --on-behalf-of <username> --target-org <alias>
    ```

**B. Create a local permission set that grants View Setup and Configuration**

1. **Setup > Users > Permission Sets > New.** Label it, for example,
   "Audit Trail - View Setup (local)", leave License blank, save.
2. Open **System Permissions > Edit**, tick **View Setup and Configuration**,
   accept the prompt that also enables **View Roles and Role Hierarchy**, and
   save.
3. **Manage Assignments > Add Assignment**, select the user from step A,
   assign.

**C. Create a second user that shows the denial**

Repeat step A only (Minimum Access - Salesforce plus
`atexplorer__Audit_Trail_Viewer`). Do not assign the local permission set
from step B. Logging in as this user and opening the app shows the message
quoted in section 2 in place of the search form `[E8]`.

**D. Make sure there is something to find**

A new org has few audit rows. Any setup change writes rows: creating the
permission set in step B and assigning it already did, as does creating and
deleting a custom field or editing a profile. The app shows only changes made
within the last 180 days `[E3]`. Before handing the org to anyone, read its
Setup Audit Trail yourself for usernames or descriptions you would not want a
reviewer to see; the app shows the running user exactly what Setup would.

**E. Check**

Log in as the step A user (or use **Login** from **Setup > Users** if the org
allows administrators to log in as any user) and open **Audit Trail
Explorer** from the App Launcher. The search form appears and the default
search (last 7 days) runs on its own `[E13]`. Log in as the step C user: the
denial message appears instead `[E8]`.

## 4. Using the app

### 4.1 Opening the tab

Open **Audit Trail Explorer** from the App Launcher; the app has one tab of
the same name `[E14]`. An administrator can also place the component on a
Lightning App page or Home page `[E15]`. Each time the component loads it
fetches the retention window and your access, and if you have access it runs
a search immediately with the default filters: date range "Last 7 days", no
text, no sections, no users `[E13]`.

### 4.2 Date range

The **Date range** list has six entries `[E16]`:

| Entry                   | Period searched                                                         |
| ----------------------- | ----------------------------------------------------------------------- |
| Today                   | the 24 hours before the moment you search, not the calendar day `[E17]` |
| Last 7 days (default)   | 7 x 24 hours before the moment you search `[E17]`                       |
| Last 30 days            | 30 x 24 hours                                                           |
| Last 90 days            | 90 x 24 hours                                                           |
| Last 180 days (maximum) | 180 x 24 hours, which is the whole retention window                     |
| Custom range            | shows **From** and **To** date-time fields `[E18]`                      |

For a custom range, an empty **From** means "7 days ago" and an empty **To**
means "now" `[E19]`. Whatever you choose, the start is raised to the
retention floor if it is earlier, so a range can never reach data Salesforce
no longer holds `[E20]`. The bounds are computed from your computer's clock at
the moment the search starts `[E17]`. Changing the date range does not search
by itself; click **Search**.

### 4.3 Free-text search

The **Search description, section or action** box takes one or more words.
Every word must appear, in any order, for a row to match; the words are
compared case-insensitively against the row's description, section, action
and the name of the user who made the change, joined together `[E21]`. The
help icon on the field says the same: "All words must appear." `[E22]` For
example, `permission set jane` matches a row whose description mentions a
permission set and whose user name or description contains "jane". Pressing
**Enter** in this box runs the search `[E23]`.

Description and section cannot be filtered by the database, so these words
are checked in Apex as rows stream in; this is why a rare word over a long
range can take several server calls to fill a page (section 4.6).

### 4.4 Section filter

A **Sections** list with **Available** and **Selected** columns appears once
the first results have arrived. It is filled from the section names seen in
the rows examined so far, including rows that did not match your text or
section filters (a user filter narrows the rows examined, so it also narrows
this list), and grows as searches reach further back; it is not a list of
every section in the org `[E24]`. Move sections to **Selected** and click
**Search**. A row matches when its section equals one of the selected names,
compared case-insensitively `[E25]`. The list persists for the rest of the
page session; **Reset** clears the selection but not the list `[E26]`.

### 4.5 User filter

Type at least two characters in **Filter by user**. The app looks up active
users whose name or username contains what you typed and shows up to 20 of
them, ordered by name, as "Name (username)" buttons under the field `[E27]`.
Users you have already chosen are left out of that list `[E28]`. Click one to
add it as a pill below the field; the chosen user leaves the candidate list
and the box clears, while any other candidates stay listed until you type
again `[E29]`. Several users can be added; a row matches when it was created
by any of them `[E30]`. The lookup is gated by the same "View Setup and
Configuration" check as the search itself, so it cannot be used as a user
directory by someone who cannot read the audit trail `[E11]`. The `%` and `_`
characters are treated as ordinary text, not wildcards `[E31]`.

To remove one user, click the X on its pill, then click **Search**; changing
a filter does not search by itself `[E29]`. **Reset** clears every filter
(text, sections, users, custom dates, and the date range back to "Last 7
days") and runs the default search again `[E26]`.

### 4.6 Search, Stop and Search further back

**Search** starts a new scan: the result list, the progress counters and the
Top sections / Top users panels are cleared, and the app reads the filters as
they are at that moment `[E32]`. It then asks the server for rows, newest
first, in a loop that stops when any of these happens `[E33]`:

- 50 more rows have been found (one page) `[E34]`;
- the whole date range has been examined;
- you clicked **Stop**;
- 25 server calls have been made for this one click `[E35]`.

Each server call examines at most 10,000 rows (ten batches of 1,000), applies
your text and section filters to them, and returns the matches together with
a cursor that records where the scan stopped; the next call resumes from that
cursor rather than from the top of the range `[E36]`. Rows are shown as each
call returns, and the line next to the **N events** count reports progress
`[E37]`:

- while running: `Searching... examined N events, currently at <date>.`
- when the range is exhausted: `Search complete - examined N events back to
<date>.`
- when the loop stopped early: `Paused - examined N events back to <date>.
More history remains.`

"N events" is the number of matching rows on screen; "examined N events" is
the number of rows the scan has read, matching or not `[E38]`.

**Stop** is shown only while a search is running. It takes effect when the
server call in flight returns; the rows already found stay on screen `[E39]`.
**Search** and **Reset** are disabled while a search is running `[E40]`.

**Search further back** appears whenever a search has stopped before the
range was exhausted, that is, in the Paused state `[E41]`. It continues from
the saved cursor and gathers up to 50 more rows under the same stopping rules,
adding them below the rows already shown `[E42]`. It reads the filter fields
as they are at that moment while continuing the existing scan position, so
if you have changed any filter, click **Search** instead, which starts over
from the top of the range `[E32]`.

### 4.7 Top sections / Top users

Once there are results, two small bar lists show the eight most frequent
sections and the eight most frequent user names among the rows currently on
screen, highest count first, ties in alphabetical order; the bar length is
relative to the largest count `[E43]`. They are recomputed over all rows shown
each time more rows arrive, so after **Search further back** they describe
the whole list, not just the latest page `[E44]`. Rows with a blank section
or user name are not counted `[E45]`.

### 4.8 Results table and View details

The table shows **Date**, **User**, **Section**, **Action** and
**Description** (wrapped), newest first, in a scrolling area `[E46]`. The Date
column is formatted by the Lightning data table using your Salesforce locale
and time-zone settings `[E47]`.

The menu at the right of each row has one entry, **View details**, which
opens an **Event detail** panel below the table with Date, User, Section,
Action, Description, **Delegate user** and **Namespace** `[E48]`. Delegate
user is Salesforce's `DelegateUser` field (the Login-As user who made the
change, when there was one); Namespace is `ResponsibleNamespacePrefix` (the
managed package responsible for the change, when there was one). Both are
often blank. Close the panel with its X; it also closes when a new search
starts `[E49]`.

### 4.9 Export CSV

**Export CSV**, at the top right of the card, is enabled as soon as there is
at least one row and writes every row currently on screen, not only the
visible part of the table, to a file named `audit-trail-YYYY-MM-DD.csv`
`[E50]`. The file is built entirely in your browser and downloaded through
your browser's normal download path; nothing is uploaded or stored on the
server `[E51]`.

Columns, in order: `Date`, `User`, `Section`, `Action`, `Description`,
`Delegate User`, `Namespace` `[E52]`. `Date` is the event time as an ISO-8601
timestamp in UTC, for example `2026-10-11T18:41:07.000Z`, regardless of your
time zone `[E53]`. Rows are separated by CRLF, every cell is wrapped in double
quotes, double quotes inside a value are doubled, and a blank value is an empty
quoted cell `[E54]`.

**Formula-injection protection.** Spreadsheets treat a cell beginning with
`=`, `+`, `-` or `@` as a formula, and audit descriptions can echo text that
someone else typed (a field label, for example). Any exported value that
begins with one of those four characters, with whitespace, with their
full-width look-alikes, with a control character or with a zero-width space is
written with a single apostrophe in front, so the spreadsheet shows it as text
`[E55]`. That apostrophe is the only change made to any exported value; delete
it if you need the raw text.

## 5. Limits and behaviour to expect

- **180 days.** Nothing older can be shown; the notice under the buttons
  states the exact date before which history is gone, computed on the server
  from the current time `[E3]`.
- **One page is 50 rows; one click is at most 25 server calls; one server
  call examines at most 10,000 rows** `[E34]` `[E35]` `[E36]`. A rare search
  term over 180 days in a busy org therefore shows the Paused state after
  reading up to 250,000 rows; click **Search further back** to continue.
- **You see your own view of the audit trail.** The query runs with the
  running user's object and field permissions (`USER_MODE`), behind the same
  "View Setup and Configuration" check Salesforce applies in Setup; the app
  cannot show a user anything Setup would not `[E10]` `[E56]`. The fields it
  reads are `Id`, `CreatedDate`, `Section`, `Action`, `Display`,
  `CreatedById`, `CreatedBy.Name`, `DelegateUser`,
  `ResponsibleNamespacePrefix`, `CreatedByContext` and `CreatedByIssuer`; the
  last two are received by the page but not displayed or exported `[E57]`.
- **Nothing is stored.** Filters, results and the section list exist only in
  the page; reloading the browser tab starts from the defaults. No audit row
  content is written to any log; on an unexpected failure only the exception
  type and message go to the Apex debug log `[E2]` `[E58]`.
- **The user lookup returns active users only, at most 20** `[E27]`. To find
  changes by a deactivated user, search their name as free text instead
  `[E21]`.
- **Section list and Top panels cover what has been examined and shown so
  far**, not the whole org `[E24]` `[E44]`.
- **Time zones differ by surface.** The table's Date column follows your
  Salesforce settings `[E47]`; the detail panel date, the progress text and the
  retention notice follow your browser's locale and time zone `[E59]`; the CSV
  uses UTC `[E53]`.
- **A search runs on every load**, including on a Home page that hosts the
  component; it is one bounded action with the default filters `[E13]`.
- **Lightning Experience only**, and only in editions that allow custom
  Apex (not Professional or Base Edition) `[E60]`.

## 6. Troubleshooting

**The page shows the "View Setup and Configuration" message instead of the
search form.** The user has the packaged permission set but not the second
grant. Grant "View Setup and Configuration" through the profile or a local
permission set (section 3, step B), then reload the page `[E8]`. If the
message instead appears as a red alert above the results after the page had
been working, the permission was removed after the page loaded; the server
rejects every search until it is restored `[E11]` `[E61]`.

**The app is not in the App Launcher.** The user does not have
`atexplorer__Audit_Trail_Viewer` `[E5]`.

**A red alert says "The audit search could not be completed. Please try
again, or contact your administrator if the problem persists."** The server
hit an unexpected error and deliberately shows this fixed text rather than the
platform message. Try again; an administrator with a trace flag on the user
can read the underlying type and message in the Apex debug log, prefixed
`Audit search failed:` `[E58]`.

**"No audit events matched your filters in this range."** The search finished
without a match `[E62]`. Check, in order: the date range ("Today" is only the
last 24 hours `[E17]`); that every word in the text box really appears in the
rows you expect `[E21]`; selected sections and users; a custom range whose
**From** is later than its **To**, which completes immediately with no rows
`[E63]`; and whether the org has had any setup changes in the window at all.
**Reset** returns to the defaults `[E26]`.

**The progress line says "More history remains."** The last click stopped at
50 new rows, at the 25-call bound, or because you pressed **Stop**; the range
has not been fully examined `[E37]`. Click **Search further back** to
continue, or narrow the date range. Only "Search complete" means the whole
range was examined.

**Typing in Filter by user shows no names.** Fewer than two characters were
typed, no active user's name or username contains the text, or the running
user lacks "View Setup and Configuration", in which case the list simply
stays empty `[E27]` `[E64]`.

**Export CSV is greyed out.** There are no rows on screen yet `[E50]`.

**Accented names look wrong in a spreadsheet.** The file is UTF-8 without a
byte-order mark `[E54]`; import it choosing UTF-8 rather than double-clicking
it, or open it in an editor that detects UTF-8.

**CSV times do not match the table.** The CSV is in UTC; the table is in your
Salesforce time zone `[E53]` `[E47]`.

## 7. Uninstall

Uninstalling leaves nothing behind because nothing is stored; see
[`README.md`, Uninstall](../README.md#uninstall) for the Setup and CLI steps
`[E65]`.

## Evidence

Line numbers refer to the source at tag `v1.0.0` (commit `934f200`), which
built version `1.0.0.2`; `force-app` is unchanged at the current `HEAD`, so
they are exact. Other documents in this repository are cited by section
heading rather than by line, because they are revised more often than the
code. Paths are relative to the repository root, and `lwc/` stands for
`force-app/main/default/lwc/auditExplorer/`, `classes/` for
`force-app/main/default/classes/`.

- **E1** `classes/SetupAuditTrailProvider.cls:17-20` (query against
  `SetupAuditTrail`); `README.md`, section "What it does".
- **E2** `docs/PRIVACY.md`, section "What the app does not do" (no object,
  cache, callout, telemetry or browser storage); `docs/ARCHITECTURE.md`,
  section "Component diagram", closing paragraph (no trigger, job, custom
  object or setting); `lwc/auditExplorer.js:48-75` (all state is component
  fields).
- **E3** `classes/AuditQueryService.cls:22,36-41` (180-day floor, applied to
  every search); `classes/AuditQueryController.cls:50-51` (floor date sent
  to the page); `lwc/auditExplorer.js:418-421` and `lwc/auditExplorer.html:125-133`
  (the retention notice).
- **E4** `README.md`, section "Two grants are required".
- **E5** `force-app/main/default/permissionsets/Audit_Trail_Viewer.permissionset-meta.xml:3,7-30`
  (label; class access to `AuditQueryController`, `AuditQueryService`,
  `AuditPermissionService`, `SetupAuditTrailProvider`; app and tab
  visibility; no `objectPermissions` or `fieldPermissions`).
- **E6** `force-app/main/default/permissionsets/Audit_Trail_Viewer.permissionset-meta.xml:31-38`.
- **E7** `docs/LIVE-ORG-VALIDATION.md`, section "Managed packaging strips
  system permissions" (source deploy `true`, managed `false`); its
  subsection "The administrator workaround is verified, not just documented"
  (gate closed with the packaged set alone, open with a local permission set
  added); and section "Install into a persistent Developer Edition org"
  (org `00Dbm00000u2XaoEAE`, `PermissionsViewSetup` and
  `PermissionsViewRoles` `false`).
- **E8** `lwc/auditExplorer.html:249-256` (the message, rendered when
  `canViewSetup` is false); `lwc/auditExplorer.js:77-90` (`canViewSetup`
  comes from `getContext`).
- **E9** `lwc/auditExplorer.html:3-10` (Export button outside the gated
  block); `lwc/auditExplorer.js:427-429` (disabled when there are no rows).
- **E10** `classes/AuditPermissionService.cls:23-25` (`isAccessible()`), with
  the equivalence noted at `:7-10`; `classes/AuditQueryController.cls:53`.
- **E11** `classes/AuditQueryController.cls:20` (`search`) and `:64`
  (`searchUsers`) both call `AuditPermissionService.assertCanViewSetup()`;
  `classes/AuditPermissionService.cls:27-37`.
- **E12** `classes/AuditPermissionServiceTest.cls:5-8` (why the tests use
  "Minimum Access - Salesforce"); `docs/LIVE-ORG-VALIDATION.md`, subsection
  "The administrator workaround is verified, not just documented".
- **E13** `lwc/auditExplorer.js:77-90` (`connectedCallback`: `getContext`,
  then `runSearch(true)` when allowed); `:53` (default preset `'7'`);
  `:56-57,49` (empty text, sections, users).
- **E14** `force-app/main/default/applications/Audit_Trail_Explorer.app-meta.xml:3,6`;
  `force-app/main/default/tabs/Audit_Trail_Explorer.tab-meta.xml:3-4`.
- **E15** `lwc/auditExplorer.js-meta.xml:7-11` (`lightning__Tab`,
  `lightning__AppPage`, `lightning__HomePage`).
- **E16** `lwc/auditExplorer.js:30-37`; `lwc/auditExplorer.html:28-33`.
- **E17** `lwc/auditExplorer.js:129,137` (`Date.now()` minus preset days x
  86,400,000 ms; "Today" is value `1`, line 31).
- **E18** `lwc/auditExplorer.html:70-89`; `lwc/auditExplorer.js:94-96`.
- **E19** `lwc/auditExplorer.js:133-135`.
- **E20** `lwc/auditExplorer.js:139-142` (client clamp);
  `classes/AuditQueryService.cls:36-41` (server clamp).
- **E21** `classes/AuditQueryService.cls:180-187` (terms split on
  whitespace, lower-cased); `:196-213` (haystack of display, section, action
  and user name; every term must be contained).
- **E22** `lwc/auditExplorer.html:17-25` (label, placeholder, help text).
- **E23** `lwc/auditExplorer.js:122-126`.
- **E24** `classes/AuditQueryService.cls:88-90,126` (sections collected from
  every scanned row); `lwc/auditExplorer.js:241,267-284` (merged and sorted
  into the list); `lwc/auditExplorer.html:91-104` (rendered only once the
  list is non-empty; help text).
- **E25** `classes/AuditQueryService.cls:173-179,191-195`.
- **E26** `lwc/auditExplorer.js:168-178` (`handleClear`: resets preset,
  custom dates, text, sections, users and the lookup list, then searches;
  `sectionOptions` is not touched); `lwc/auditExplorer.html:114-119`.
- **E27** `classes/AuditQueryController.cls:66-69` (fewer than 2 characters
  returns nothing); `:78-85` (`Name` or `Username` `LIKE`, `IsActive = TRUE`,
  `ORDER BY Name`, `LIMIT 20`); `lwc/auditExplorer.js:300-306`;
  `lwc/auditExplorer.html:36-57`.
- **E28** `lwc/auditExplorer.js:308-309`.
- **E29** `lwc/auditExplorer.js:316-324` (`handleUserSelect`: appends to
  `selectedUsers`, removes only the picked entry from `userResults`, clears
  `userSearchTerm`; `:335-337` keeps the candidate box open while
  `userResults` is non-empty); `:326-329` (`handleUserRemove` drops one user
  from `selectedUsers`); `lwc/auditExplorer.html:59-66` (pill container with
  `onitemremove`). Neither handler starts a search; see `[E32]`.
- **E30** `lwc/auditExplorer.js:149` (`userIds`);
  `classes/SetupAuditTrailProvider.cls:25-27` (`CreatedById IN :userIds`).
- **E31** `classes/AuditQueryController.cls:70-77`.
- **E32** `lwc/auditExplorer.js:156-158,180-200` (`runSearch(true)` clears
  rows, cursor, counters, detail and facets at 189-198; the filter is read
  at line 200 on every call, including load-more at 160-162).
- **E33** `lwc/auditExplorer.js:207-223`.
- **E34** `lwc/auditExplorer.js:39,201` (`PAGE_SIZE = 50`, target is current
  rows plus 50); `classes/AuditQueryService.cls:26,103-106`.
- **E35** `lwc/auditExplorer.js:41,211` (`MAX_CALLS_PER_ACTION = 25`).
- **E36** `classes/AuditQueryService.cls:24-25` (`SCAN_BATCH = 1000`,
  `MAX_BATCHES_PER_CALL = 10`); `:69-77,94-96,113-118` (batch loop and cursor
  advance); `classes/AuditCursor.cls:35-43` (cursor records the last
  timestamp and the ids consumed at it);
  `classes/SetupAuditTrailProvider.cls:28-33` (consumed ids excluded,
  `ORDER BY CreatedDate DESC`); `lwc/auditExplorer.js:217-221,237` (cursor
  sent back on the next call).
- **E37** `lwc/auditExplorer.js:402-416`; `lwc/auditExplorer.html:143-150`.
- **E38** `lwc/auditExplorer.js:386-388,239` (`resultCount` is rows shown;
  `scannedTotal` accumulates `scannedCount`);
  `classes/AuditSearchResult.cls:10-12`.
- **E39** `lwc/auditExplorer.js:164-166,209` (flag checked before the next
  call); `lwc/auditExplorer.html:120-122`.
- **E40** `lwc/auditExplorer.html:107-119` (`disabled={loading}`);
  `lwc/auditExplorer.js:181-183`.
- **E41** `lwc/auditExplorer.js:398-400`; `lwc/auditExplorer.html:197-201`.
- **E42** `lwc/auditExplorer.js:160-162,189,201,236`.
- **E43** `lwc/auditExplorer.js:253-265` (count, sort by count then label);
  `:286-296` (first eight, bar width relative to the largest);
  `lwc/auditExplorer.html:152-176`.
- **E44** `lwc/auditExplorer.js:242-249` (recomputed over `this.rows` after
  every call).
- **E45** `lwc/auditExplorer.js:256-259`.
- **E46** `lwc/auditExplorer.js:7-26,98-100`; `lwc/auditExplorer.html:178-189`
  (`lightning-datatable`, 30rem container);
  `classes/SetupAuditTrailProvider.cls:33` (newest first).
- **E47** `lwc/auditExplorer.js:9-20` (column `type: 'date'` with
  `typeAttributes`, rendered by `lightning-datatable`).
- **E48** `lwc/auditExplorer.js:28,341-345`; `lwc/auditExplorer.html:203-246`;
  `classes/AuditEventRow.cls:45-46` (`DelegateUser`,
  `ResponsibleNamespacePrefix`).
- **E49** `lwc/auditExplorer.js:347-349,195`; `lwc/auditExplorer.html:208-213`.
- **E50** `lwc/auditExplorer.html:3-10`; `lwc/auditExplorer.js:357-363,379,427-429`
  (iterates `this.rows`; file name from the current UTC date).
- **E51** `lwc/auditExplorer.js:376-381` (`Blob`, `URL.createObjectURL`,
  programmatic click); `docs/PRIVACY.md`, section "CSV export".
- **E52** `lwc/auditExplorer.js:361,365-373`.
- **E53** `lwc/auditExplorer.js:366` (`toISOString()`).
- **E54** `lwc/auditExplorer.js:376` (`\r\n`, `text/csv;charset=utf-8`, no
  byte-order mark prepended); `lwc/csv.js:39-52` (quoting, doubled quotes,
  `""` for null or undefined).
- **E55** `lwc/csv.js:8-37` (trigger set and rationale: `=`, `+`, `-`, `@`,
  whitespace, full-width U+FF1D/FF0B/FF0D/FF20, C0 controls, U+200B);
  `:44-46` (single apostrophe prepended, nothing else changed).
- **E56** `classes/SetupAuditTrailProvider.cls:35-40`
  (`AccessLevel.USER_MODE`); `classes/AuditQueryController.cls:82`
  (`WITH USER_MODE` on the user lookup); `docs/PRIVACY.md`, section "Access
  control".
- **E57** `classes/SetupAuditTrailProvider.cls:18-19` (selected fields);
  `classes/AuditEventRow.cls:37-49` (mapped to the row);
  `lwc/auditExplorer.js:7-26,361-373` and `lwc/auditExplorer.html:216-243`
  (`createdByContext` and `createdByIssuer` are neither shown nor exported).
- **E58** `classes/AuditQueryController.cls:15` (the fixed message);
  `:32-33,37-44` (every non-permission exception is replaced by it; type and
  message written with `System.debug` at line 38).
- **E59** `lwc/auditExplorer.js:352` (`toLocaleString()` in the detail
  panel); `:406-408` (progress text); `:419` (`toLocaleDateString()` in the
  retention notice).
- **E60** `docs/ARCHITECTURE.md`, section "Known limitations"; `README.md`,
  section "Install" (the editions note); `lwc/auditExplorer.js-meta.xml:7-11`.
- **E61** `classes/AuditQueryController.cls:28-31` (permission error passed
  to the page unchanged); `classes/AuditPermissionService.cls:29-35` (its
  text); `lwc/auditExplorer.js:224-225,431-439` and
  `lwc/auditExplorer.html:135-141` (shown as the alert).
- **E62** `lwc/auditExplorer.html:191-195`; `lwc/auditExplorer.js:394-396`
  (shown after a search, when not loading, with no rows and no error).
- **E63** `classes/AuditQueryService.cls:51-56` (upper bound below lower
  bound returns `done` with no rows).
- **E64** `lwc/auditExplorer.js:302-305,311-313` (short terms and any
  rejected lookup both leave the list empty).
- **E65** `README.md`, section "Uninstall"; `docs/PRIVACY.md`, section "What
  the app does not do" (the uninstall row).
