# AppExchange Listing Draft

This is a **draft** of listing copy for internal review before submission. It
makes no claims of AppExchange certification, security review approval,
customer adoption, or install counts — those are added by Salesforce/AppExchange
processes, not by this repository.

> **Not published.** The package described here is a **released managed 2GP
> version** (`1.0.1.4`, `04thm000002tWirAAE`, promoted 2026-10-12) that has
> **not** yet passed AppExchange Security Review. Its listing exists only as a
> draft in the Partner Console (created 2026-10-14, linked to `1.0.1.4`). Do
> not publish the listing, or any variant of it, until
> [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) records that the
> review has been passed. Update the install link and version references
> below at that time.

The Listing Builder's own field help gives each field's character limit; the
draft listing was entered within those limits.

## Listing name

Audit Trail Explorer

## Tagline

Search, filter, and export your Setup Audit Trail.

## Short description

Fast, filterable search over Salesforce's Setup Audit Trail. Search by
description, section, user, or date — something native Setup can't do —
and export to CSV. Read-only, no custom objects, no external callouts,
nothing stored.

## Full description

Salesforce's built-in Setup Audit Trail is one of the most useful compliance
and troubleshooting tools in the platform — and one of the hardest to
actually search. It shows 20 rows at a time, and you cannot filter by the two
fields you usually want: the change description ("Display") or the section
("Section"). Audit Trail Explorer fixes that without adding a single byte of
storage to your org.

**What it does**

- Search up to 180 days (Salesforce's retention limit) of setup/configuration
  changes by free text, section, changed-by user, and date range.
- See which sections and users show up most in your current result set.
- Open any event for detail: delegate user and namespace.
- Export the current result set to CSV for offline review or audit
  evidence — with spreadsheet-formula-injection protection built in.

**What it doesn't do**

- Store anything. It queries `SetupAuditTrail` live on every search and keeps
  nothing server-side. Uninstalling the package leaves zero residue.
- Call out anywhere. No named credential, no remote site setting, no
  third-party service of any kind.
- Bypass Salesforce's permission model. The runtime enforces the same "View
  Setup and Configuration" permission Salesforce requires to view the audit
  trail natively. The app cannot grant a user any access they don't already
  have - see the requirements below.

**Requirements**

- Enterprise, Unlimited, Performance, or Developer Edition. Custom Apex is
  required, so editions without it are not supported — this includes
  Professional Edition and Base Edition.
- Lightning Experience.
- The packaged `atexplorer__Audit_Trail_Viewer` permission set, which grants
  the app, its tab, and its Apex classes.
- **"View Setup and Configuration", granted separately by your
  administrator.** Salesforce strips system permissions from a managed
  package's permission sets on install, so the packaged permission set cannot
  grant this on your behalf. Grant it through your own profile or permission
  set, alongside `atexplorer__Audit_Trail_Viewer`.

## Categories

- IT & Administration Tools
- Analytics
- Security & Compliance

## Pricing

Free / open source (Apache License 2.0). See [LICENSE](../LICENSE).

## Support

Community support via GitHub issues:
`https://github.com/muraliseelam/sf-audittrail-app/issues`. See
[SECURITY.md](../SECURITY.md) for reporting security concerns privately.

## Other Listing Builder fields (draft listing, 2026-10-14)

The sections above cover only part of the form. The draft listing holds these
values for the remaining fields:

- Highlights:
    - Search up to 180 days of Setup Audit Trail changes by text, section,
      user and date.
    - Export results to CSV with spreadsheet-formula-injection protection.
    - Stores nothing: queries the audit trail live, with no custom objects and
      no external callouts.
    - Respects Salesforce permissions: users need View Setup and
      Configuration, granted by your admin.
- SEO title: Audit Trail Explorer - Search and Export Your Setup Audit Trail.
- Required Salesforce products: none. Supported editions: Enterprise,
  Unlimited, Performance and Developer (see the edition note under Install in
  [README.md](../README.md#install)).
- Supported languages: English.
- Supported features: Lightning Experience.
- Industries: none selected (not industry-specific).
- Target user persona: Administrator.
- Business needs: Analytics; IT & Administration.
- Installation method: install from the AppExchange listing.
- Lead org: not set.
- Support: community support through GitHub issues (the knowledge center link
  is this repository); no support email, phone or SLA is published yet.
- Provider: Murali Mohan Reddy Seelam (individual publisher); website and phone
  not set.
- Customer terms and conditions: none beyond Salesforce's own.
  [LICENSE](../LICENSE) is the Apache-2.0 software licence, not customer
  terms.
- Privacy policy URL: not set yet. The builder needs a hosted URL;
  [docs/PRIVACY.md](PRIVACY.md) is the policy text.

## Visual assets

None exist yet. The repository contains no PNG, JPG or SVG outside
`node_modules/` and `coverage/`, and the app has no custom icon (the tab uses
the standard `Custom53: Bell` motif). The sizes below are legacy published
guidance and must be confirmed against the builder's field help before any
image is produced: small logo PNG 60x60 up to 100 KB; tile logo PNG 280x205
up to 300 KB; banner PNG 1200x300 up to 1 MB; up to eight screenshots PNG up
to 1 MB each.

Do not take screenshots in org `00DRK00000aOfV72AK`: its Setup Audit Trail
permanently holds the seeded "ATE Bulk" rows (see the note at the end of the
"Functional UI verification of the managed install — 2026-09-13" section of
[docs/LIVE-ORG-VALIDATION.md](LIVE-ORG-VALIDATION.md)). Review the chosen
org's audit trail for real usernames before publishing any image.

Screenshots still to be produced (not included in this repo):

- [ ] Search screen with results populated and facets visible.
- [ ] Row detail panel.
- [ ] CSV export in a spreadsheet application.
- [ ] Permission set assignment screen (install experience).

## Claims explicitly NOT made in this draft

Per project policy, this draft does not state or imply: AppExchange security
review approval/certification, a specific install/download count, or customer
testimonials or reviews. Any such
statement must come from the actual AppExchange review outcome and real,
consenting customers — not from this repository.
