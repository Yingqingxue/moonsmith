# MoonSmith

MoonSmith is a MoonBit compiler backend differential tester. It generates a
deterministic, typed MoonBit program, evaluates its expected output with a
small reference interpreter, executes it on the `js`, `wasm`, and `wasm-gc`
backends, classifies differences, and reduces reproducible findings.

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

The PowerShell entry point is a thin process/IO adapter. The generator,
reference evaluator, differential oracle, and AST reducer are implemented in
MoonBit. `fuzz` returns a JSON batch report and exits nonzero on an unexpected
finding. `replay -CasePath PATH` takes a saved finding directory or its
`report.json` and succeeds only if the finding and reduction key match again.

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
[reduction design](docs/reduction.md). The reproducible 1,020-seed scan summary
is in [seed scan evidence](docs/evidence/seed_scans_20261009.md).

Licensed under Apache-2.0.
