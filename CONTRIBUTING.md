# Contributing

Thanks for considering a contribution to Audit Trail Explorer.

## Reporting bugs and requesting features

Open a GitHub issue. For bugs, include:

- Salesforce edition and API version.
- Steps to reproduce, including the filter/date-range combination used.
- Whether you are on the packaged version or a source deploy.

For a suspected **security** vulnerability, do not open a public issue —
see [SECURITY.md](SECURITY.md) instead.

## Development setup

```bash
git clone https://github.com/muraliseelam/sf-audittrail-app.git
cd sf-audittrail-app
npm install

# Deploy to a scratch org or sandbox
sf org create scratch --definition-file config/project-scratch-def.json --alias audittrail-dev --set-default
sf project deploy start --source-dir force-app --target-org audittrail-dev
sf org assign permset --name Audit_Trail_Viewer --target-org audittrail-dev
```

## Before opening a pull request

Run the checks that CI also runs, and make sure they're all clean:

```bash
npm run lint             # ESLint over the LWC/Aura source
npm run prettier:verify  # Formatting check (run `npm run prettier` to fix)
npm run test:unit        # Jest tests for the LWC
sf project deploy start --source-dir force-app --target-org audittrail-dev --test-level RunLocalTests
```

The Apex test suite requires a Salesforce org (scratch org, sandbox, or
Developer Edition) because `SetupAuditTrail` records cannot be inserted by a
unit test — several tests validate behavior against the real object and the
real permission model. CI cannot run these without org credentials; please
run them locally and report the result (org edition + pass/fail) in your PR
description.

If you have the Salesforce Code Analyzer plugin, also run:

```bash
sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
  --rule-selector Recommended --rule-selector Security --rule-selector AppExchange
```

## Code style

- Apex: `with sharing` on every class; no inline SOQL/SOSL built from
  concatenated user input — always use bind variables; prefer
  `AccessLevel.USER_MODE` / `WITH USER_MODE` for CRUD/FLS enforcement.
- LWC: no `lwc:dom="manual"`, no `innerHTML`/`eval`; render user-controlled
  text only through `{}` template interpolation.
- Formatting is enforced by Prettier (`npm run prettier`) and is not
  independently bikeshedded in review.

## Pull request checklist

- [ ] Tests added or updated for the changed behavior (Jest for LWC, Apex
      tests for Apex — run locally against an org and report the result).
- [ ] `npm run lint`, `npm run prettier:verify`, and `npm run test:unit` pass.
- [ ] No new custom object, trigger, scheduled job, external callout, or
      stored/cached data was introduced without discussion — the project's
      "zero storage footprint" design is a deliberate constraint, not an
      oversight.
- [ ] CSV/export changes were checked against formula/injection payloads
      (see the tests in `force-app/main/default/lwc/auditExplorer/__tests__/`).

## Sign-off

By submitting a pull request, you agree that your contribution is licensed
under the project's [Apache License 2.0](LICENSE).
