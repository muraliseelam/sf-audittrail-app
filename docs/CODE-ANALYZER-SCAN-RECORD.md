# Code Analyzer Scan Record

Dated results of each Salesforce Code Analyzer run against this repository, so
the dispositions in
[`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md)
can be checked against a real execution rather than taken on trust. The
generated reports (`CodeAnalyzerReport.html`, `ca-report.json`) are build
artifacts and are deliberately gitignored; this file is the committed evidence
of what they contained.

**This is a static-analysis record, not a review outcome.** The package has not
been submitted for, or passed, AppExchange Security Review and has no
AppExchange listing. See
[`LIVE-ORG-VALIDATION.md`](LIVE-ORG-VALIDATION.md).

## 2026-09-10 — source commit `934f200`

### Environment

| Item                 | Value                                            |
| -------------------- | ------------------------------------------------ |
| Code Analyzer plugin | `5.15.0`                                         |
| Salesforce CLI       | `@salesforce/cli/2.98.6` win32-x64, node 22.17.0 |
| JDK                  | OpenJDK 21.0.12 (Microsoft build, LTS)           |
| Host memory          | 7.72 GB total                                    |
| Workspace scanned    | `force-app`                                      |

PMD, CPD and the Graph Engine need a local JDK; without one they fail to load
and are skipped silently, producing a false all-clear. The JDK above was
present, so those engines genuinely executed.

### Rule selection

The three-flag selector resolved to **310 rules across 6 engines**, matching the
count pinned in [`code-analyzer.yml`](../code-analyzer.yml):

| Engine      | Rules   |
| ----------- | ------- |
| `eslint`    | 202     |
| `pmd`       | 94      |
| `regex`     | 6       |
| `retire-js` | 4       |
| `cpd`       | 2       |
| `sfge`      | 2       |
| **Total**   | **310** |

A count of 0 here would mean the scan proves nothing regardless of how clean it
looks, which is why the count is recorded rather than assumed.

### Run 1 — all six engines

```
sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
  --rule-selector Recommended --rule-selector Security --rule-selector AppExchange \
  --output-file CodeAnalyzerReport.html --output-file ca-report.json
```

**85 violations across 16 files.** Zero Critical, zero High.

| Rule                                            | Engine | Count |
| ----------------------------------------------- | ------ | ----- |
| `ApexDoc`                                       | pmd    | 29    |
| `ApexUnitTestClassShouldHaveRunAs`              | pmd    | 26    |
| `@salesforce-ux/slds/no-hardcoded-values-slds2` | eslint | 18    |
| `ExcessiveParameterList`                        | pmd    | 4     |
| `CognitiveComplexity`                           | pmd    | 3     |
| `CyclomaticComplexity`                          | pmd    | 2     |
| `AvoidDebugStatements`                          | pmd    | 1     |
| `NcssCount`                                     | pmd    | 1     |
| `@lwc/lwc-platform/no-inline-disable`           | eslint | 1     |

`retire-js` and the `regex` secrets engine each reported **0 violations**.

> **The Graph Engine portion of this run is INVALID and is not used.** It
> reported:
>
> ```
> sfge: Overall, analyzed 3 path(s) from 2 entry point(s). Detected 0 violation(s).
> Error: Engine 'sfge': Internal execution error while scanning entry point:
>        AuditQueryController.cls:18:37: Path evaluation timed out after 600000 ms
> ```
>
> Free host memory measured **during** this run was 0.8 GB, against a 2 GB
> heap request. The outcome matches the `3 path(s) from 2 entry point(s)`
> signature that `code-analyzer.yml` documents for a heap request the host
> cannot satisfy; memory pressure is the likely cause but was not proven by
> controlled experiment. Either way the "0 violations" it printed is the
> vacuous all-clear that comment warns about, and it is disregarded here in
> favour of Run 2.

### Run 2 — Graph Engine alone (authoritative for `sfge`)

Run on an otherwise idle host, per the verification procedure in
`code-analyzer.yml`:

```
sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
  --rule-selector sfge --output-file ca-sfge.json
```

```
sfge: Detected 0 violation(s) from 14503 path(s) on 3/3 entry point(s)
Found 0 violations.
```

This meets the validity bar exactly — **14,503 paths, 3/3 entry points, no
`Internal execution error`** — so the two Graph Engine rules genuinely
executed to completion:

- `sfge:ApexFlsViolation` — **0 violations**
- `sfge:DatabaseOperationsMustUseWithSharing` — **0 violations**

These are the two rules most relevant to an AppExchange security review, and
they are tagged `DevPreview`, so only the `Security` selector reaches them.

### Combined result

| Severity  | Count  |
| --------- | ------ |
| Critical  | **0**  |
| High      | **0**  |
| Moderate  | 11     |
| Low       | 74     |
| **Total** | **85** |

No violation of any severity carries the `Security`, `AppExchange` or
`ErrorProne` tag. These counts reproduce the table in
[`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md)
exactly; each finding is dispositioned there.

### Operational note for this host

On a 7.72 GB machine the Graph Engine must be run **alone**. Run 1 and Run 2
scanned identical source with identical configuration and differed only in
concurrency, and that alone decided whether the analysis completed (14,503
paths) or was abandoned after 3. Treat any Graph Engine result that does not
name its path and entry-point counts as unproven, and re-run it on its own
before recording it.

## 2026-09-19 — source commit `5c70c8c`

Produced by the `Code Analyzer` workflow rather than by hand:
[run 35450675758](https://github.com/muraliseelam/sf-audittrail-app/actions/runs/35450675758),
dispatched on branch `wt/audittrail`, every step green in 17m33s.

### Why this run exists

Code Analyzer 5.16.0 no longer executes an ESLint configuration file that it
discovered automatically, because such a file's top-level JavaScript would run
during analysis. `auto_discover_eslint_config: true` therefore stopped applying
`eslint.config.js`, the ESLint engine fell back to its bundled defaults, and the
selector silently lost `jest/no-deprecated-functions` — **309 rules, 201
eslint**. That was
[run 35449263094](https://github.com/muraliseelam/sf-audittrail-app/actions/runs/35449263094),
which failed the rule-count check in `.github/workflows/code-analyzer.yml`
rather than publishing a scan that no longer reflected the lint rules this
project enforces. Catching exactly this is why the count is checked.

Commit `5c70c8c` adds the explicit `eslint_config_file` the plugin now requires.
The fix was first measured locally on 5.16.0 — rule selection only — and the run
below is its first full verification.

### Environment

| Item                 | Value                                             |
| -------------------- | ------------------------------------------------- |
| Code Analyzer plugin | `5.16.0`, installed as `code-analyzer@latest`     |
| Salesforce CLI       | `@salesforce/cli/2.150.6` linux-x64, node 22.23.2 |
| JDK                  | OpenJDK 21.0.12.1 (Temurin, LTS)                  |
| Runner               | `ubuntu-latest`, GitHub Actions                   |
| Workspace scanned    | `force-app`                                       |

Unlike the 2026-09-10 entry this is not a developer workstation. The CLI, the
plugin and the JDK are installed fresh on every run, which is why a plugin
release reaches CI before it reaches any local machine.

### Rule selection

| Engine      | Rules   |
| ----------- | ------- |
| `eslint`    | 202     |
| `pmd`       | 94      |
| `regex`     | 6       |
| `retire-js` | 4       |
| `cpd`       | 2       |
| `sfge`      | 2       |
| **Total**   | **310** |

Identical to 2026-09-10 rule for rule, not merely in total: comparing the full
rule-name lists from the 5.15.0 run and this one gives no additions and no
removals. The count pinned in [`code-analyzer.yml`](../code-analyzer.yml) still
describes the same rule set.

With the explicit setting the engine warns that the configured file contains
executable JavaScript that will run during analysis. That is an advisory about a
file committed to this repository, not the silent fallback it replaced.

### Run 1 — all six engines

```
sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
  --rule-selector Recommended --rule-selector Security --rule-selector AppExchange \
  --output-file CodeAnalyzerReport.html --output-file ca-report.json \
  --severity-threshold 2
```

**85 violations across 16 files.** Zero Critical, zero High.

| Rule                                            | Engine | Count |
| ----------------------------------------------- | ------ | ----- |
| `ApexDoc`                                       | pmd    | 29    |
| `ApexUnitTestClassShouldHaveRunAs`              | pmd    | 26    |
| `@salesforce-ux/slds/no-hardcoded-values-slds2` | eslint | 18    |
| `ExcessiveParameterList`                        | pmd    | 4     |
| `CognitiveComplexity`                           | pmd    | 3     |
| `CyclomaticComplexity`                          | pmd    | 2     |
| `AvoidDebugStatements`                          | pmd    | 1     |
| `NcssCount`                                     | pmd    | 1     |
| `@lwc/lwc-platform/no-inline-disable`           | eslint | 1     |

Every rule and every count reproduces the 2026-09-10 table exactly, on a
different operating system and a newer plugin. `retire-js` and the `regex`
secrets engine again reported **0 violations**.

### Run 2 — Graph Engine alone (authoritative for `sfge`)

```
sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
  --rule-selector sfge --output-file ca-sfge.json
```

```
sfge: Detected 0 violation(s) from 14503 path(s) on 3/3 entry point(s).
Found 0 violations.
```

This meets the validity bar — **14,503 paths, 3/3 entry points, no
`Internal execution error`** — so both Graph Engine rules executed to
completion. The workflow gives this step its own `sf code-analyzer run`, after
the six-engine scan, for the memory reason recorded in the 2026-09-10
operational note.

### Combined result

| Severity  | Count  |
| --------- | ------ |
| Critical  | **0**  |
| High      | **0**  |
| Moderate  | 11     |
| Low       | 74     |
| **Total** | **85** |

Unchanged from 2026-09-10, so the dispositions in
[`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md)
still describe this scan. The generated reports are attached to the run as the
`code-analyzer-reports` artifact and expire after 30 days; this file is the
durable record.
