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

## 2026-10-11 — source commit `934f200` (shipped source) / HEAD `f27a009`

Three runs on the maintainer's workstation during the pre-submission readiness
audit. `HEAD` was `f27a009`. `git diff --stat v1.0.0..HEAD -- force-app
sfdx-project.json` is empty, so the source scanned from the working tree in
Runs 1 and 2 is the source that built released managed version `1.0.0.2`
(`04thm000002OtQPAA0`) from tag `v1.0.0`, commit `934f200`. The seven commits
since the tag (`4f50909`, `3a31a52`, `d50567c`, `b4938a4`, `8f2b27a`,
`5c70c8c`, `f27a009`) touch docs, CI and config only. Run 3 was made from a
clean worktree checked out at `934f200` itself.

### Why this run exists

- The last recorded scan is CI's of 2026-09-19, and its report artifact
  expires after 30 days. This entry re-establishes the result on a toolchain
  newer than either previous entry, and on a workstation rather than a runner.
- Salesforce's AppExchange instructions name one command,
  `sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security --output-file CodeAnalyzerReport.html`,
  run from the package's top-level directory on the source that matches the
  submitted version. Before this date that report had never been generated
  for this package; the repository's reproducible scan uses the three-flag
  selector in [`code-analyzer.yml`](../code-analyzer.yml), which is a superset
  but not the file the reviewers ask for
  ([`SECURITY-REVIEW-SUBMISSION.md`](SECURITY-REVIEW-SUBMISSION.md)). Run 3
  is that report.

### Environment

| Item                 | Value                                                                                                               |
| -------------------- | ------------------------------------------------------------------------------------------------------------------- |
| Code Analyzer plugin | `5.16.0`                                                                                                            |
| Salesforce CLI       | `@salesforce/cli/2.153.5` win32-x64, node 24.20.0, npm 11.19.0                                                      |
| JDK                  | OpenJDK 21.0.12.1 (Microsoft build, LTS)                                                                            |
| Python               | None during Runs 1 and 2; `3.12.10` installed before Run 3                                                          |
| Host                 | Windows 11 workstation, 7.72 GB total memory                                                                        |
| Workspace scanned    | Runs 1-2: `force-app` of the working tree at `f27a009`; Run 3: top-level directory of a clean worktree at `934f200` |

The same checkout passed the project's own gates on this toolchain the same
day: `npm run lint`, `npm run prettier:verify` and `npm run test:unit:coverage`
(Jest 7/7; `auditExplorer.js` 70.64% statements, `csv.js` 100%).

Python matters for the first time in this record. Code Analyzer 5.16.0 ships a
`flow` engine that needs Python 3.10 or newer to instantiate at all. The
2026-09-19 entry ran on a CI runner that has Python; the 2026-09-10 entry, on
plugin 5.15.0, recorded nothing about it. What the missing interpreter did to
Runs 1 and 2 here, and why CI never showed it, is in the operational note at
the end of this entry.

### Rule selection

The repository selector resolved to **310 rules across 6 engines**, the count
pinned in [`code-analyzer.yml`](../code-analyzer.yml), both before and after
Python was installed:

```
sf code-analyzer rules --config-file code-analyzer.yml --workspace force-app \
  --rule-selector Recommended --rule-selector Security --rule-selector AppExchange
```

| Engine      | Rules   |
| ----------- | ------- |
| `eslint`    | 202     |
| `pmd`       | 94      |
| `regex`     | 6       |
| `retire-js` | 4       |
| `cpd`       | 2       |
| `sfge`      | 2       |
| **Total**   | **310** |

Identical to 2026-09-10 and 2026-09-19 engine for engine. The official
AppExchange selector, measured in Run 3 from the clean `934f200` worktree with
no `--config-file` and no `--workspace`, resolved to **62 rules across 5
engines**:

```
sf code-analyzer rules --rule-selector AppExchange --rule-selector Recommended:Security
```

| Engine      | Rules  |
| ----------- | ------ |
| `pmd`       | 51     |
| `retire-js` | 4      |
| `eslint`    | 3      |
| `flow`      | 3      |
| `regex`     | 1      |
| **Total**   | **62** |

No `sfge` and no `cpd`. The two Graph Engine rules carry the tags
`DevPreview, Security, Apex` and not `Recommended`, so the colon-separated
`Recommended:Security` intersection drops them. That is exactly why this
repository keeps the three-flag selector and the `--rule-selector sfge` run as
supporting evidence next to the official report: the official selector never
reaches `ApexFlsViolation` or `DatabaseOperationsMustUseWithSharing`.

### Run 1 — all six engines (repository selector)

Run from the repository working tree, 18:41-18:51 local, with Python absent:

```
sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
  --rule-selector Recommended --rule-selector Security --rule-selector AppExchange \
  --output-file CodeAnalyzerReport.html --output-file ca-report.json \
  --severity-threshold 2
```

**85 code violations across 16 files.** Zero Critical, zero High from any
rule that ran against a file.

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

Identical to the 2026-09-19 table rule for rule and count for count, which is
what an unchanged `force-app` should produce. `retire-js`, the `regex` secrets
engine and `cpd` again reported **0 violations**.

> **The command nevertheless exited 1, and `ca-report.json` holds 86 entries,
> not 85. The 86th is an engine-instantiation error, not a code finding.** It
> is reported as a Critical violation named `UninstantiableEngineError` from
> the `flow` engine, with no tags and no file (`Undefined Code Location`), and
> this message:
>
> ```
> The engine with name 'flow' could not be instantiated. Error: Could not
> locate a Python v3.10.0+ install using any of the following:
> ["python3","python"].
> ```
>
> Python was not installed on this host at that moment. No rule ran against
> any file to produce the entry; it describes the machine, not `force-app`.
> Because it is scored Critical, `--severity-threshold 2` ended the run with
> exit code 1:
>
> ```
> Found 86 violation(s) across 16 file(s):
>     1 Critical severity violation(s) found.
>     11 Moderate severity violation(s) found.
>     74 Low severity violation(s) found.
> Error (ThresholdExceeded): 1 violations met or exceeded the severity threshold of "High".
> ```
>
> The 85 entries that name a file are the table above; the 86th is excluded
> from every count in this entry and is explained in the operational note.

Unlike 2026-09-10, the Graph Engine completed **inside** this concurrent run:

```
sfge: Overall, analyzed 14503 path(s) from 3 entry point(s). Detected 0 violation(s).
```

with the configured 2 GB heap and 4 threads, while free host memory measured
during the run was about 0.7-0.8 GB. That it finished this time does not
change the procedure; Run 2 is the authoritative Graph Engine record, as in
both previous entries.

### Run 2 — Graph Engine alone (authoritative for `sfge`)

18:51-19:01 local, same configuration, Python still absent:

```
sf code-analyzer run --config-file code-analyzer.yml --workspace force-app \
  --rule-selector sfge --output-file ca-sfge.json
```

```
sfge: Detected 0 violation(s) from 14503 path(s) on 3/3 entry point(s).
```

This meets the validity bar — **14,503 paths, 3/3 entry points, no
`Internal execution error`** — so both Graph Engine rules executed to
completion on the shipped source:

- `sfge:ApexFlsViolation` — **0 violations**
- `sfge:DatabaseOperationsMustUseWithSharing` — **0 violations**

The only violation the command printed was the same `flow`
`UninstantiableEngineError` (Critical, no file), so its summary read
`Found 1 violation(s) across 0 file(s)`; with no severity threshold on this
command it exited 0. The engine error is independent of the selector: it
appears whenever the plugin starts without Python, whichever rules are asked
for.

### Run 3 — official AppExchange command, clean worktree at `934f200`

Python 3.12.10 was installed between Run 2 and this run. A clean git worktree
was checked out at `934f200` (tag `v1.0.0`), with no `node_modules`, and both
commands were run from its top-level directory exactly as Salesforce's
AppExchange page gives them — no `--config-file`, no `--workspace`. The rule
selection is the 62-rule table above. The scan, at 19:53 local:

```
sf code-analyzer run --rule-selector AppExchange --rule-selector Recommended:Security \
  --output-file CodeAnalyzerReport.html
```

```
Executing rules... done. Executed rules from regex, retire-js, pmd, eslint.
Found 0 violations.
```

Exit code 0. With Python present the `flow` engine instantiated and was listed
as eligible, but the package contains no Flow metadata, so it had no file to
scan and does not appear in the executed list; `sfge` and `cpd` hold no rule
under this selector. Without `--config-file` the ESLint engine reported that
`eslint.config.js` "was automatically discovered in your workspace but was NOT
applied", so its three rules here are the engine's own AppExchange and Security
rules, not this project's lint set; that is what the official command does by
design, and the project's lint rules are covered by Run 1 and `npm run lint`.

The resulting `CodeAnalyzerReport.html` is the file the submission asks for. It
is kept by the maintainer outside the repository (`CodeAnalyzerReport.html` is
gitignored, `.gitignore:55`); it is 65,085 bytes and its SHA-256 is

```
5C05B155418A8A1BE3FA2FF77132260F3B62E628380B25AFA4DC293D93C9169E
```

computed with `Get-FileHash -Algorithm SHA256`, so any copy presented later can
be checked against this entry.

### Combined result

Code findings from Run 1, with the Graph Engine result taken from Run 2:

| Severity  | Count  |
| --------- | ------ |
| Critical  | **0**  |
| High      | **0**  |
| Moderate  | 11     |
| Low       | 74     |
| **Total** | **85** |

Unchanged from 2026-09-10 and 2026-09-19, so the dispositions in
[`SECURITY-REVIEW-FINDINGS-DISPOSITION.md`](SECURITY-REVIEW-FINDINGS-DISPOSITION.md)
still describe this scan. No violation of any severity carries the `Security`,
`AppExchange` or `ErrorProne` tag. The official 62-rule selector (Run 3) found
**0 violations** on the same source.

A clean report from the official command is one of the files a submission
requires; it is static-analysis evidence and nothing more. The package has not
been submitted for, has not passed, and is not listed after AppExchange
Security Review, and this entry does not change that.

### Operational note — Python and the `flow` engine

The `flow` engine in Code Analyzer 5.16.0 requires Python 3.10 or newer. When
none is found the engine fails at instantiation, and the plugin reports that
failure as a Critical `UninstantiableEngineError` with no file — which a
`--severity-threshold 2` run then treats as a High-or-worse finding and exits
1, for a reason that has nothing to do with the code. Before treating any
Critical entry as a finding, read its `engine` and `locations`; an entry whose
engine is `flow` and whose location is `Undefined Code Location` is this
error.

CI never surfaced it because GitHub's `ubuntu-latest` runner has `python3`
preinstalled, so `.github/workflows/code-analyzer.yml` has needed no Python
step; this workstation had no Python until it was installed between Run 2 and
Run 3. With `--workspace force-app` the flow engine is in any case not eligible
(there is no Flow metadata to scan), which is why the repository selector
counts 310 rules from 6 engines identically on CI, on this host without
Python, and on this host after Python was installed. The error message itself
offers `engines.flow.disable_engine: true` as a configuration alternative;
`code-analyzer.yml` does not set it, and installing Python 3.10+ was the route
taken here because the official command needs the engine available.

The memory guidance from the 2026-09-10 note still stands. The Graph Engine
happened to finish inside the six-engine run this time, but on a 7.72 GB host
the result to record is the one from running it alone.
