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
metrics and minimal source. Both reports include escaped source/output,
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
addition, subtraction, comparisons, short-circuit conjunction, negation,
conditional expressions, boolean and tagged-enum pattern matching, scoped
`let` bindings, two-element arrays with safe constant indexing, two-field
structs, and typed local function application with captured outer bindings.
Generated tagged-enum matches can also receive `Choice` values returned by a
typed local function, exercising payload typing through generation, printing,
reference evaluation, and reduction.
It also generates bounded `for` loops with an index and accumulator updated
together, and models loop-carried values in the reference evaluator and AST
reducer. One narrow probe emits a `#valtype` struct with a `Double` first field
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
Batch schema 8 now reports Choice-returning-function coverage explicitly, and
the nightly validator requires nonzero case and function counts so a corpus
cannot pass while omitting this new generator branch.
When both extended workflow inputs are enabled, CI also downloads and compares
the Linux and Windows reports, failing on a seed-set, toolchain, source-hash,
reference-output, or finding mismatch.

The nightly Actions workflow scans fixed seeds 14990–15989 on Linux across
JS/Wasm/Wasm-GC and retains its machine-readable report for 30 days. Its first
manual validation run and a later end-to-end workflow check both predate the
Choice-returning extension. A fresh run on the updated generator checked 1,000
distinct bodies and 3,000 backend executions without findings; see the
[updated corpus evidence](docs/evidence/choice_function_corpus_20261013.md).
These nightly scans are Linux-only and do not cover native backends. The
workflow generates a self-contained HTML summary with separate generated-source
and reference-trace coverage, finding counts, failure clusters, and per-seed
results; for a local batch, use
`pwsh -File scripts/moonsmith.ps1 batch-report -BatchPath <batch-json>`, adding
`-BatchOutputPath <summary.html>` when you want to choose the HTML destination.

Licensed under Apache-2.0.
