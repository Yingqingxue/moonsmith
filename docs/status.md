# Implementation status

Last updated: 2026-10-19

## Equal-wall-clock online-feedback prototype

A new three-arm runner (`scripts/run_live_feedback_wallclock_campaign.ps1`)
interleaves sequential, semantic-guided, and MoonGrammata one-case workers,
rotates which arm starts each round, and gives each arm the same active
wall-clock allowance. Child startup, proposal generation/preflight, feedback,
verification, and serialization count against that allowance. It preserves
per-case JSON and hashes, checkpoints atomically, censors/kills an attempt at
the limit without retry, and can recover a prior checkpoint. The semantic
arm's accumulated selected-path state is passed across isolated workers.
After the first depth-10 run, report review caught a bookkeeping defect: the old
`censored` flag also labeled fully observed nonzero-exit selection windows as
censored. The runner now records no-valid-preflight windows separately and
sets censoring only for an attempt terminated at its wall-clock budget. A mock
regression verifies the distinction. A second, disjoint five-minute-per-arm
depth-10 replicate completed 20 sequential, 19 semantic-guided, and 23
executable MoonGrammata cases; 8 additional MoonGrammata callbacks were stopped
by the source-size guard. All 186 backend checks succeeded, with no mismatch or
crash. Its path sets were 56/56/55. Unlike the first depth-10 run, it had no
empty semantic proposal windows. This confirms only that those observed
selection failures did not recur in this small replicate; it does not estimate
the underlying candidate rate. Hashes and caveats are in the protocol evidence.

Mock tests cover the budget/interleave/timeout/recovery, stale-harness resume
rejection, and aggregate metric contract, and are added to CI. A corrected local
smoke run (30 seconds per arm; JS/Wasm/Wasm-GC; depth 1) completed three cases
on each arm and censored its fourth attempt. All nine completed cases were
consistent across all three backends.
It is a small wiring/measurement smoke, not evidence of effectiveness or of a
bug-finding advantage. The result and protocol caveats are recorded in
[`moongrammata_wallclock_comparison_protocol_20261019.md`](evidence/moongrammata_wallclock_comparison_protocol_20261019.md).
The prototype and protocol were committed and fast-forward pushed in
`ed1ca68268cc35cb3e9ba4a5aa6d7c27af2c62d1`. Local mock integration tests,
the existing campaign tests, `test_cli.ps1`, and MoonBit `moon test` (111/111)
passed. Hosted Linux verification and CaseKit interoperability passed in
[CI run 39186347066](https://github.com/Yingqingxue/moonsmith/actions/runs/39186347066);
the Windows native job also completed successfully. A 5-minute-per-arm depth-4
exploratory run completed 20 sequential, 20 semantic-guided, and 29 live
MoonGrammata cases; every completed case was consistent on JS/Wasm/Wasm-GC.
That sample found no mismatch or crash and did not distinguish reference-path
coverage (53 kinds in each arm); it is not an effectiveness claim. Details and
the report hash are recorded in the
[wall-clock protocol evidence](evidence/moongrammata_wallclock_comparison_protocol_20261019.md).
A 10-minute-per-arm depth-6 follow-up completed 40, 41, and 58 consistent cases
for sequential, semantic-guided, and MoonGrammata, respectively; all 417
backend executions succeeded. Coverage ended at 56/55/55 reference-path kinds,
and an early MoonGrammata lead disappeared during the run. This remains
exploratory evidence, not proof of comparative effectiveness. A depth-8,
10-minute-per-arm run completed 40 sequential, 40 semantic-guided, and 57
MoonGrammata cases; all 411 backend executions succeeded. Reference-path unions
were 55/56/55, a one-kind semantic-guided lead in this sample only. It is not
evidence of stable effectiveness. The depth-10, 10-minute-per-arm run completed
40 sequential, 39 semantic-guided, and 47 executable MoonGrammata cases. All
378 backend checks succeeded; semantic-guided had three proposal windows with
no preflight-valid candidate, and MoonGrammata had 12 generator-limit outcomes
before any backend check. Each arm reached the matched time budget and the
path-kind sets all contained the same 56 kinds. These remain exploratory
measurements, not evidence of effectiveness. Details, hashes, and caveats are
in the same
[protocol evidence](evidence/moongrammata_wallclock_comparison_protocol_20261019.md).

An offline integrity auditor now verifies a campaign's saved selection config,
raw-report hashes/index, per-arm counts, and realized equal-budget flag. The
corrected depth-10 replicate (70 raw reports) and final smoke report (9) pass;
the earlier long report is rejected for its already-documented false censor
flags rather than silently rewritten. The regression test checks that both a
tampered aggregate and a modified raw report are rejected. This audit verifies
artifact/summary integrity only; it does not replay compilers or establish
effectiveness.

A clean depth-10 replication then ran for 15 minutes per arm after all local
regression checks had finished. The saved 219-report artifact passed the
offline audit. Sequential, semantic-guided, and MoonGrammata observed 56 path
kinds each; all 591 backend checks succeeded with matching reference outputs.
There were 22 MoonGrammata callbacks stopped by the 16,300-line source guard
before backend execution, not compiler failures. The controls performed 244
and 248 proposal work items while MoonGrammata performed 96 live callbacks, so
equal wall-clock does not mean equal candidate work. This remains descriptive,
not evidence of effectiveness or throughput superiority. See the protocol
evidence for report/config/harness hashes and cost counters. A separate
10-minute-per-arm attempt overlapped local audit/regression commands and is
explicitly excluded from comparisons.

A subsequent attempt was interrupted during atomic checkpoint replacement and
resumed; although its 227 raw reports pass integrity audit, the report correctly
marks it as resumed and denies a realized-budget match, so it is excluded. A
fresh-seed clean repeat then completed with 900 seconds per arm and passed audit
over 229 raw reports. Again all three arms saw the same 56 reference-path kinds;
all 582 backend checks succeeded. MoonGrammata had 35 source-size-limit
callbacks before backend evaluation, while 68 callbacks completed all three
backend checks. No mismatch or crash was observed. The two clean 15-minute
replicates are descriptive only; the control proposal work and live callback
units still differ, and equal-time path counts do not prove effectiveness.
Hashes, cost counters, and the checkpoint caveat are in the protocol evidence.

## Competition-review follow-up: integration boundaries and evidence

The live MoonGrammata adapter now has seven exploratory synchronous-feedback
cohorts, including 32 selected cases per arm in the seventh. That run observed
38/48/24 reference-path kinds for sequential/semantic-guided/MoonGrammata, with
96 backend attempts per arm. The controls preflighted 128 proposals each,
versus 32 MoonGrammata callbacks, so candidate-work and total-compute budgets
remain unequal. This measures a path-diversity proxy, not bug-finding
effectiveness. The raw artifacts and caveats are in the
[seventh replication report](evidence/moongrammata_live_feedback_replication7_20261019.md).

The current response to the four overlap/validation concerns is intentionally
evidence-led and not a claim that all concerns are closed:

The baseline for this evidence update is commit `b177635`, whose regular
Linux/Windows and CaseKit CI passed in [run 39148454828](https://github.com/Yingqingxue/moonsmith/actions/runs/39148454828).
The seventh online-feedback cohort is recorded below and in its raw evidence
files; local MoonBit tests pass 111/111. The untracked application draft is
preserved and excluded from the project changes.

- A pinned CaseKit CI bridge serializes captured JS/Wasm stdout into CaseKit v1
  transcripts and calls CaseKit's comparator. Local integration-script tests
  with a protocol-compatible test double cover normal agreement, a backend-only
  injected mismatch, and a common-mode wrong value that MoonSmith's reference
  evaluator catches. The actual pinned CaseKit CLI build and all three hosted
  comparisons passed in [CI run 39015643110](https://github.com/Yingqingxue/moonsmith/actions/runs/39015643110).
  The [artifact-level evidence](evidence/casekit_interop_20261017.md) records
  each result. The bridge does not invoke CaseKit's observation-package runner.
- The public MoonGrammata README explicitly excludes native process isolation
  and crash-signal capture. MoonSmith's #2228 regression exercises that narrow
  process-level boundary, but overlap in generation, differential testing, and
  reduction remains; no comparative effectiveness advantage is established.
  The source revision and exact #2228 result are recorded in the
  [process-boundary evidence](evidence/moongrammata_process_boundary_20261017.md).
- MoonReduce's #2228 run preserved the external failure and the pre-crash print
  but removed zero non-layout source lines (385 to 379 bytes, layout-only).
  A separate MoonSmith parameter search then changed only the recursion depth
  from 1,000,000 to 523,682, preserved native exit 139/empty stdout plus JS
  RangeError, and passed three final replays ([evidence](evidence/moonreduce_upstream_2228_numeric_parameter_20261017.md)).
  This proves a source-specific MoonSmith parameter reduction on the actual
  upstream case, not semantic reduction by MoonReduce: its pinned first-version
  README excludes numeric simplification and AST reduction. The initial
  diagnostic run exposed and fixed an incorrect `0` expectation for the
  native-success/JS-RangeError partial case.
- Thirteen disjoint [230-seed cross-platform scans](evidence/current_generator_scan_20261017.md)
  (seeds 16450–16679 through 19210–19439) found no unexpected compiler
  outcomes. In total these cohorts compared 8,970 Linux and 2,990 Windows
  native-release executions on the same MoonBit toolchain. The newest cohort's
  full workflow passed in [run 39057929527](https://github.com/Yingqingxue/moonsmith/actions/runs/39057929527).
  A separate five-seed [depth-10 cross-platform cohort](evidence/current_generator_scan_20261017.md)
  also passed in [run 39059031700](https://github.com/Yingqingxue/moonsmith/actions/runs/39059031700):
  15 Linux backend executions and five Windows native executions were consistent.
  It broadens complexity sampling but is too small to support a completeness claim.
  A second depth-10 cohort (seeds 19450–19454) passed in run 39063712489:
  two in-bound seeds matched across six Linux and two Windows executions; three
  oversized sources were symmetrically classified as generator-limit exclusions
  and were not compiled. There were zero unexpected findings. The preceding
  run 39060757697 exposed old accounting that treated those exclusions as CI
  failures; this was a reporting-policy defect, not a compiler mismatch, and the
  rerun validates its correction. See the linked scan evidence for details.
  The adjacent cohort (seeds 19455–19459) also passed in
  [run 39065818510](https://github.com/Yingqingxue/moonsmith/actions/runs/39065818510):
  one seed completed four matching backend executions while four were
  size-guard exclusions. Across seeds 19445–19459, eight of 15 programs were
  executed on both platforms and seven were not compiled due to the 16,300-line
  bound; no unexpected outcomes were found. This remains exploratory coverage
  only.
  The next adjacent cohort (19460–19464) passed in
  [run 39070044826](https://github.com/Yingqingxue/moonsmith/actions/runs/39070044826):
  two in-bound samples matched across eight executions and three were excluded
  by the same size guard. Across the four focused depth-10 cohorts, ten of 20
  generated bodies were executed on both platforms; the other ten were not
  compiled. No new compiler issue was found in this finite sample.
  #1322 and #2228 remain upstream reports, not MoonSmith discoveries. These
  finite clean scans do not establish that no new compiler bug exists.

## Saved-source integrity during replay

The CLI replay command now checks a saved `source.mbt` against the
`sourceSha256` in `report.json` before running any backends. A mismatch is
rejected before execution so edits to an artifact cannot be mistaken for a
replay of the original finding. Reports predating source hashes remain
replayable and explicitly report that the integrity check was unavailable.
`scripts/test_cli.ps1` covers intact replay, tampered-source rejection, and
hashless legacy replay. This verifies artifact identity; it does not establish
that the original finding was a compiler defect.

## Bounded generated GCC FMA probe

The typed expression IR now includes a fixed finite-input `FmaContractionProbe`
and `generate_fma_probe_program`, exposed by the generator CLI's `--fma-probe`
mode. The reference evaluator runs the two `Double` operations on the JS target,
where they are separately rounded; the AST reducer treats the probe as a
minimal leaf. Local checks pass: 103/103 MoonBit tests, and the emitted source
returns `true` on JS, Wasm, and Wasm-GC. The GCC experiment script now compiles
that generated source under fast-contraction and contraction-disabled package
flags, instead of compiling only the hand-written fixture. On
[GitHub Actions run #38536474069](https://github.com/Yingqingxue/moonsmith/actions/runs/38536474069),
Ubuntu 24.04 with GCC 13.3.0 and MoonBit `moonc v0.10.15+943464bfa` produced
`true` on JS/Wasm/Wasm-GC and the native no-contraction control, and `false`
for native fast contraction. An initial generated-source attempt returned
`true` in both native configurations because its operands were literals; the
probe now parses runtime arguments to preserve the multiply/add for compiler
optimization. The same workflow's Linux verification and Windows native jobs
also passed. This remains a single known-issue probe with fixed test values,
not general `Double` expression generation or random FMA fuzzing.

## Semantic-path-guided seed selection experiment

`scripts/compare_semantic_selection.ps1` now compares a deterministic,
reference-path-guided selection against sequential seeds drawn from the same
candidate range. It records the candidate prescreen wall time separately from
the two backend arms, verifies that both arms actually launch the configured
number of backend executions, and labels the reference trace correctly as an
interpreter observation rather than backend instrumentation. Synthetic ranking
tests and a four-candidate/two-execution JS integration smoke run are included
in CI. This is a selection-policy experiment, not evidence yet that it finds
more compiler defects; path diversity and elapsed-time tradeoffs must be
measured over multiple cohorts. Three initial depth-4 cohorts of 40 candidates
and ten programs per arm showed higher reference-path variety under guidance
at the same 30 runtime launches per arm, but with 18–19 seconds of extra
prescreening and possible source-size confounding. See the
[bounded A/B evidence](evidence/semantic_selection_20261014.md); no compiler
defect was discovered in these runs.

The preregistered follow-up (100 candidates, 20 programs per arm, matched
source-size quartile counts) completed on commit `c0b5497`. Both arms launched
60 backend executions; the sequential arm covered 52 reference path kinds and
the guided arm 53, with mean source lengths of 120.6 and 124.6 lines. Candidate
prescreening added 88.8 seconds, so the extra path variety is not yet a strong
practical tradeoff. See the
[size-matched result](evidence/semantic_selection_size_match_20261014.md).

October 16 update: the hosted 24220–24319 run was repeated on a clean runner;
it reproduced the same selected seeds and 51-versus-55 path counts, but used a
different harness digest and is not an independent cohort. A new preregistered,
non-overlapping range 24320–24419 then produced 53 path kinds in both arms at
the same 60-execution and source-size-quartile budgets, with no unexpected
findings. The repeat supports stability for one fixed range; the new cohort
does not reproduce a guided-selection gain. Keep this policy experimental and
optional: both same-version independent cohorts ran sequential first, so a
warm-cache/order effect remains possible. See the [rerun report](evidence/semantic_selection_hosted_replication_20261016.md)
and [new cohort report](evidence/semantic_selection_hosted_replication2_20261016.md).
The push run [38875953569](https://github.com/Yingqingxue/moonsmith/actions/runs/38875953569)
and new-cohort run [38876082331](https://github.com/Yingqingxue/moonsmith/actions/runs/38876082331)
both passed their Linux and Windows-native jobs.

## Bounded array alias updates

The typed generator can now create a two-element `Int` or `Bool` array,
write a generated replacement through a second binding to that array, and
read the result through the original binding. Generated source asserts both
the updated value and the untouched other element, making an aliasing error
observable even if the final result alone would not expose it. The reference
evaluator records which index was updated and when a generated replacement
would otherwise be a no-op. In that case, both source and reference evaluator
substitute a different value, closing a false-negative path for ignored alias
writes. The reducer can simplify all
three child expressions while preserving the update scaffold. Batch JSON
reports source cases and reference paths separately. Local JS/Wasm/Wasm-GC
tests and a 20-seed differential sample passed. A fixed 1,000-seed nightly
and separate Windows native-release cohorts now also pass; the updated
index-selection gate enforces both a 2% floor and a 1:2 balance bound. See
[the measured evidence](evidence/array_alias_update_20261014.md) for exact
before/after runs, including a passing same-seed Linux/Windows comparison and
the updated 1,000-seed nightly corpus.
This is not arbitrary aliasing,
variable-length mutation, or proof of backend correctness.

## Grown-array index balance

The fixed 1,000-seed corpus previously visited grown-array index 1 in only
4 cases, despite 367 sources containing array growth. A separate seed stream
now selects the grown index; the same corpus visits index 0 in 144 cases and
index 1 in 133. The nightly gate checks a 2%-of-corpus floor for each path
and reconciles aggregate counts with per-case reference traces. Linux nightly
and Linux/Windows CI passed on commit `165695d`. See the
[paired evidence](evidence/array_growth_balance_20261014.md). These are
reference-interpreter observations, not backend internal coverage.

## Bounded primitive-array growth

Alongside fixed two-element array literals, the generator now sometimes builds
an empty `Array[Int]` or `Array[Bool]`, pushes two generated values, and reads
index 0 or 1. The reference evaluator models insertion order and records
growth, pushes, and the selected index; the AST reducer can simplify either
element or replace the whole construct with a same-typed value. Batch reports
count this source construct separately as `casesWithArrayGrow`. This is a
bounded slice, not arbitrary array mutation or index fuzzing. A local
three-backend injected-mismatch check reduced one generated growth case from
complexity 12,114 to 1,002 while retaining the two pushes and indexed read;
the injected mismatch is not a MoonBit compiler defect.

## Bounded `while` validation

The new bounded `while` form is covered by a [1,000-seed fixed-corpus run](evidence/while_coverage_20261013.md), targeted three-backend differential checks, and a trigger-preserving reducer integration test. The nightly validator now requires nonzero generated `while` syntax and executed reference-iteration paths, with exact per-case reconciliation. These checks establish this bounded slice on the tested toolchain and backends, not arbitrary `while` semantics or compiler-wide correctness.

## Observable conjunction short-circuiting

Generated `&&` expressions now use the same captured-counter guard as `||`:
the RHS must be called once when the LHS is true and skipped when false. A
targeted source test checks the emitted guard, and a fixed 1,000-seed
reference-trace test asserts that both conjunction RHS paths occur. Seeds 1
and 5 exercise the RHS-executed and RHS-skipped paths respectively; both
matched reference output on JS, Wasm, and Wasm-GC. Seed 42 at depth 4 also
passed the three-backend comparison. The schema-10 nightly gate described
below now measures both operators; reference traces are not native or backend
internal branch coverage.

## Nightly conjunction coverage gate

Schema 10 requires at least 20% source coverage for both `&&` and `||`, both
reference paths for each operator, and exact aggregate/per-case reconciliation.
Legacy schemas 7–9 remain accepted by report rendering and cross-platform
comparison; the nightly validator requires schema 10. Local batch-report and
CLI integration tests pass. Cross-platform CI
[38384509956](https://github.com/Yingqingxue/moonsmith/actions/runs/38384509956)
and the fresh fixed-seed nightly
[38384529922](https://github.com/Yingqingxue/moonsmith/actions/runs/38384529922)
both passed on commit `805b87c`. The nightly checked 1,000 unique cases and
3,000 JS/Wasm/Wasm-GC executions with zero unexpected findings. It recorded
558 cases containing `&&` (170 RHS-executed, 178 RHS-skipped) and 357 containing
`||` (141 executed, 162 skipped); all totals matched per-case source and trace
records. The HTML artifact includes the AND metric and contains no `<script>`
or `<img>` tags. See the
[short-circuit coverage evidence](evidence/short_circuit_coverage_20261013.md).

## Offline HTML case reports

The `report` command now writes a self-contained `report.html` alongside the
existing Markdown report. It includes evidence classification, toolchain and
host metadata, backend results, reference output, source hash, original and
optionally minimized source, aggregate reduction metrics, and a replay command.
Saved source and process output are HTML-encoded; the page has no JavaScript or
external assets. The CLI integration passed locally and on Linux/Windows in
[CI run 38284749943](https://github.com/Yingqingxue/moonsmith/actions/runs/38284749943).
When reduction data is present, the report now includes a table of accepted
candidate indices, attempt numbers, and decreasing complexity. Rejected
attempts and per-step source text are not shown; this remains a static report,
not an interactive reduction-history viewer.

## Nightly fixed-seed corpus

The new scheduled workflow runs seeds 14990–15989 at depth 4 on Linux across
JS, Wasm, and Wasm-GC, then retains the JSON report for 30 days. Manual
validation run [38286339963](https://github.com/Yingqingxue/moonsmith/actions/runs/38286339963)
passed in 9m23s using MoonBit `0.1.20261012 (748b63c)`: 1,000/1,000 distinct
program bodies, 1,000 reference checks, and 3,000 backend executions, all
consistent; no compile/runtime failures, timeouts, mismatches, generator limits,
or harness errors were reported. This fixed nightly corpus covers JS/Wasm/Wasm-GC
only; it is not native coverage or a proof of language-wide correctness.
The batch CLI also renders this machine report as a standalone HTML summary with
separate generated-source and reference-trace coverage, finding counts,
signature clusters, and per-seed rows. Local rendering was checked against the
saved 1,000-case report, and synthetic tests cover hostile text encoding, legacy
reports without clusters, and protection against overwriting the JSON source.
The nightly workflow enforces nonzero source and reference-trace coverage for
the valtype raise probe, its array composition, and both raise outcomes; batch
integration tests verify the gate accepts a complete report and rejects a
missing composition path.

End-to-end manual run [38294697813](https://github.com/Yingqingxue/moonsmith/actions/runs/38294697813)
passed in 9m22s on MoonBit `0.1.20261012 (748b63c)`. It verified 1,000 unique
bodies, 1,000 reference checks, and 3,000 JS/Wasm/Wasm-GC executions with no
unexpected findings. Coverage included 402 cases with the raise probe, 234
with direct array composition, 198 reference traces visiting both probe kinds,
164 raise-success paths, and 142 raise-error paths. The uploaded artifact
`moonsmith-nightly-generator-corpus-38294697813` was downloaded and verified to
contain both the 1,000-case JSON and HTML files; the HTML includes both distinct
coverage tables and no executable script or image tags. This was a manual
end-to-end validation; the next scheduled cron run remains pending.

Current developer and project owner: `Yingqingxue`. Development is currently
single-person; no second team member is recorded.

## Current generator change

The second, deliberately narrow `#valtype` probe starts with the empty-array
plus `push` shape from upstream issue #1322, then appends a second reference-
carrying enum record and reads it by index to exercise array growth. The
checked-in fixture continues to preserve the exact upstream source separately;
the generated extension is not claimed to be the original reproducer. The
MoonBit reference evaluator models both inserted values and traces the two
pushes and indexed reads; AST shrinking keeps the probe scaffold while reducing
its input. The extension passed the Linux, Windows, and extended-seed jobs in
[GitHub Actions run 38246227150](https://github.com/Yingqingxue/moonsmith/actions/runs/38246227150).
The current-generator scan covered 360 distinct bodies and 820 executions
(690 across JS/Wasm/Wasm-GC and 130 Windows native-release); see the
[fixed-seed evidence](evidence/current_generator_scan_20261012.md).
Four paired scans on seeds 13000–13229, 13300–13529, 13530–13759, and
13760–13989 covered 920 distinct generated bodies. Linux reference checks and
JS/Wasm/Wasm-GC totaled 2,760 executions; Windows native-release added 920,
for 3,680 consistent backend executions with matching source hashes and
reference outputs, no size limits, and no unexpected findings. See the
evidence document for runs 38274803979, 38276715973, 38278202679, 38280242793,
and 38281878588. The last run's five jobs, including automatic report
comparison, passed; MSVC `cl.exe` FileVersion was `19.51.36260.0`. Run
38280242793's scan/comparison jobs succeeded but its overall workflow failed
due to the test helper's unset `$env:TEMP` assumption; this was fixed with
`Path.GetTempPath()` and verified in later green CI. Native-debug remains
excluded from these samples because of the upstream-reported #1322 ICE.
#1322 remains an upstream-reported issue, not a MoonSmith-discovered defect.
In the 2026-10-12 CI run, its native-debug signature reproduced on both
Linux/GCC and Windows/MSVC, while native-release and Wasm-GC passed; an earlier
MoonBit `0.1.20260920` run had not reproduced it on Windows. The apparent change
coincides with a MoonBit toolchain update, but causation is not established.
See the [regression notes](regressions.md#case-3-native-debug-array-push-of-a-valtype-record-containing-an-enum).
The same-runner [toolchain comparison](evidence/issue_1322_toolchain_comparison_20261012.md)
completed twice on October 12: Linux reproduced the signature with both MoonC
versions in both workflow runs, while Windows changed from non-reproduction to
reproduction in both runs; GCC and MSVC versions matched within each job. This
is repeatable association evidence across two hosted runners per OS, but does
not isolate `moonc` from `moon`/core or establish a root cause. The comparison
can be repeated from the [manual workflow](../.github/workflows/issue-1322-toolchain-comparison.yml).

The 3,750-program scan totals below were collected before this generator
branch changed. They remain historical evidence for that version of the
generator, not a measured distribution or defect-finding rate for the current
branch. The smaller current-generator sample is documented separately and
must not be added to those historical totals. This workstation has no
compatible C compiler, so native behavior is checked on hosted CI.

## Latest completed local verification (2026-10-12, before array-growth extension)

On `main` at `c8d71f9`, `moon info`, `moon fmt`,
and `moon check --deny-warn` completed successfully. The main package passed 77/77
tests on each of JS, Wasm, and Wasm-GC. The reference, reducer, CLI, and #1322
integration scripts passed. Generated seed 4 at depth 3 contains the empty
array + `push` trigger, is reference-checked, and agrees on JS/Wasm/Wasm-GC;
reducer tests retain the `push` scaffold. The `git diff --check` validation
was clean. This workstation has no compatible C compiler, so generated native
debug behavior was not validated locally; the dedicated CI regression checks
it against the known upstream signature, while the ordinary Linux native
release batch avoids treating that known debug failure as an unexpected
finding.

The local-verification section above is a historical snapshot from before the
array-growth extension and should not be read as the current validation state.
The extension has since passed the remote checks and current-generator scan
linked above; this machine still lacks a compatible C compiler.

## Targeted test additions (2026-10-13)

Added whitebox coverage for `ChoiceType` value typing and typed local-function
printing, plus relative single-filename path normalization in diagnostics. A
follow-up review found and fixed a real generator gap: `ChoiceType` expressions
were rejected even though the IR, evaluator, and reducer support them. The
generator now composes Choice values through typed local functions, and the
printer uses the argument's type for the function parameter instead of assuming
the return type matches it. The reducer now only offers the function argument
as a replacement when its type matches the function result. The main package
passes 81 tests locally on JS, Wasm, and Wasm-GC. Reference, reducer, CLI, and
batch-report integration scripts also pass. Seed 4, whose generated source
contains the new Choice-returning function, was consistent across JS, Wasm,
and Wasm-GC. A source-triggered injected mismatch on that seed reduced from
complexity 24,167 to 7,007 in 20 attempts (7 accepted steps), retaining the
trigger; this validates reducer behavior and is not a compiler finding. The
updated generator also passed a fresh 1,000-seed Linux corpus; compared against
the immediately preceding same-toolchain corpus, 251 source hashes changed
and 305 local-function nodes were added. Details and artifact checks are in
[the updated corpus evidence](evidence/choice_function_corpus_20261013.md).
Earlier large scans remain historical and do not measure this extension. The
new corpus is Linux-only, and reference traces are not runtime coverage inside
generated compiler backends. Native remains a hosted-CI check because this
workstation has no compatible C compiler.
Batch-report schema 8 now records Choice-returning-function cases and total
functions explicitly; the nightly validator requires schema 8 and gates on
both counts. Unit tests
cover rejection of missing coverage and mismatch between aggregate and per-case
counts. The refreshed remote 1,000-seed run passed:
251 cases contained 305 Choice-returning functions, with no unexpected
findings, generator limits, or harness errors. Report rendering and
cross-platform comparison retain schema-7 read compatibility for existing
saved reports. See [the schema-8 run evidence](evidence/choice_function_corpus_20261013.md).
After adding per-case/aggregate reconciliation, the validator and full nightly
corpus passed again on the latest code in run
[38347193204](https://github.com/Yingqingxue/moonsmith/actions/runs/38347193204).

## Short-circuit disjunction extension (2026-10-13)

The typed expression IR and generator now include boolean `||` alongside
`&&`. The reference evaluator traces whether the right-hand side executes or
is skipped, and the AST reducer can simplify either operand while preserving
the boolean result type. Tests cover both short-circuit paths and reduction
invariants. Generated seed 353 at depth 4 executes disjunction in its
reference trace and agrees across JS, Wasm, and Wasm-GC. An injected
wasm-gc-only output mismatch on that seed was reduced in the integration test:
2 accepted shrink steps in a 10-attempt budget lowered the complexity from
25,131 to 23,119 while retaining `||`. The attempt budget was reached, so this
proves the path works but not that the reducer converged to a minimum. This is
a narrow language-coverage improvement, not evidence of a MoonBit compiler
defect or broad backend branch coverage.

Batch-report schema 9 adds a per-case `or` source count and aggregate
`casesWithOr`; the nightly gate requires at least 20% of the corpus to contain
`||` and reconciles this count against each case. Renderers and cross-platform
comparison preserve schema-7/8 compatibility. Local integration fixtures cover
both legacy formats, low-coverage rejection, and aggregate/per-case mismatches.
The refreshed schema-9
nightly passed in
[run 38352609842](https://github.com/Yingqingxue/moonsmith/actions/runs/38352609842)
on `c27ca2f`. It checked 1,000 unique bodies, 1,000 reference results, and
3,000 JS/Wasm/Wasm-GC executions with no unexpected findings. The report
recorded 15 cases containing `||`, reconciled to the per-case total, and
reference traces exercised both right-hand-side execution (5 cases) and
short-circuit skipping (3 cases). The artifact JSON was downloaded and checked;
the standalone HTML includes the new metric. Ordinary CI, including Windows
native integration, passed in
[run 38352593110](https://github.com/Yingqingxue/moonsmith/actions/runs/38352593110).
This is fixed-corpus evidence, not backend branch instrumentation or a claim
that MoonSmith discovered an upstream compiler defect. See the detailed
[disjunction corpus evidence](evidence/disjunction_corpus_20261013.md).

The first nightly's 15/1,000 disjunction-bearing sources exposed that a
nonzero-only coverage gate was permissive. Commit `2a96c43` changed only the
existing `And`/`Or` selection probability (1:2, favoring `Or`), without
changing expression branch selection. The same seed window then produced 357
sources with `||` and 470 `Or` nodes; reference traces exercised both RHS
execution and short-circuit skipping. All 1,000 reference checks and 3,000
backend executions remained consistent, while the existing valtype probe,
composition, and combined-trace counts remained 402, 234, and 204. Commit
`f7de731` adds a 20%-of-corpus floor to the fixed-window generator test and
nightly validator. The stricter nightly passed with all 357 observed cases
above its 200-case minimum in
[run 38355758690](https://github.com/Yingqingxue/moonsmith/actions/runs/38355758690);
Linux and Windows CI passed in
[run 38355748814](https://github.com/Yingqingxue/moonsmith/actions/runs/38355748814).
See the paired evidence for exact counts and limits.

An additional non-overlapping depth/platform sample passed in
[run 38356796437](https://github.com/Yingqingxue/moonsmith/actions/runs/38356796437):
230 unique seeds at depths 4, 6, and 8 matched across Linux JS/Wasm/Wasm-GC and
Windows native-release (920 consistent executions, matching source hashes and
reference outputs). `||` appeared in 38/100 depth-4, 79/100 depth-6, and 30/30
depth-8 sources. Commit `f013ec3` made the nightly gate require both
short-circuit outcomes and reconcile their aggregate totals against each
case's reference-path kinds. Nightly run
[38358007538](https://github.com/Yingqingxue/moonsmith/actions/runs/38358007538)
passed with 141 RHS-executed and 162 RHS-skipped cases; the downloaded report
confirmed both totals match per-case records. Linux/Windows CI passed in
[38358006292](https://github.com/Yingqingxue/moonsmith/actions/runs/38358006292).

To make a short-circuit regression observable even when the final Bool result
is unchanged, the `Or` printer now evaluates its RHS through a closure that
increments a captured mutable counter. Generated code expects 0 calls when the
LHS is true and 1 when it is false, panicking if the compiler violates that
contract. Local seeds 14990, 14993, and 14995 passed on JS/Wasm/Wasm-GC, with
14993 exercising both RHS paths. Remote CI
[38362600738](https://github.com/Yingqingxue/moonsmith/actions/runs/38362600738)
passed Linux and Windows; nightly
[38362624266](https://github.com/Yingqingxue/moonsmith/actions/runs/38362624266)
passed 1,000 unique bodies and 3,000 executions with 357 OR-bearing sources,
470 OR nodes, 141 executed-RHS cases, and 162 skipped-RHS cases. The longest
source had 201 lines and no case hit the generator limit. A new depth/platform
comparison
[38362629021](https://github.com/Yingqingxue/moonsmith/actions/runs/38362629021)
also passed on Linux and Windows native-release. This adds an observable
short-circuit check; it does not establish that a MoonBit compiler defect was
found.

The composed `#valtype`/raise + enum-array probe and its end-to-end evidence
are documented below; those scans predate the push-pattern change and remain
historical, not measurements of the current generator revision. No newly
discovered compiler defect is claimed.

## Verified baseline (2026-10-10)

- MoonBit toolchain: `moon 0.1.20260920 (914d7da 2026-09-20)`.
- The library and tests compile without warnings.
- Seventy-four main-package tests pass on each of `js`, `wasm`, and `wasm-gc`;
  reference, reducer, and CLI integration scripts also pass.
- The current generator revision passed [CI run 38029911973](https://github.com/Yingqingxue/moonsmith/actions/runs/38029911973):
  Linux verification and 10-seed, five-configuration smoke; Windows native
  verification and 130-seed native smoke.
- A fresh 100-seed depth-4 scan after the enum-array probe change completed in
  575,172 ms: all 100 reference checks and 300 JS/Wasm/Wasm-GC executions were
  consistent, with 100 distinct program bodies and no harness changes. The
  enum-array probe appeared in 51 sources and was visited by the reference
  evaluator in 51 cases; the `#valtype`/`raise` probe appeared in 41 sources.
  Raw report: `.moonsmith/runs/batch_20261010_061907_455.json` (local, ignored).
- Signed-`Int` seed boundary checks now cover `-2147483648` and `2147483647`,
  including normalization, Park–Miller advancement, child seeds, deterministic
  generation, and result typing. Standard Park–Miller vectors are also pinned
  by white-box tests. After adding these cases, 70/70 package tests
  pass on each of `js`, `wasm`, and `wasm-gc`; the CLI integration also
  differentially checks the minimum, `-1`, and maximum seeds across JS, Wasm,
  Wasm-GC, and (on Windows CI) native. This workstation has no compatible C
  compiler.
- JS coverage analysis reports 17 uncovered defensive branches across the
  generator, oracle, reducer, and reference evaluator. Review shows these are
  invalid `ChoiceType`/scope states or an exhaustive-classification fallback,
  not untested normal `#valtype`/`raise` paths. Coverage was not inflated by
  exercising malformed ASTs.
- Regression package `issue_1071_coverage_ice` passes its instrumented JS test
  and package-scoped coverage analysis; `issue_1274_wasm_valtype_raise` passes
  its test on all three backends.
- The post-probe 100-seed depth-4 batch completed all 100 reference checks and
  300 backend executions with zero mismatches, compile/runtime failures,
  timeouts, or harness errors. It produced 100 distinct program bodies with an
  unchanged harness digest.
- A deeper 100-seed depth-5 batch completed in 543,728 ms with 100 distinct
  bodies, 100 reference checks, and 300 consistent backend executions; there
  were no failures or harness changes. The probe appeared in 67 sources;
  reference traces visited its path in 46 cases (success 20, error 31; cases
  may include both). Raw report: `.moonsmith/runs/batch_20261009_142423_321.json`
  (local, ignored). These path counts are interpreter traces, not backend
  runtime instrumentation.
- A separate depth-5 Wasm-only scan of seeds 1000–1299 completed 300 reference
  checks and executions in 947,698 ms: all were consistent, with 300 unique
  bodies and an unchanged harness digest. The probe appeared in 201 sources;
  interpreter traces visited it in 140 cases (success 85, error 75; overlap
  possible). Combined with the depth-4/5 full-matrix runs above, the three
  scans cover 500 distinct program bodies, 500 reference checks, and 900
  backend executions, all consistent. Raw report:
  `.moonsmith/runs/batch_20261009_143600_489.json` (local, ignored).
  A 30-seed depth-6 full-matrix batch (run `20261009_150151_741`) completed all
  30 reference checks and 90 executions in 162,745 ms, with no failures or
  harness changes; 26 sources contained the probe and reference traces visited
  it in 21 cases (success 17, error 11; overlap possible).
- A depth-6 Wasm-only scan of seeds 3000–3099 (run `20261009_150733_048`)
  completed 100 reference checks and executions in 310,515 ms, with 100 unique
  bodies and no failures or harness changes. The probe appeared in 89 sources;
  interpreter traces visited it in 69 cases (success 43, error 40; overlap
  possible).
- A depth-7 full-matrix scan of seeds 4000–4029 (run `20261009_152126_201`)
  completed 30 reference checks and 90 executions in 162,050 ms, with no
  failures or harness changes; all 30 sources contained the probe and traces
  visited it in 26 cases (success 19, error 19; overlap possible).
- A 100-seed depth-7 full-matrix scan of seeds 5000–5099 (run
  `20261009_152857_146`) completed 100 reference checks and 300 executions in
  543,907 ms, with no failures or harness changes. The probe appeared in 98
  sources; reference traces visited it in 89 cases (success 60, error 68;
  overlap possible). Across the seven selected runs the totals are 760
  distinct bodies, 760 reference checks, and 1,480 consistent backend
  executions.
- A 30-seed depth-8 full-matrix scan of seeds 6000–6029 (run
  `20261009_154042_081`) completed 30 reference checks and 90 executions in
  164,444 ms; all cases were consistent and the harness digest stayed fixed.
  The probe appeared in all 30 sources; reference traces visited it in 28
  cases (success 21, error 25; overlap possible). Across eight selected runs,
  body-hash comparison confirms 790 distinct bodies, 790 reference checks,
  and 1,570 consistent backend executions.
- A 100-seed depth-8 full-matrix scan of seeds 6100–6199 (run
  `20261009_154604_335`) completed 100 reference checks and 300 executions in
  555,440 ms; all cases were consistent and the harness digest stayed fixed.
  The probe appeared in all 100 sources; reference traces visited it in 95
  cases (success 86, error 78; overlap possible). Across nine selected runs,
  body-hash comparison confirms 890 distinct bodies, 890 reference checks,
  and 1,870 consistent backend executions.
- A 30-seed depth-9 full-matrix scan of seeds 7000–7029 (run
  `20261009_161038_538`) completed 30 reference checks and 90 executions in
  172,209 ms; all cases were consistent and the harness digest stayed fixed.
  All sources contained the probe; reference traces visited it in all 30
  cases (success 29, error 26; overlap possible). Across ten selected runs,
  body-hash comparison confirms 920 distinct bodies, 920 reference checks,
  and 1,960 consistent backend executions.
- A 100-seed depth-9 full-matrix scan of seeds 7100–7199 (run
  `20261009_161448_637`) completed 100 reference checks and 300 executions in
  586,626 ms; all cases were consistent and the harness digest stayed fixed.
  All sources contained the probe; reference traces visited it in 96 cases
  (success 94, error 88; overlap possible). Across eleven selected runs,
  body-hash comparison confirms 1,020 distinct bodies, 1,020 reference checks,
  and 2,260 consistent backend executions.
- A 30-seed depth-10 full-matrix scan of seeds 8000–8029 (run
  `20261009_162727_808`) completed 30 reference checks and 90 executions in
  208,573 ms; all cases were consistent and the harness digest stayed fixed.
  All sources contained the probe and reference traces visited it in all 30
  cases (success 30, error 30; overlap possible).
- A 100-seed depth-10 full-matrix scan of seeds 8100–8199 (run
  `20261009_165647_384`) produced 98 fully consistent programs and two explicit
  `generator-limit` results. Those two generated sources were 18,299 and 17,739
  lines, exceeding the runner's safe 16,300-line source-segment limit; neither
  was sent to the reference evaluator or a backend. The other 98 samples passed
  98 reference checks and 294 backend executions. Across thirteen selected
  runs, body hashes confirm 1,150 distinct bodies, 1,148 reference checks, and
  2,644 consistent backend executions; two size-limit cases remain explicit.
- A second 100-seed depth-10 scan of seeds 8200–8299 (run
  `20261009_171554_872`) completed 97 reference checks and 291 consistent
  backend executions; three generated sources exceeded the 16,300-line bound
  and were reported as `generator-limit` without compiling. Across fourteen
  selected runs, hashes confirm 1,250 distinct bodies, 1,245 reference checks,
  and 2,935 consistent backend executions, with five explicit size-limit cases.
  Reproduction commands and combined summary are tracked in
  [seed scan evidence](evidence/seed_scans_20261009.md).
- A depth-11 boundary scan of seeds 8300–8399 (run
  `20261009_212300_782`) produced 29 programs below the 16,300-line safety
  bound; all passed the reference evaluator and JS/Wasm/Wasm-GC (87 executions).
  The other 71 were stopped as `generator-limit` before compilation; the largest
  source was 44,034 lines. All 100 bodies were distinct, the harness digest was
  unchanged, and there were no compiler/runtime errors or differential
  mismatches. This makes depth 11 an unreliable range today; depth 10 also had
  five limits in 230 cases. See [the boundary scan record](evidence/seed_scans_20261009.md).
- A new 100-seed depth-10 scan of seeds 8400–8499 (run
  `20261009_212902_452`) completed 99 reference checks and 297 consistent
  JS/Wasm/Wasm-GC executions. Seed 8482 was stopped at 16,816 lines by the
  existing guard. All 100 bodies were unique against the prior fourteen depth-
  4–10 runs; the expanded evidence totals 1,350 unique bodies, 1,344 checked
  cases, and 3,232 backend executions, with six explicit size-limit rejections.
  No compiler/runtime failures, mismatches, or harness changes occurred. See
  [the seed scan evidence](evidence/seed_scans_20261009.md).
- Verifier report schema 5 now carries source line counts for successful
  generated inputs as well as `generator-limit` cases; external `SourcePath`
  reports also count lines but leave `sourceLineLimit` null because the generated
  source guard is not applied there. Batch schema 6 reports the number of
  measured cases and the maximum line count. CLI integration checks the per-case
  values against the near-limit fixture and verifies batch aggregation.
- A 500-seed depth-5 full-matrix scan (seeds 10000–10499, run
  `20261009_214412_087`) passed all 500 reference checks and 1,500 backend
  executions. A subsequent 100-seed depth-6 scan (seeds 11000–11099, run
  `20261009_224035_689`) passed 100 checks and 300 executions; all 100 batch
  records contained source-line measurements, with a maximum of 752. The probe
  appeared in 319/500 and 90/100 sources respectively; reference traces visited
  it in 220 and 68 cases. Across 17 depth-4–10 runs, cross-report body hashes
  confirm 1,950 distinct programs, 1,944 consistent checks, 5,032 backend
  executions, and six guarded size-limit cases. Neither scan changed the
  harness digest or found a compiler/runtime mismatch.
- A 100-seed depth-7 full-matrix scan (seeds 12000–12099, run
  `20261009_225236_634`) passed 100 reference checks and 300 backend
  executions. Schema-6 reports measured every source; the maximum was 1,685
  lines. The probe appeared in 97 sources and was visited in 79 reference
  traces. Across 18 depth-4–10 runs, cross-report hashes confirm 2,050 distinct
  program bodies, 2,044 consistent checks, 5,332 backend executions, and six
  guarded size limits. Digest remained unchanged and no mismatch occurred.
- A 100-seed depth-8 full-matrix scan (seeds 13000–13099, run
  `20261009_230253_164`) passed 100 checks and 300 executions. Every case had
  a measured line count (maximum 4,221); all sources contained the probe and 97
  reference traces visited it. Across 19 depth-4–10 runs, hashes confirm 2,150
  distinct programs, 2,144 consistent checks, 5,632 backend executions, and
  six guarded size limits, with an unchanged harness digest.
- A 100-seed depth-9 full-matrix scan (seeds 14000–14099, run
  `20261009_231924_625`) passed 100 reference checks and 300 executions.
  Every source had a line count (maximum 8,862); all sources contained the
  probe, and 97 reference traces visited it. Across 20 selected depth-4–10
  runs, hashes confirm 2,250 distinct programs, 2,244 consistent checks,
  5,932 backend executions, and six guarded size limits. The harness digest
  remained unchanged; no compiler/runtime mismatch was found.
- A 100-seed depth-10 full-matrix scan (seeds 15000–15099, run
  `20261009_233158_232`) passed 97 reference checks and 291 executions; three
  generated sources were stopped by the 16,300-line guard before compilation
  (maximum 21,308). All sources were measured and contained the probe; 97
  reference traces visited it. Across 21 selected depth-4–10 runs, cross-report
  hashes confirm 2,350 distinct programs, 2,341 consistent checks, 6,223
  backend executions, and nine guarded size limits. The digest was unchanged.
- A further 200 depth-10 seeds (16000–16199, run `20261009_234550_219`)
  produced 200 unique bodies and 200 line measurements (maximum 21,980); 197
  reference checks and 591 executions passed, with three safe size-limit
  rejections. All sources contained the probe; 196 reference traces visited
  it. Across 22 selected depth-4–10 runs, hashes confirm 2,550 distinct
  programs, 2,538 consistent checks, 6,814 backend executions, and twelve
  guarded size limits. The harness digest remained unchanged.
- A further 200 depth-9 seeds (17000–17199, run `20261010_001035_699`) all
  passed reference evaluation and 600 executions; every case had line
  telemetry (maximum 10,230), and all sources contained the probe. The
  reference trace visited it in all 200 cases. Across 23 selected depth-4–10
  runs, hashes confirm 2,750 distinct programs, 2,738 consistent checks,
  7,414 backend executions, and twelve guarded size limits. No harness change
  or mismatch occurred.
- A further 200 depth-8 seeds (18000–18199, run `20261010_003225_873`) all
  passed reference evaluation and 600 executions. Every source had line
  telemetry (maximum 3,553); 194 reference traces visited the probe. Across
  24 selected depth-4–10 runs, hashes confirm 2,950 distinct programs, 2,938
  consistent checks, 8,014 backend executions, and twelve guarded size limits.
  The harness digest remained unchanged.
- A further 200 depth-7 seeds (19000–19199, run `20261010_005354_875`) all
  passed reference evaluation and 600 executions. All sources had line
  telemetry (maximum 1,459); 198 contained the probe and 178 reference traces
  visited it. Across 25 selected depth-4–10 runs, hashes confirm 3,150 unique
  bodies, 3,138 consistent checks, 8,614 backend executions, and twelve
  guarded size limits. No harness change or mismatch occurred.
- A further 200 depth-6 seeds (20000–20199, run `20261010_011449_609`) all
  passed reference evaluation and 600 executions. Every source had telemetry
  (maximum 697); 177 contained the probe, with 133 reference traces visiting
  it. Across 26 selected depth-4–10 runs, hashes confirm 3,350 unique bodies,
  3,338 consistent checks, 9,214 backend executions, and twelve guarded size
  limits. The harness digest remained unchanged.
- A further 200 depth-5 seeds (21000–21199, run `20261010_013546_190`) all
  passed reference evaluation and 600 executions. Every source had telemetry
  (maximum 327); 122 contained the probe and 84 reference traces visited it.
  Across 27 selected depth-4–10 runs, hashes confirm 3,550 unique bodies,
  3,538 consistent checks, 9,814 backend executions, and twelve guarded size
  limits. The harness digest remained unchanged.
- A further 200 depth-4 seeds (22000–22199, run `20261010_015555_490`) all
  passed reference evaluation and 600 executions. Every source had telemetry
  (maximum 179); 86 contained the probe, and 58 reference traces visited it.
  Across 28 selected depth-4–10 runs, hashes confirm 3,750 unique bodies,
  3,738 consistent checks, 10,414 backend executions, and twelve guarded size
  limits. The digest remained unchanged.
- An explicitly labelled injected difference on `wasm-gc` is classified as
  `output-mismatch` and makes the verification command fail as intended.
- The generator CLI emits byte-identical source on `js`, `wasm`, and
  `wasm-gc` for the same seed and depth.
- Commit `dc2314f` passed remote GitHub Actions run `37943444203` (1m06s),
  including the probe-specific reduction replay. Its artifact contains both
  smoke-batch JSON and injected-reduction source/reports, is 9,840 bytes, and
  is available through 2026-11-08. The workflow uses the Node 24 artifact
  action runtime; only GitHub's future Ubuntu runner migration notice remains.
- Boundary tests now lock down `-1` as the error case and `0`/`1` as success,
  assert the generated program retains the `#valtype` + first-`Double` +
  raising function + `try?` trigger shape, and verify helper declarations are
  omitted from programs that do not use the probe. All backends pass 61/61;
  reference, reducer, and CLI integration scripts pass as well.
- A probe-scoped injected mismatch was replayed and reduced across all four
  targets in GitHub Actions run `37968510482` for commit `90e0395`: 5 accepted
  steps in 10 attempts, complexity 39,300 → 18,133, with the trigger scaffold
  retained. The uploaded `reduction.json` confirms the target matrix includes
  native. A separate 100-budget local three-backend run accepted 15 steps in
  84 attempts, reduced bytes 2,376 → 1,367 and complexity 39,300 → 11,014,
  then exhausted the current candidate set without hitting its budget. Final
  reduction key was revalidated; this is not a global-minimum guarantee or a
  real compiler bug.

## Native backend status and local environment limitation

The `native` target cannot be tested on this workstation because no compatible
system C compiler (`cl`, `clang-cl`, `gcc`, `clang`, or `cc`) is installed. The
latest completed GitHub Actions run `37978979627` for commit `01cbfa2` passed
both Linux
and Windows jobs. The Windows job configured MSVC, found `cl.exe`, passed
`moon test --target native` (70/70 package tests), ran a 100-seed depth-6 scan (seeds 9000–9099) and
a 30-seed depth-8 scan (seeds 9200–9229), and passed reference/reducer/CLI
integration. Retained artifacts report 130 distinct program bodies, 130
reference checks, 130 consistent native executions, zero unexpected findings,
and unchanged harness digests. The `#valtype`/`raise` probe appeared in 89
depth-6 sources; reference traces visited modeled success (43 cases) and error
(39 cases) paths. Every depth-8 source contained the probe; traces visited
success (29 cases) and error (24 cases). These counts are not native runtime
instrumentation. The same workflow's cold Windows
generator timeout was corrected by increasing its per-seed budget from 10 to
60 seconds; the previous allowance expired before seed 0 could be generated
on a clean runner. The Linux job continues to cover the four-target smoke
batch and probe-specific reducer. Earlier runs independently verified the
30-seed depth-6 native baseline; run `37967661714` verified
a 10-seed full-matrix batch (seeds 0–9, depth 4): ten distinct program bodies,
40 executions across JS/Wasm/Wasm-GC/native, ten consistent cases, no findings,
and an unchanged harness digest. The uploaded batch and reduction reports were
inspected directly. These CI batches are separate from the 1,250-case
JS/Wasm/Wasm-GC scan documented below; local native replay still requires an
appropriate C toolchain. Native randomized coverage is useful but still limited
to 130 seeds (100 depth 6, 30 depth 8). The pinned
MSVC setup action currently emits a Node 20 deprecation warning while
successfully running under Node 24 compatibility mode; monitor for an upstream
action update.

A separate fixture preserves upstream issue
[#1322](https://github.com/moonbitlang/moonbit-docs/issues/1322). The initial
2026-10-09 run on MoonBit `0.1.20260920` reproduced its native-debug
`lower_array_make` ICE on Linux/GCC but not Windows/MSVC. A later successful
[CI run 38246227150](https://github.com/Yingqingxue/moonsmith/actions/runs/38246227150)
on MoonBit `0.1.20261012` reproduced the same signature on both platforms, for
both the upstream fixture and the generated extension. Native release and
Wasm-GC returned the expected `0` and `x` in both runs. The results changed
alongside the MoonBit toolchain version, but the runner images and other
dependencies were not controlled in an A/B experiment; this is correlation,
not an established cause. This reproduces an upstream report, not a MoonSmith
discovery, and does not establish whether the behavior violates the language
contract. Local native replay is unavailable without a C compiler.
The fixture's latest harness version also passes the source and upstream-known
expected output through `verify_seed.ps1`, validating the existing Oracle's
per-target classification; because the expected value is supplied externally,
this path does not use the MoonSmith AST reference evaluator.
The generic verifier now also exposes `native-release` beside `native` (debug),
recording the underlying backend and build mode in each per-target result so
debug/release configuration comparisons can use identical source. MoonBit may
select different internal compiler backends for native debug and release, so
the report's `backend: native` denotes the command-line target rather than a
promise of identical internal lowering. This workstation has
no compatible C compiler, so local integration verifies unavailable-state
classification and report metadata, not execution of either native mode; CI
run [37988791461](https://github.com/Yingqingxue/moonsmith/actions/runs/37988791461)
passed both Linux and Windows jobs with the new target. Linux recorded
native-debug `compile-failed`, native-release `succeeded`, and Wasm-GC
`succeeded`; Windows recorded native-debug and native-release `succeeded`.
The release outputs matched the upstream-provided expected output on both.
Their evidence records GCC 13.3.0 on Linux and MSVC 19.51.36260 on Windows.
In that run, the Linux smoke batch also checked 10 distinct generated programs
across JS, Wasm, Wasm-GC, native debug, and native release (50 successful
backend executions). Windows checked 100 distinct depth-6 generated programs
in native debug and release (200 successful executions), plus 30 depth-8
native-debug cases; all were consistent and the harness digest stayed
unchanged.
CI run [37992067092](https://github.com/Yingqingxue/moonsmith/actions/runs/37992067092)
also passed the `#valtype` source-triggered reducer with the five-configuration
matrix on both Linux and Windows. The Windows artifact was downloaded and
verified to contain both reducer JSON records, original and minimized source,
and the native-release target in the probe-specific matrix.

## Current vertical slice

```text
seed + depth -> typed Expr -> MoonBit source -> selected target matrix
                                      -> JSON comparison report
```

The typed generator now includes a narrow `ValtypeRaiseProbe` node motivated
by public issue #1274. Its printer emits the `#valtype`/`Double`-first/raising
function shape, the reference evaluator checks the expected returned value and
records success/error paths, and the reducer shrinks the probe's input without
removing the trigger scaffold. It is deliberately not general `Double` or
exception support. Seed 0 generated the probe and passed reference plus `js`,
`wasm`, and `wasm-gc` execution; a 10-seed depth-4 batch included the probe in 6
programs (3 cases visited the modeled error path, 4 the success path; these are
reference traces, not backend runtime coverage). The report is local and ignored
at `.moonsmith/runs/batch_20261009_133053_806.json`.

The comparison script is a bootstrap host adapter. Differential result types,
stdout/stderr normalization, failure classification, stable signatures, and an
explicitly labelled output-mismatch injection now run through the MoonBit
oracle. The bootstrap adapter also owns time limits and persistence; AST
reduction is now implemented for the supported expression subset.

## Runner and corpus layer

- Generator, build, execution, and oracle subprocesses now have explicit time
  budgets and process-tree termination.
- Diagnostics normalize the workspace root to `<workspace>` before signature
  construction.
- Non-consistent cases are keyed by the first 16 hexadecimal characters of a
  SHA-256 signature hash and persist `source.mbt` plus `report.json`.
- Injected cases are isolated from real findings under `.moonsmith/injected`.
- Missing backend prerequisites use `environment-failure`, not
  `compile-failure`, and are isolated under `.moonsmith/environment`.
- `scripts/run_batch.ps1` runs deterministic seed ranges and stores aggregate
  counts, unique failure signatures, durations, and per-seed summaries.
- Batch reports also group signed non-consistent cases by finding kind and
  signature, list their seeds/case IDs, and select the lowest-seed representative.
  Harness errors without a signature remain outside clusters; synthetic tests
  cover duplicates, distinct findings, and missing signatures.
- The first persisted 10-seed batch completed 30 backend executions with zero
  unexpected findings in 13.8 seconds on the development workstation.

## Reducer foundation

- Expressions expose a deterministic complexity metric.
- The first reducer pass generates unique, type-preserving candidates for
  literals, arithmetic, comparisons, negation, and conditional expressions.
- Every candidate must be strictly simpler than its parent expression.
- Tests check these invariants over 100 generated seeds on all three bootstrap
  backends.

The host-side replay loop now compares the baseline finding and reduction
key, accepts only strictly smaller candidates, repeats the baseline and final
case, and saves a separate record for each reduction run. A source-dependent
injected mismatch was reduced from complexity 18,270 to 1,003 while retaining
the triggering `if` expression. This is a harness validation, not a real
compiler finding. See `docs/reduction.md` for scope and limitations.

## Fixed-seed scan

On 2026-10-08, a stable run tested seeds 0–99 at depth 4 on `js`, `wasm`, and
`wasm-gc` with MoonBit `0.1.20260920`. All 100 cases were classified
`consistent`; there were zero harness errors and the harness digest did not
change during the run. This is 300 backend executions, not 300 independent
programs. Excluding the seed comment, 94 distinct program bodies were
generated. Source sizes ranged from 60 to 483 bytes, averaging 179 bytes.

The summary is stored at
`.moonsmith/runs/batch_20261008_083752_443.json` on this workstation.
The scan did not discover a compiler defect. Its evidence is limited to the
small expression subset currently generated.

An earlier 100-seed run was invalidated by an Oracle interface change while
it was in progress. It produced harness errors and is excluded from these
results. Batch summaries now include a before/after harness digest so such
runs can be identified automatically.

## Reference evaluator

The generator's IR now has a small MoonBit interpreter for integers, booleans,
addition, comparison, negation, and lazy conditionals. The runner compares
each successful backend's output with this expected result. When all backends
agree with each other but disagree with the reference, the Oracle reports
`reference-mismatch`.

An injected common wrong output was correctly classified as
`reference-mismatch`, and the reducer re-evaluated the reference for each
accepted candidate. The earlier source-triggered backend mismatch regression
still passes.

A second stable scan on 2026-10-08 tested seeds 0–99 at depth 4. All 100
reference checks and 300 backend executions were consistent; there were no
findings or harness errors. Fifty cases returned integers, fifty returned
booleans, and the expected outputs had 38 distinct values. The report is
`.moonsmith/runs/batch_20261008_085023_204.json`.

The interpreter runs on the MoonBit toolchain itself. It provides an
independently structured evaluation path from the generated source, but a
shared compiler defect could still affect both. These checks do not establish
full language correctness.

## Boolean pattern matching

The typed IR, source printer, reference interpreter, and shrinker now support
exhaustive matches on `Bool`. A stable 100-seed scan at depth 4 completed 300
backend executions and 100 reference checks with zero findings or harness
errors. Seventy-seven generated sources contained a `match`; excluding seed
comments, the scan produced 90 distinct bodies. The report is
`.moonsmith/runs/batch_20261008_085845_165.json`.

The preceding expression-only 100-seed scan produced 94 distinct bodies.
Adding match syntax increased construct coverage but did not improve source
diversity in this seed range. The generator's small modulo-based seed space
and correlated branching motivated the next iteration.

## Scoped bindings and seed coverage

The generator now emits typed, scoped `let` bindings and variable references.
The reference evaluator tracks lexical bindings and shadowing. The AST reducer
retains bindings when a candidate still uses them and can remove an identity
binding. Unit tests cover evaluation and reduction of these cases. The seed
mixing also uses a wider deterministic state instead of the old 997-seed
cycle; seed 0 and seed 1 no longer map to the same initial state.

Batch reports now record a hash of each program body (excluding the seed
comment) and lexical counts for `let`, `match`, and `if`. In the stable
100-seed scan at depth 4, all 100 reference checks and 300 executions on
`js`, `wasm`, and `wasm-gc` were consistent, with no harness changes during
the run. There were 92 distinct bodies; 82 cases contained `let`, 57
contained `match`, and 49 contained `if`. These are source-occurrence
indicators, not a measure of executed path coverage. The report is
`.moonsmith/runs/batch_20261008_091919_993.json`.

The source-dependent injected fault still reduces from complexity 3,028 to
1,003 in 4 accepted steps and 13 attempts (seed 20, depth 2). This confirms
the harness path, not a MoonBit compiler defect. The 8 duplicate bodies in
the 100-seed scan show that structural diversity still needs improvement.

## Branch mixing and arithmetic/logic expansion

The prior generator selected grammar alternatives with `seed % 6` while also
using seed parity to select the result type. This correlated the two choices:
top-level boolean programs could only select half of the available grammar
branches. The generator now mixes the seed before branch selection and adds
subtraction and short-circuit boolean conjunction. The MoonBit interpreter,
printer, reducer, and tests cover both constructs.

After this change, a stable 100-seed depth-4 scan on `js`, `wasm`, and
`wasm-gc` produced **100 distinct program bodies**, with 100 consistent
reference checks and 300 successful backend executions. Ninety-nine cases
contained `let`, 88 contained `match`, 75 contained `if`, 77 contained
subtraction, and 67 contained conjunction. These lexical indicators do not
measure executed branch coverage. There were no harness errors or harness
digest changes. The report is
`.moonsmith/runs/batch_20261008_122250_689.json`.

The injected output mismatch still reduces reproducibly (seed 20, depth 2):
complexity 6,038 to 2,004 in 7 accepted steps and 18 attempts. No real
compiler defect has been established by these scans. The next bottleneck is
broader semantic coverage and a more usable CLI/reporting surface, not merely
more seed counts.

A structural-diversity regression test now requires at least 95 distinct
expression bodies from the first 100 seeds. The early bootstrap note that CI
had only been checked locally is historical and no longer applies: the remote
workflow has passed repeatedly, most recently in [run 38272335209](https://github.com/Yingqingxue/moonsmith/actions/runs/38272335209).

## Unified host CLI

`scripts/moonsmith.ps1` now exposes `doctor`, `fuzz`, `replay`, `reduce`, and
`report`.
`doctor` executes a small real backend probe; `fuzz` delegates to the stable
batch runner; `replay` rechecks a saved finding against its original finding
kind and reduction key; `reduce` runs the generated-seed reducer. A CLI
integration test validates `doctor`, a two-seed batch, and an explicitly
injected saved-case replay. This is a PowerShell host adapter, not yet a
standalone native MoonBit executable. Arbitrary-source reduction remains
unfinished.

## Finding reports

The host CLI now renders a saved finding and optional matching reduction as
both `report.md` and a self-contained `report.html` that opens offline. They
include the source hash, toolchain and host metadata for new cases, per-backend
status/output/diagnostics, reference output, reduction metrics, and a replay
command. HTML-encodes saved source and diagnostics, with no script elements.
Reports explicitly mark injected demonstrations
and environment failures as non-defects; real findings are labelled
unconfirmed candidates. Source hashes, reduction identity, and equality of
the reduction's original source with the saved canonical case are checked
before rendering. CLI integration tests exercise both formats. Existing
reports are not overwritten without `-Force`.

## Fixed-size array expressions

The typed IR, printer, reference evaluator, and AST reducer now support
two-element arrays followed by a safe constant index (`0` or `1`). Element
expressions may be `Int` or `Bool`; both elements are evaluated when the array
literal is created, matching the generated MoonBit source. Reducer candidates
may replace the selection with either same-typed element, and the host reducer
still accepts a candidate only when replay preserves the failure key.

All 39 tests pass separately on `js`, `wasm`, and `wasm-gc`. A stable depth-4
scan of seeds 0–99 completed 100 reference checks and 300 backend executions:
all were consistent, all 100 program bodies were distinct, and the harness
digest did not change. Arrays appeared in 92 cases; 74 cases contained index
`0` and 71 contained index `1` (a case can contain both). These are lexical
presence counts, not executed branch coverage. The report is
`.moonsmith/runs/batch_20261009_091459_066.json`.

The scan took 530,732 ms on the current workstation, substantially longer
than earlier runs. No controlled performance benchmark was performed, so this
must not be presented as a generator or compiler performance result. No real
MoonBit compiler defect was found.

## Typed local function application

The IR now models a restricted local unary function whose parameter and
result share a known `Int` or `Bool` type. Generated source constructs a
function value with `fn(parameter : Type) { body }` and invokes it with a
generated argument. Function bodies may capture enclosing `let` bindings.
The reference evaluator implements eager argument evaluation and lexical
parameter binding; the reducer preserves parameter scope and never emits the
bound parameter as a standalone candidate.

All 42 tests pass separately on `js`, `wasm`, and `wasm-gc`. Reference and
reducer integration fixtures also pass. A stable depth-4 scan of seeds 0–99
completed 100 reference checks and 300 backend executions with zero findings,
zero harness errors, 100 distinct program bodies, and no harness digest
change. Functions occurred lexically in 84 cases: 63 included an `Int`
function and 52 included a `Bool` function; a case can contain both. These
counts do not prove that every function appeared on the dynamically selected
branch. The report is `.moonsmith/runs/batch_20261009_094200_029.json`.

This scan took 575,187 ms on the current workstation. It was not a controlled
benchmark and must not be compared as a compiler performance result. No real
MoonBit compiler defect was found.

## Reference-path trace

The reference evaluator can now return the constructs and decisions visited
while evaluating one expression. The trace records only the selected `if` and
`match` arm, whether `&&` evaluated its right-hand side, and the selected safe
array index; it also records dynamically evaluated operations, bindings, and
function calls. `verify_seed.ps1` includes this trace for generated-seed runs,
and batch schema version 3 counts the number of cases in which each trace kind
was observed. A direct `--trace` mode is available from `cmd/main`.

This is execution-path evidence from the MoonBit reference interpreter, not
runtime coverage instrumentation inside JS, wasm, or wasm-gc. It must not be
described as backend branch coverage. Arbitrary-source runs have no such trace.
The three backend test suites now each contain 44 passing tests; the reference,
reducer, and CLI integration checks were also run after this change.

## Typed record expressions

The generator now emits a two-field `Pair` record with an `Int` field and a
`Bool` field, constructs it, reads both fields, and returns either field. The
record declaration is included only when the generated expression uses it, so
ordinary generated cases remain warning-free under `--deny-warn`. Both fields
are read deliberately because MoonBit reports an unused-field warning when a
field is never accessed. The reference evaluator follows eager field
evaluation, records both field reads and the selected result field, and the
reducer can simplify either field while preserving the expression's result
type.

After this addition, each of the `js`, `wasm`, and `wasm-gc` suites passed 47
tests, and the reference, reducer, and CLI integration scripts passed. Seed 0
is a generated record case and matched output `7` on all three backends.

A new stable 100-seed depth-4 batch completed with 100 reference checks and 300
backend executions, all consistent; there were 100 distinct program bodies,
zero harness errors, and no harness digest change. Records appeared in 84
sources. The reference-path trace observed record construction in 70 cases,
both field reads in those same 70 cases, and the integer/boolean selected field
in 53/40 cases respectively (cases may select both in nested expressions).
These are source-presence and reference-interpreter path counts, not backend
coverage. The batch took 602,393 ms on this workstation, not a controlled
benchmark. Its report is
`.moonsmith/runs/batch_20261009_102601_209.json`. No real compiler defect was
found.

## Tagged enums with payload matching

The IR now supports a closed `Choice` enum with `Number(Int)` and `Flag(Bool)`
payload constructors. Generated expressions construct a value, exhaustively
match both variants, bind each payload in its corresponding branch, and use
those bound values in type-correct branch bodies. The enum declaration is
emitted only when needed and is public in the standalone generated module so
the compiler does not reject an otherwise-valid corpus case merely because
one payload constructor is absent from that individual source. The reference
interpreter models both tagged values, lexical payload binding, and the selected
branch; the reducer preserves the scrutinee type and branch scopes.

All 50 tests pass on each of `js`, `wasm`, and `wasm-gc`; static checks and the
reference/reducer/CLI integration scripts pass. The fixed seed-0 enum-containing
program compiled and agreed on all three backends. The current 100-seed depth-4
batch then completed 100 reference checks and 300 backend executions with zero
findings, zero harness errors, 100 distinct program bodies, and no harness
digest change. Enum matching appeared in 91 sources. The reference interpreter
visited `Number` and `Flag` match arms in 57 and 41 cases, respectively (case
counts can overlap due to nested matches). This remains reference-path evidence,
not backend runtime coverage. The scan took 611,465 ms on this workstation and
is not a controlled benchmark. Report:
`.moonsmith/runs/batch_20261009_105218_451.json`. No real compiler defect was
found.

## Bounded `for` expressions with loop-carried state

The typed IR and generator now include bounded `for` expressions with an
integer index and accumulator updated simultaneously. Each generated loop runs
0–5 iterations; its update expression reads both the current index and
accumulator. The MoonBit printer emits the loop as an integer-valued expression
with a `nobreak` result. The reference evaluator models loop-variable scope,
accumulator updates, zero-iteration exit, and records `for-loop`,
`for-iteration`, and `for-normal-exit` trace events. The reducer can remove the
loop, reduce its bound to zero, and simplify its initializer or body while
preserving result type and loop-variable scope.

The generator also samples a bounded `while` variant over the same index and
accumulator update expression. Its printer uses mutable locals, the reference
interpreter records `while-loop`, `while-iteration`, and `while-normal-exit`,
and the reducer preserves the loop's bound-variable scope. Each generated
`while` has a fixed 0–5 iteration bound, so this is not general loop or
termination-condition fuzzing. Batch summaries separately count generated
`while` syntax and executed reference-interpreter paths; the HTML report places
iteration-case counts in the reference-trace table. Older corpus counts
below predate this addition and should not be attributed to the new generator.

All 61 main-package tests pass on each of `js`, `wasm`, and `wasm-gc`; both
historical regression packages pass, and static, reference, reducer, and CLI
integration checks pass. After adding the targeted `ValtypeRaiseProbe`, a fixed
100-seed depth-4 scan on MoonBit `0.1.20260920 (914d7da 2026-09-20)` completed
100 reference checks and 300 backend executions across `js`, `wasm`, and
`wasm-gc`. All cases were consistent, with 100 unique program bodies, zero
harness errors, and an unchanged harness digest. The probe appeared in 43
generated sources and was visited in 29 reference traces: 18 success-path and
14 error-path case occurrences (some cases visited both). Loops appeared in 68
sources and reference iteration traces in 59 cases. These are source and
reference-interpreter counts, not backend runtime coverage. The scan took
534,291 ms, not a controlled performance benchmark. Raw report:
`.moonsmith/runs/batch_20261009_133613_232.json` (ignored and local only). No
unreported MoonBit compiler defect was found by that scan. Separately, the
optional MoonReduce adapter has now reduced the externally reported
`moonbit-docs#1322` native-debug reproducer from 275 to 263 bytes in a hosted
run, preserving the exact MoonSmith finding and passing independent final
replay. Artifact inspection showed it removed only blank lines and `///|`
separators, not executable statements, so it is a format-only shrink rather
than semantic minimization. This validates one issue-linked preservation and
replay workflow; it is not a MoonSmith discovery or a general reduction-quality
claim. See the
[MoonReduce #1322 evidence](evidence/moonreduce_upstream_1322_20261016.md).

## Ecosystem comparison baseline

A source-based comparison of Csmith, YARPGen, C-Reduce, and MoonBit QuickCheck
is recorded in `docs/ecosystem_comparison.md`. It distinguishes the current
MoonSmith implementation from unverified claims: the tool has a MoonBit-targeted
typed generator, reference evaluator, three-backend comparison, and generated-AST
reducer, but has not independently discovered an unreported real compiler bug,
does not yet include an arbitrary-source reducer, and has no optimizer-directed
generator. One reduction of an externally reported compiler issue is documented
as a case study, not discovery evidence. This is desk research, not an external
review or a comparative effectiveness experiment. The next validation gap is a
larger redistributable set of previously reported MoonBit compiler regressions
and an external scope review. One minimal coverage-tool ICE regression from
`moonbitlang/moonbit-docs#1071` and one reported Wasm backend regression from
`moonbitlang/moonbit-docs#1274` are now included; both pass under the current
toolchain. See `docs/regressions.md`. The Wasm issue remains open upstream, and
neither case was discovered by MoonSmith or estimates detection recall.

## Composed valtype probes

The generator now deliberately includes a deterministic mix of
`ValtypeRaiseProbe(ValtypeEnumArrayProbe(...))` alongside standalone raise
probes. Seed 44607 is the fixed end-to-end case. Its generated source compiles
and agrees with the reference evaluator on JS, Wasm, and Wasm-GC; the reference
trace visits both probe kinds. The reducer's injected-mismatch test accepts
three shrink steps (complexity 17,132 → 3,001) while retaining the array and
raise scaffolds.

A 30-seed depth-4 scan over seeds 44607–44636 completed 30 reference checks and
90 backend executions, all consistent, with 30 unique program bodies. Fourteen
sources contained a direct raise-over-enum-array composition; nine evaluated
reference traces visited both probe kinds. These are source-presence and
reference-interpreter observations, not backend coverage. Runtime was 186,503
ms on this workstation, not a controlled benchmark. No compiler defect was
found. See [composition scan evidence](evidence/valtype_composition_scan_20261012.md);
the raw JSON remains local and ignored.

The initial 30-seed composition cohort was selected around a known trigger seed.
To measure a broader ordinary range, schema-v7 batch reporting now counts
direct source compositions and cases whose reference traces visit both probe
kinds. An unselected depth-4 cohort of seeds 0–49 then passed 50/50 reference
checks and 150/150 backend executions, with 50 unique bodies and an unchanged
harness digest. Thirteen sources contained a direct composition and ten
reference traces visited both probes. This is observed frequency in this
small cohort, not backend coverage or a frequency guarantee. Runtime was
307,214 ms on this workstation; raw JSON is ignored locally. Details are in
the [composition scan evidence](evidence/valtype_composition_scan_20261012.md).

## Reusing MoonBit Target Parity after competition review feedback

On 2026-10-16, the per-seed oracle adapter began using the pinned
`zhangbowen2006/moonbit-target-parity@0.5.1` library for complete successful
backend matrices. Its independent status/result is included in `targetParity`
in the `verify_seed.ps1` JSON output (schema 7). The adapter passes each target's
exit code/stdout and, when present, the reference evaluator's expected output;
it disables stderr comparison because MoonSmith's current success contract is
about exit code and stdout, while warnings on stderr are not a failure. It skips
incomplete or failed runs rather than mapping compile errors or timeouts into
ordinary observations. MoonSmith continues to own those terminal states,
diagnostic normalization, reduction signatures, and AST shrinking.

Validation on MoonBit `0.1.20260920`: `moon check --deny-warn` and 107 tests on
each of JS, Wasm, and Wasm-GC passed. The reference, reducer, and CLI PowerShell
integration scripts passed; the reference script verifies a normal report has
Target Parity `pass`, and an injected common-mode wrong output is independently
`divergent`. Native tests could not run on this Windows workstation because it
has no C compiler. The first pushed attempt pinned GitHub's 0.5.1 main-branch
version before it was published. A later clean-runner attempt still failed on
0.5.0 because the package registry index had not been refreshed. Mooncakes now
lists 0.5.1; the dependency is pinned to that release, and each CI job now runs
`moon update` before resolving dependencies. [CI run 38873391261](https://github.com/Yingqingxue/moonsmith/actions/runs/38873391261)
then passed both standard Linux and Windows jobs, including dependency
resolution and the full native/reducer smoke path; the targeted
[semantic-selection run 38873580951](https://github.com/Yingqingxue/moonsmith/actions/runs/38873580951)
also completed successfully. This is
evidence of one integration, not proof that MoonSmith is distinct from the
other named projects or that it has discovered an unreported MoonBit compiler
bug. The remaining positioning risks and feature boundaries are recorded in
[`ecosystem_comparison.md`](ecosystem_comparison.md). The exact two-command
smoke evidence is in
[`target_parity_adapter_20261016.md`](evidence/target_parity_adapter_20261016.md).

## Batch-level Target Parity gate

The single-seed result was visible after the first adapter, but the batch
`fuzz` path was dropping that nested result. Per-seed saved-report schema 7 now
includes the adapter result, and standalone Markdown/HTML reports show its
status and matrix summary. Older saved reports without that field are labelled
`not recorded`, distinct from a current report's `not run` status; existing
saved case artifacts are never overwritten on reuse. Batch schema 11 carries each case's `targetParity`
object and summarizes `pass` / `divergent` /
`inconclusive` counts, and renders the status in the offline HTML. Nightly
schema-11 validation requires all 1,000 cases to have a per-case Target Parity
`pass`; the Linux/Windows comparison also rejects a non-passing result on either
side and requires matching Target Parity statuses. Older report schemas remain
accepted by the general renderer/comparator, but the stricter nightly gate only
accepts schema 11. These checks validate the successful matrices captured by
the harness, not compiler correctness or a historical bug-discovery claim.

The two-seed CLI smoke report contained two per-case `pass` results. The schema,
full CLI/batch, and batch-report PowerShell regression tests pass; the latter
also verifies that a non-passing result is rejected. A fresh remote CI run for
the published dependency and batch-schema changes is still required; the local
Windows host has no C compiler, so native compilation remains a remote-CI check
rather than a local claim.
