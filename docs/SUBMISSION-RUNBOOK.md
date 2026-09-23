# AppExchange Security Review — Submission Runbook

The ordered sequence from the current state to a submitted security review.
Requirements are taken from the ISVforce Guide, "Prepare for the AgentExchange
Security Review" and "Manage Your AgentExchange Listings", read 2026-09-20.
Salesforce's documentation is now written for **AgentExchange**; it is the same
review process and the same wizard that gates an AppExchange listing.

**Current state:** released managed 2GP `1.0.0.2` (`04thm000002OtQPAA0`), not
submitted, no listing. See
[`LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) for the authoritative status.

## What can and cannot be automated

| Category                                          | Who         |
| ------------------------------------------------- | ----------- |
| Partner Console and Partner Community actions     | **Human**   |
| Partner Security Portal (Checkmarx) actions       | **Human**   |
| Creating a Developer Edition org (account signup) | **Human**   |
| The submission itself, and signing agreements     | **Human**   |
| Everything inside an authorised org, via `sf`     | Automatable |
| Repository documentation and scan records         | Automatable |

Nothing in the Partner Console can be driven from this repository. Those steps
need a partner login and are deliberately listed as manual.

---

## Phase 0 — Partner Console prerequisites

Salesforce lists five preconditions under "Ensure That You're Ready to Start".
Accessing the console at all requires the **Manage Listings** permission on the
Partner Community user.

Work through these at <https://partners.salesforce.com>, then record the outcome
in the Partner Console prerequisites checklist in
[`LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md), replacing each `unverified`.

1. **ISV Partner Program enrolment and a Partner Business Org.** The packaging
   Dev Hub `partner-pbo` (`00Dhm000004MOXjEAO`) implies this exists. Confirm it
   rather than inferring it.
2. **Lightning Ready certification.** Mandatory for all new submissions. This
   app is Lightning Web Components only, with no Aura, Visualforce or Classic
   surface, so it should certify without code changes.
3. **Connect the packaging org to the Partner Console.** Partner Console →
   Technologies → Solutions. Connect the org that owns package
   `0Hohm0000000NHZCA2`.
4. **Create the company / provider profile.** Partner Console → Company Info.
5. **Designate security leadership contacts.** Partner Console → Company Info.
   The console prompts for these on login and re-prompts every six months.
   Salesforce uses them only for security incident response; they are not
   published. Prefer an address that will not be spam-filtered — Salesforce
   specifically warns against generic usernames such as `security@`.

**Checkpoint.** Partner Console → Technologies → Solutions should show version
`1.0.0.2` with a listing-readiness value. Expect **Security Review Required**;
that is the correct value before submission and confirms the console can see the
package.

---

## Phase 1 — Build the reviewer's Developer Edition org

The existing DE org `00Dbm00000u2XaoEAE` **cannot** be used. It was inspected on
2026-09-20 and disqualified on four counts, recorded in
[`LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).

### 1.1 Sign up a fresh org — manual

<https://developer.salesforce.com/signup>, under your own name, using an address
you control. A `+` alias on an existing mailbox is fine and keeps the mail
threaded. Developer Edition orgs do not expire the way scratch orgs do.

This org exists **only** for the security review. Do not install anything else
into it, and do not reuse it for demos or screenshots — Setup Audit Trail is
append-only, so anything done in it is permanent.

### 1.2 Authorise it locally — manual

```bash
sf org login web --alias review-de
```

The browser handles authentication; no credential passes through tooling.

### 1.3 Everything after this point is automatable

Once `review-de` is authorised:

- install `04thm000002OtQPAA0`
- assign `atexplorer__Audit_Trail_Viewer`
- create a permission set in the subscriber org granting **View Setup and
  Configuration**, since the packaged one cannot — this is the documented
  administrator workaround, and the reviewer must see it configured
- create a non-administrator test user on **Minimum Access - Salesforce**,
  carrying both grants
- seed audit history across several sections, deep enough that paging, faceting
  and CSV export all return meaningful results
- run the packaged Apex tests and re-confirm the permission strip
- record the org id, test-user credentials location, and evidence in
  `LIVE-ORG-VALIDATION.md`

### 1.4 Why the test user matters more here than for most apps

Managed packaging strips system permissions on install, so
`atexplorer__Audit_Trail_Viewer` alone does not open the app. A reviewer who
logs in as an administrator sees it work — but only because the administrator
profile already carries `ViewSetup`, which masks the real behaviour. A reviewer
who logs in as anyone else sees every search fail.

Both paths must be demonstrable, and the handover note must say so before the
reviewer discovers it. This is the single most likely cause of a confused or
failed first review for this package.

---

## Phase 2 — Scans

### 2.1 Salesforce Code Analyzer — done, keep current

Required for managed packages. Already run and recorded in
[`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md): 0 Critical,
0 High, 11 Moderate, 74 Low, with the Graph Engine completing all 14,503 paths
across 3/3 entry points.

Re-run and re-record if the package source changes before submission. The
`Code Analyzer` GitHub workflow does this on demand and verifies the result by
rule and path counts rather than by a bare "0 violations".

Submit `CodeAnalyzerReport.html` from a run against the **exact source** of
`1.0.0.2`.

> The scan command used here is broader than the one Salesforce documents, for
> a measured reason: the documented selector engages no Graph Engine rules at
> all. See "Relationship to the selector Salesforce documents" in
> [`SECURITY-REVIEW-SOLUTION-DOC.md`](SECURITY-REVIEW-SOLUTION-DOC.md). Have
> that explanation ready; a reviewer comparing commands will ask.

### 2.2 Checkmarx / Source Code Scanner — not started, manual

Required **in addition to** Code Analyzer for any submission containing a
Salesforce package. Hosted on the Partner Security Portal, not runnable locally.

1. Log in to the Partner Security Portal from the Partner Community.
2. Link the package and run the Source Code Scanner against `1.0.0.2`.
3. Review the findings. Fix what is genuinely fixable; document the rest as
   false positives.
4. Re-run, and keep the final report for submission.

**Open question to settle first.** Salesforce documents three scanner runs
provisioned per package version "with the security review fee", and no fee is
payable for a free solution. Whether the runs are provisioned anyway is not
stated. Ask at Partner Security Portal office hours before planning around a
three-run budget — an appointment can be booked from the portal, and the
Security Review Operations team handles submission-mechanics questions.

### 2.3 DAST — not applicable

Required only for external endpoints. This package makes no callouts, has no
named credential and no remote site setting, so there is no external surface to
scan. State this in the submission rather than leaving the field empty.

---

## Phase 3 — Assemble the materials

For a "Salesforce Native Solution with Lightning Components":

| Material                               | Source                                                                                               | Status      |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------- | ----------- |
| Managed—Released package version       | `04thm000002OtQPAA0`                                                                                 | Ready       |
| Developer Edition org with the package | Phase 1                                                                                              | Outstanding |
| Code Analyzer report                   | [`CODE-ANALYZER-SCAN-RECORD.md`](CODE-ANALYZER-SCAN-RECORD.md)                                       | Ready       |
| Checkmarx report                       | Phase 2.2                                                                                            | Outstanding |
| False-positives document               | Phase 2.2, plus [`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md) | Partial     |
| Solution documentation                 | [`SECURITY-REVIEW-SOLUTION-DOC.md`](SECURITY-REVIEW-SOLUTION-DOC.md)                                 | Ready       |
| Company security-program documentation | [`SECURITY-PROGRAM.md`](SECURITY-PROGRAM.md)                                                         | Ready       |

On the false-positives document: Salesforce means scanner findings claimed to be
non-issues, principally from Checkmarx.
`SECURITY-REVIEW-FINDINGS-DISPOSITION.md` disposes of Code Analyzer
code-quality findings and is useful supporting material, but it is not a
substitute and cannot be completed until the Checkmarx scan exists.

---

## Phase 4 — Submit

Partner Console → the security review wizard.

- Attach the materials from Phase 3.
- Provide the Phase 1 org and its credentials, including the test user.
- Include the handover note explaining the two-grant requirement.
- **No fee** is payable for a solution distributed free of charge.

Then expect, per Salesforce's published estimates:

| Stage                                              | Typical time |
| -------------------------------------------------- | ------------ |
| Security Review Operations verifies the submission | 1–2 weeks    |
| Product Security tests the solution                | 3–4 weeks    |
| Re-test after a non-approval                       | 2–3 weeks    |

Do not create new package versions while a submission is in flight. Listing
readiness is inherited from a **passed** ancestor, so a version built before the
ancestor passes does not inherit anything and would need its own review.

---

## Phase 5 — After approval

Only once the review has actually passed:

1. Create the AppExchange listing. Draft copy is in
   [`APPEXCHANGE-LISTING.md`](APPEXCHANGE-LISTING.md); it still needs
   screenshots, which require a **fresh** org — not the reviewer's org, and not
   `00DRK00000aOfV72AK`, whose audit trail permanently contains seeded test
   entries.
2. Submit the listing for approval against brand and program policy. This is a
   separate review from the security review.
3. Sign the Partner Application Distribution Agreement.
4. Register the package with the License Management App so installs produce
   license records.
5. Update `README.md`, `APPEXCHANGE-LISTING.md` and `LIVE-ORG-VALIDATION.md` to
   reference the listing.

Until step 1, every "not reviewed, not listed" statement in this repository
remains accurate and must stay.

---

## Open questions

Neither blocks starting, but both are worth resolving early.

1. **Checkmarx entitlement without a fee.** See Phase 2.2. Partner Security
   Portal office hours.
2. **Which Dev Hub owns the lineage.** The managed package is permanently bound
   to `partner-pbo` (`00Dhm000004MOXjEAO`) and cannot be moved. Confirm the
   Partner Console is connected to that same org and not to one of the other
   three authorised Dev Hubs.
