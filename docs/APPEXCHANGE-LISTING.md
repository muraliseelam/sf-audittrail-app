# AppExchange Listing Draft

This is a **draft** of listing copy for internal review before submission. It
makes no claims of AppExchange certification, security review approval,
customer adoption, or install counts — those are added by Salesforce/AppExchange
processes, not by this repository.

> **Not ready to publish as-is.** The package described here is an
> **unreleased managed beta** and has not been submitted for AppExchange
> Security Review. Do not publish this listing (or any variant of it) until
> the package described in
> [`docs/LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md) is a promoted,
> security-reviewed release. Update the install link and version references
> below at that time.

## Listing name

Audit Trail Explorer

## Tagline (≤ 10 words)

Search, filter, and export your Setup Audit Trail.

## Short description (≤ 250 characters)

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
  changes by free text, section, action, changed-by user, and date range.
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

- Enterprise, Unlimited, Performance, or Developer Edition (custom Apex is
  required; Professional Edition is not supported).
- Lightning Experience.
- The packaged `Audit_Trail_Viewer` permission set, which grants the app, its
  tab, and its Apex classes.
- **"View Setup and Configuration", granted separately by your
  administrator.** Salesforce strips system permissions from a managed
  package's permission sets on install, so the packaged permission set cannot
  grant this on your behalf. Grant it through your own profile or permission
  set, alongside `Audit_Trail_Viewer`.

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

## Screenshots / demo assets needed (not included in this repo)

- [ ] Search screen with results populated and facets visible.
- [ ] Row detail panel.
- [ ] CSV export in a spreadsheet application.
- [ ] Permission set assignment screen (install experience).

## Claims explicitly NOT made in this draft

Per project policy, this draft does not state or imply: AppExchange security
review approval/certification, a specific install/download count, customer
testimonials or reviews, or any EB-1A/immigration-related claim. Any such
statement must come from the actual AppExchange review outcome and real,
consenting customers — not from this repository.
