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
To create a Markdown case report, run
`pwsh -File scripts/moonsmith.ps1 report -CasePath <finding-directory>`.
Pass `-ReductionPath <reduction-directory>` to include verified reduction
metrics and minimal source. Existing `report.md` files are kept unless
`-Force` is supplied.

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
It also generates bounded `for` loops with an index and accumulator updated
together, and models loop-carried values in the reference evaluator and AST
reducer. A narrow, issue-motivated probe emits a `#valtype` struct with a
`Double` first field through a `raise`/`try?` path, with reference evaluation
and shrinking. This does not imply general floating-point or exception
generation support.
The reducer works on generated ASTs and verifies candidates against the
original backend relationship. Arbitrary MoonBit source reduction is not
implemented yet.

See the [project plan](MoonSmith_项目计划书.md), [implementation status](docs/status.md),
the [ecosystem comparison](docs/ecosystem_comparison.md),
the [historical regression corpus](docs/regressions.md),
the [pre-review risk gate](docs/pre_review_gate.md), and
[reduction design](docs/reduction.md). The reproducible 1,250-program
JS/Wasm/Wasm-GC scan and 130-program Windows native scan summaries are in
[seed scan evidence](docs/evidence/seed_scans_20261009.md).

Licensed under Apache-2.0.
