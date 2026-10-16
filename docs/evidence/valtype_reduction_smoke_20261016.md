# Targeted `#valtype`/`raise` AST-reduction smoke (2026-10-16)

This run exercises MoonSmith's narrow generated probe related to the operation
shape in upstream [moonbitlang/moonbit-docs#1322](https://github.com/moonbitlang/moonbit-docs/issues/1322).
The checked-in reproducer in `regressions/issue_1322_native_valtype_enum_array/repro.mbt`
remains the exact upstream example. The generated seed below is an extension
that also composes the enum-bearing `#valtype` array probe with the existing
`#valtype`/`raise` probe; it is not the upstream reproducer.

## Run and outcome

The same targeted case is part of `scripts/test_reducer.ps1`. Its reduction
uses the JavaScript, Wasm, and Wasm-GC targets available on this Windows host:

```powershell
pwsh -NoProfile -File scripts/reduce_case.ps1 `
  -Seed 44607 -Depth 4 `
  -Targets @('js','wasm','wasm-gc') `
  -InjectOutputMismatchTarget 'wasm-gc' `
  -InjectOnlyWhenSourceContains 'let _ms_valtype_input = _ms_valtype_array_run(' `
  -MaxAttempts 20
```

On MoonBit `0.1.20260920` / MoonC `0.10.14+7d59c7ec9`, the regression script
passed. In this run the baseline was classified as an injected `output-mismatch`
on `wasm-gc`; the same generated case was reduced from complexity 18,133 to
3,001 in 3 accepted steps and 3 attempts. The checked-in test asserts that the
minimal source retains the generated array-probe call, `#valtype` record,
two array pushes, indexed match/read, and `raise`/`try?` composition.

The injected output is a test fault, not a compiler failure. This demonstrates
only that the current AST reducer can preserve a mismatch on this targeted
generated shape. It is not evidence that MoonSmith discovered #1322, that this
upstream issue was caused by the generated extension, or that MoonSmith covers
the backend's internal branches. The local machine has no C compiler, so this
run did not exercise native debug or native release. The exact upstream
native-debug reproducer and its platform/toolchain observations are recorded
separately in [`regressions.md`](../regressions.md).
