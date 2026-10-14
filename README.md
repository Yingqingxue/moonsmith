# MoonSmith

MoonSmith is a MoonBit compiler backend differential tester. It generates a
deterministic, typed MoonBit program, evaluates its expected output with a
small reference interpreter, executes it on the `js`, `wasm`, and `wasm-gc`
backends (plus optional `native` when a C toolchain is available), classifies
differences, and reduces reproducible findings.

Current maintainer: [Yingqingxue](https://github.com/Yingqingxue).

## Requirements

- MoonBit toolchain (`moon` on `PATH`)
- PowerShell 7 (`pwsh`)
- A local C compiler only if the optional `native` backend is selected

## Run

```powershell
moon test --target js
moon test --target wasm
moon test --target wasm-gc

pwsh -File scripts/moonsmith.ps1 doctor
pwsh -File scripts/moonsmith.ps1 fuzz -SeedStart 0 -Count 100 -Depth 4
```

For a one-command tour of detection, AST reduction, replay, and report
generation, run `pwsh -File scripts/moonsmith.ps1 demo`. It injects a labelled
output mismatch into one backend and prints paths to the saved Markdown and
offline HTML reports. The result demonstrates MoonSmith's workflow; it is not
a MoonBit compiler defect.

To include the optional `native` target, pass
`-Targets @('js','wasm','wasm-gc','native')`; native requires a compatible
system C toolchain. If it is missing, the runner reports an environment
failure rather than treating it as a compiler finding.
`native` uses MoonBit's default debug mode; add `native-release` to `-Targets`
to execute the same generated source with native release settings as a separate
differential configuration.

The PowerShell entry point is a thin process/IO adapter. The generator,
reference evaluator, differential oracle, and AST reducer are implemented in
MoonBit. `fuzz` returns a JSON batch report and exits nonzero on an unexpected
finding. `replay -CasePath PATH` takes a saved finding directory or its
`report.json` and succeeds only if the finding and reduction key match again.
Generated sources over 16,300 lines are reported as `generator-limit` and are
not sent to the reference evaluator or compiler backends; `fuzz` still exits
nonzero so the size bound stays visible in batch results.
Depth is a maximum recursive branching depth, not a promise that every seed
will fit the source-size bound: observed scans had 6 size limits in 330 depth-10
seeds and 71 in 100 depth-11 seeds. Further depth-10 scans brought the
observed depth-10 total to 12 limits in 630 seeds; depth 11 remains much less
reliable. For routine batches, prefer depth 10 or lower and review
`generator-limit` counts rather than silently discarding cases.
Per-seed JSON reports include `sourceLineCount` and, for generated inputs, the
applicable `sourceLineLimit`; batch JSON also reports how many cases have size
data and the largest source. This makes the size guard auditable for successful
as well as rejected inputs.
Batch JSON groups non-consistent cases by finding kind and stable signature,
listing affected seeds and case IDs and selecting the lowest-seed representative
for triage. Cases without a signature (such as harness failures) are not
misrepresented as a cluster.
Batch seed ranges must also stay within MoonBit's signed 32-bit `Int` domain;
the runner rejects an overflowing range before starting any compiler process.

To test whether reference-semantic-path-guided selection improves a fixed
backend budget over sequential seed scanning, run:

```powershell
pwsh -File scripts/compare_semantic_selection.ps1 -SeedStart 24000 `
  -CandidateCount 40 -ExecutionBudget 10 -Depth 4 `
  -Targets @('js','wasm','wasm-gc')
```

The script prescreens all candidates using the MoonBit reference evaluator,
then greedily favors paths rare in that candidate pool and not yet represented
among selected cases. Both arms execute the same number of selected programs
against the same backend matrix; the JSON records actual runtime launches and
marks the comparison invalid if either arm falls short. It also records
prescreen and execution time, toolchain/revision, harness digest, case overlap,
source size, program-body
diversity, and findings; unexpected findings retain their normal saved case
artifacts for triage. Reference paths are **not** backend runtime coverage.
This is an experiment, not a demonstrated improvement or a new-bug claim;
compare multiple nonoverlapping cohorts and alternate arm order with
`-GuidedFirst` before drawing an effectiveness
conclusion. Reports are saved under ignored `.moonsmith/runs/`.

For a repeatable demonstration of fault detection and reduction (an explicitly
injected fault, **not** a MoonBit compiler bug):

```powershell
pwsh -File scripts/moonsmith.ps1 reduce -Seed 20 -Depth 2 `
  -InjectOutputMismatchTarget wasm-gc `
  -InjectOnlyWhenSourceContains '(if'
```

`reduce` currently accepts a generated seed, not arbitrary MoonBit source.
Saved findings and batch summaries live under the ignored `.moonsmith`
directory. A saved injected output mismatch can be replayed with
`pwsh -File scripts/moonsmith.ps1 replay -CasePath <finding-directory>`.
To create a Markdown and standalone offline HTML case report, run
`pwsh -File scripts/moonsmith.ps1 report -CasePath <finding-directory>`.
Pass `-ReductionPath <reduction-directory>` to include verified reduction
metrics, accepted-step history, and minimal source. Both reports include escaped source/output,
backend results, evidence classification, and a replay command. Existing
`report.md` or `report.html` files are kept unless `-Force` is supplied.

The reference check also detects when every backend returns the same wrong
value. Its interpreter is written in MoonBit and runs through the MoonBit
toolchain; it provides a separate semantic path from generated source, but
is not an independent compiler implementation.

Run the corresponding integration check with
`pwsh -File scripts/test_reducer.ps1` and
`pwsh -File scripts/test_cli.ps1`.

## Current scope

The generator supports a small total expression language: integers, booleans,
addition, subtraction, comparisons, short-circuit conjunction and disjunction,
negation, conditional expressions, boolean and tagged-enum pattern matching,
scoped `let` bindings, two-element arrays with safe constant indexing, bounded
empty-array growth by two pushes, two-field
structs, and typed local function application with captured outer bindings.
Array growth currently handles `Int` and `Bool` elements only; that slice does
not generate arbitrary indices, removals, or aliasing.
For two-element `Int` and `Bool` arrays, the generator also tests a separate
alias-update slice: it writes through one array alias, reads through the
original binding, and checks that the other element was not changed. If the
generated replacement equals the selected old value, the probe substitutes
a different value so a missing write cannot masquerade as a correct result. The
reference evaluator and AST reducer support this slice; it does not model
general mutable-array programs. See the
[array alias-update evidence](docs/evidence/array_alias_update_20261014.md)
for fixed-corpus and Windows native-release results.
The fixed nightly corpus exercises both grown-array indices with a minimum
per-index reference-path floor; see the
[array-growth balance evidence](docs/evidence/array_growth_balance_20261014.md).
Generated tagged-enum matches can also receive `Choice` values returned by a
typed local function, exercising payload typing through generation, printing,
reference evaluation, and reduction.
It also generates bounded `for` and `while` loops with an index and accumulator
updated together, and models loop-carried values in the reference evaluator
and AST reducer. The `while` form uses mutable locals and a fixed 0–5 iteration
bound; it does not exercise arbitrary loop conditions or early exits. One narrow
probe emits a `#valtype` struct with a `Double` first field
through a `raise`/`try?` path. A second probe creates an empty array, pushes a
`#valtype` struct with an enum field, reads the first element's enum, appends a
second element, then reads its integer field to exercise array growth. Its
first append mirrors the relevant source shape from upstream issue
[#1322](https://github.com/moonbitlang/moonbit-docs/issues/1322), which
MoonSmith did not discover. Both probes have reference evaluation and AST
shrinking, but do not imply general floating-point, exception, enum, or array
generation support.
The reducer works on generated ASTs and verifies candidates against the
original backend relationship. Arbitrary MoonBit source reduction is not
implemented yet.

See the [project plan](MoonSmith_项目计划书.md), [implementation status](docs/status.md),
the [ecosystem comparison](docs/ecosystem_comparison.md),
the [historical regression corpus](docs/regressions.md),
the [pre-review risk gate](docs/pre_review_gate.md), and
[reduction design](docs/reduction.md). The scan evidence records 3,750
distinct depth-4–10 program bodies checked against the reference evaluator and
JS/Wasm/Wasm-GC, plus separate Windows native runs; size-guarded inputs and
upstream-reported regressions are explicitly distinguished from compiler
findings. See [seed scan evidence](docs/evidence/seed_scans_20261009.md) for
the reproducible report IDs and limits. Those scans were recorded before the
enum/array probe changed the integer branch of the generator; their totals are
historical evidence, not measurements of the current generator distribution.
Before the Choice-returning function extension, the generator was checked on
an initial 360-program fixed-seed scan and four paired 230-seed samples: each
paired source hash matched between Linux JS/Wasm/Wasm-GC and Windows
native-release, for 3,680 consistent backend executions across 920 distinct
generated bodies. See
[current-generator scan evidence](docs/evidence/current_generator_scan_20261012.md);
these measurements do not include the extension and must not be read as its
coverage evidence. The original fixed-seed nightly runs described below
predate this change. A fresh same-toolchain, same-seed comparison now covers the
Choice-returning extension: 1,000 bodies, with 251 changed source hashes and
305 additional local-function nodes. See
[the updated generator evidence](docs/evidence/choice_function_corpus_20261013.md).
Batch schema 10 retains Choice-returning-function coverage and reports
short-circuit conjunction and disjunction coverage per case. The nightly
validator requires both `&&` and `||` in at least 20% of the fixed corpus,
requires both RHS-executed and short-circuited reference paths for each
operator, and reconciles aggregate counts against per-case records. Generated
`&&` and `||` expressions wrap the RHS in a closure that increments a captured
mutable counter; the generated program checks the
operator-specific expected call count, panicking if a backend violates
short-circuit evaluation. This makes incorrect eager execution observable,
rather than relying only on the final boolean value. The nightly gate tracks
both operators, while report renderers and cross-platform comparison retain
compatibility with schema 7–9 reports.
The earlier schema-8 nightly run passed all 1,000 cases, recording 251 cases
and 305 generated Choice-returning functions (see the linked evidence).
When both extended workflow inputs are enabled, CI also downloads and compares
the Linux and Windows reports, failing on a seed-set, toolchain, source-hash,
reference-output, or finding mismatch.

The nightly Actions workflow scans fixed seeds 14990–15989 on Linux across
JS/Wasm/Wasm-GC and retains its machine-readable report for 30 days. The latest
schema-10 strict-gate run checked 1,000 distinct bodies and 3,000 consistent
backend executions; 558 sources contained `&&` (RHS execution in 170 cases,
short-circuit skipping in 178), and 357 contained `||` (141 executed, 162
skipped). Aggregate totals matched per-case records, and the captured-counter
guards passed the JS, Wasm, Wasm-GC, and Windows native-release checks. See the
[short-circuit coverage evidence](docs/evidence/short_circuit_coverage_20261013.md).
A separate 230-seed depth-4/6/8 sample matched source hashes and outputs between
Linux JS/Wasm/Wasm-GC and Windows native-release (920 consistent executions).
See the
[disjunction evidence](docs/evidence/disjunction_corpus_20261013.md) and
[Choice-function evidence](docs/evidence/choice_function_corpus_20261013.md).
The scheduled nightly corpus is Linux-only and does not cover native backends.
The workflow generates a self-contained HTML summary with separate
generated-source and reference-trace coverage, finding counts, failure
clusters, and per-seed results; for a local batch, use
`pwsh -File scripts/moonsmith.ps1 batch-report -BatchPath <batch-json>`, adding
`-BatchOutputPath <summary.html>` when you want to choose the HTML destination.

Licensed under Apache-2.0.
