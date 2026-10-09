# Historical MoonBit compiler regression corpus

This is a deliberately small, provenance-tracked starting corpus, not a
representative benchmark and not evidence of MoonSmith's bug-finding rate.
Only minimized examples whose source issue and behavior can be checked are
included. We do not copy third-party project snapshots into this repository.

## Case 1: non-Unit `main` method breaks coverage analysis

- Upstream report: [moonbitlang/moonbit-docs#1071](https://github.com/moonbitlang/moonbit-docs/issues/1071)
- Reported: 2025-12-10; marked closed upstream.
- Reported symptom: `moon coverage analyze` ICEs when a type defines
  `fn X::main() -> String`.
- Local fixture: `regressions/issue_1071_coverage_ice/repro.mbt`.
- Current validation: MoonBit `0.1.20260920`, `moonc v0.10.14+7d59c7ec9`,
  JavaScript target; the instrumented test passes (1/1) and the package-scoped
  `moon coverage analyze` succeeds.
- Scope: this confirms the historical trigger is handled by the current
  toolchain. It is not a backend miscompilation, and this fixture does not
  exercise MoonSmith's generator or claim it discovered the upstream issue.

Reproduce from the repository root:

```powershell
moon test --target js --enable-coverage --deny-warn regressions/issue_1071_coverage_ice
moon coverage analyze -p Yingqingxue/moonsmith/regressions/issue_1071_coverage_ice
```

The first command is part of CI. The second checks that coverage reporting can
consume the instrumentation output, rather than only checking that the fixture
compiles.

## Case 2: `#valtype` Double returned through `raise` on Wasm

- Upstream report: [moonbitlang/moonbit-docs#1274](https://github.com/moonbitlang/moonbit-docs/issues/1274)
- Reported: 2026-06-26; GitHub's issue API still reports it open on
  2026-10-10 (last updated 2026-07-01).
- Reported symptom: Wasm validation fails when a `#valtype` struct whose first
  field is `Double` is returned from a `raise`-capable function and consumed via
  `try?`.
- Local fixture: `regressions/issue_1274_wasm_valtype_raise/repro.mbt`.
- Current validation: MoonBit `0.1.20260920`, `moonc v0.10.14+7d59c7ec9`;
  JS, Wasm, and Wasm-GC tests each pass (1/1). The reported Wasm failure did not
  reproduce on this toolchain. The source retains upstream's deprecated `try?`
  construct intentionally to preserve the reported trigger shape.
- Scope: this is a historical regression test against a public issue, not a
  MoonSmith-discovered bug. MoonSmith now generates this trigger shape through
  a dedicated typed AST probe and compares the compiled result to its reference
  model. It still does not generate arbitrary `#valtype` layouts or general
  `raise` expressions; this narrow probe is not evidence of broad exception or
  floating-point coverage.

Reproduce from the repository root:

```powershell
moon test --target js regressions/issue_1274_wasm_valtype_raise
moon test --target wasm regressions/issue_1274_wasm_valtype_raise
moon test --target wasm-gc regressions/issue_1274_wasm_valtype_raise
```

The fixture package disables only the `deprecated` warning because `try?` is
part of the historical trigger. Do not replace it mechanically: changing the
construct may stop testing the original result-lowering path.

## Candidate not yet included

[moonbitlang/core#1594](https://github.com/moonbitlang/core/issues/1594) reported
undefined-behavior-sanitizer findings in generated C for signed integer
overflow in the native backend; GitHub's issue API reports it closed since
2025-02-11. The linked reproducer is a full third-party project, not a small
self-contained source fixture; the report concerns native runtime semantics
and does not directly match MoonSmith's current JS/wasm/wasm-gc matrix. It is
not included as a regression because its source, license, exact toolchain,
sanitizer setup, and current reproduction status have not been audited. It is
not a MoonSmith-discovered bug.

## What this corpus can and cannot show

The included case tests whether a known historical compiler-tooling failure
still reproduces. It does not measure issue-detection recall, current compiler
quality, or comparative fuzzing effectiveness. Add further cases only with a
stable upstream source, a small redistributable fixture or reproducible fetch
procedure, exact expected behavior, and a current-toolchain result.
