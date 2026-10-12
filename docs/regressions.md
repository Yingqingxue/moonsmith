# MoonBit compiler regression corpus and upstream repro probes

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
  JS, Wasm, and Wasm-GC tests each pass (1/1). The fixture asserts the
  error-path result at `Int64` -2147483648, the success boundary at 0, and the
  positive result at 2147483647. The reported Wasm failure did not reproduce on
  this toolchain. The source retains upstream's deprecated `try?` construct
  intentionally to preserve the reported trigger shape.
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

## Case 3: native debug array push of a `#valtype` record containing an enum

- Upstream report: [moonbitlang/moonbit-docs#1322](https://github.com/moonbitlang/moonbit-docs/issues/1322)
- Reported: 2026-10-08, with MoonBit `0.1.20260920` and `moonc
  v0.10.14+7d59c7ec9` (the same versions recorded by this project).
- Reported symptom: native debug linking ICEs in `lower_array_make` for an
  array append of a `#valtype` record containing a reference-carrying enum;
  native release and Wasm-GC produce `0` and `x`.
- Local fixture: `regressions/issue_1322_native_valtype_enum_array/repro.mbt`.
- Generator mapping: `ValtypeEnumArrayProbe` begins with the reported key
  operation shape (empty `Array[MoonSmithEntry]`, then `push` a `#valtype`
  record whose enum carries a `String` reference, followed by indexed enum
  matching) and adds a second append plus indexed read to exercise array
  growth. The checked-in fixture above remains the exact upstream reproducer;
  the generated extension must not be described as that exact reproducer.
  Seed 4 at depth 3 exercises the generated path; its reference trace records
  initialization, both pushes, and both indexed reads. The generated probe is
  semantically modeled by its input integer and does not claim native behavior
  is correct. The extension has passed current Linux and Windows CI.
- Validation: `scripts/test_issue_1322.ps1` checks the Wasm-GC and native
  release control outputs, then classifies native debug as either the reported
  ICE signature or a successful result. The generic verifier now exposes
  `native-release` separately from `native` (debug), recording backend and
  build mode in each run so debug/release configuration differences can be compared
  without changing the generated source. GitHub Actions run
  [37981943718](https://github.com/Yingqingxue/moonsmith/actions/runs/37981943718)
  on MoonBit `0.1.20260920` reproduced the exact ICE signature under Linux/GCC;
  Windows/MSVC native debug did not reproduce it in that run. Native release
  and Wasm-GC passed on both runners. A later successful
  [run 38246227150](https://github.com/Yingqingxue/moonsmith/actions/runs/38246227150)
  used MoonBit `0.1.20261012`: both Linux/GCC and Windows/MSVC reproduced the
  exact native-debug signature for the upstream fixture and the generated
  extension; native release and Wasm-GC passed on both. The reports record GCC
  13.3.0 in both runs and MSVC 19.51.36260 in both Windows runs. Thus the
  observed Windows result changed across MoonBit toolchain versions while the
  reported C compiler versions stayed the same. This correlation does not prove
  the MoonBit update caused the change: runner images and other dependencies
  were not held constant in an A/B experiment. This workstation has no
  compatible C compiler, so only Wasm-GC has been checked locally.
  MoonBit's native debug and release configurations may select different
  compiler backends; therefore `backend: native` identifies MoonBit's target,
  not a guarantee of identical internal lowering. See the
  [MoonBit native backend note](https://docs.moonbitlang.com/next/language/ffi.html).
- For a same-runner version comparison, manually trigger
  [Issue 1322 Toolchain Comparison](../.github/workflows/issue-1322-toolchain-comparison.yml)
  with the desired dated release identifiers. Each Linux or Windows job
  installs the baseline and candidate versions sequentially, runs this same
  regression script, and uploads the two raw JSON reports plus a compact
  comparison summary. This controls the runner instance and source revision
  within each platform better than comparing runs from different dates, but it
  does not pin the hosted image or every dependency; a changed result is still
  not, by itself, proof of the compiler root cause.
- The older run [37988791461](https://github.com/Yingqingxue/moonsmith/actions/runs/37988791461)
  passed both Linux and Windows jobs with the generic verifier included:
  Linux classified native debug as `compile-failed`; Windows classified it as
  `succeeded`. These results are now interpreted as observations under the
  older MoonBit toolchain, not as a persistent Linux/Windows difference. The
  newer run above supersedes the old platform conclusion, but does not identify
  why behavior changed.
- The script also sends the checked-in source and the upstream-reported
  expected output to `verify_seed.ps1`, exercising MoonSmith's existing
  differential classification and persisting its per-target status in the
  evidence JSON. That expected value is supplied by the upstream reproducer;
  this fixture does not invoke MoonSmith's AST reference evaluator.
- Scope: this is an upstream-reported unsupported lowering path, not a
  MoonSmith-discovered defect and not necessarily a language-contract violation.
  It tests whether the toolchain fails internally instead of issuing a normal
  diagnostic while preserving release and Wasm-GC as controls.

Reproduce the control path from the repository root:

```powershell
moon run regressions/issue_1322_native_valtype_enum_array/repro.mbt --target wasm-gc
```

With a compatible C compiler, run
`pwsh -File scripts/test_issue_1322.ps1` to capture native debug/release results.

## Case 4: JS link-core ICE for cross-package generic trait identity

- Upstream report: [moonbitlang/moonbit-docs#1133](https://github.com/moonbitlang/moonbit-docs/issues/1133)
- Narrowed reproducer: [upstream comment with the standalone four-file case](https://github.com/moonbitlang/moonbit-docs/issues/1133#issuecomment-3904217755).
- Reported symptom: JS `link-core` raised `Key_not_found` when a cross-package
  call reached a generic helper using a trait implemented for `Array[T]` with
  `= "%identity"`, while the exported function accepted an optional
  `Array[Int]` argument. The issue report says `moon check` passed and the ICE
  occurred during JS linking. A follow-up narrowed the trigger and says the
  minimized case was independently reproduced by an upstream maintainer and
  fixed on nightly. The checked-in fixture follows that narrowed case: it uses
  `Int` as the identity result and omits the `#external`/FFI wrapper, which the
  follow-up identifies as unnecessary for reproducing the linker failure.
- Local fixture: the standalone module at
  `regressions/issue_1133_js_link_core_trait_identity/` with `lib` and `main`
  packages.
- Current validation: MoonBit `0.1.20260920`, `moonc
  v0.10.14+7d59c7ec9`; JS-targeted `moon check` and `moon run` both pass.
- Target scope: the fixture is an independent MoonBit module with
  `supported_targets = "js"`. The historical `%identity` pattern is
  JS-linker-specific and is not a valid cross-backend semantic test; the module
  boundary keeps it out of the primary project's other backend test discovery.
- Scope: this is a standalone compiler-linker regression fixture, not syntax
  currently emitted by MoonSmith's generator. It does not exercise MoonSmith's
  reference evaluator, differential verifier, or reducer, and it is not a
  MoonSmith-discovered issue. The identity implementation is target-specific;
  do not run this fixture on Wasm-GC as a cross-backend control. Supporting the
  pattern in generated programs would require modeling generic traits and
  cross-package linking, far beyond the current generator grammar.

Reproduce from the repository root:

```powershell
moon -C regressions/issue_1133_js_link_core_trait_identity check --target js --deny-warn main
moon -C regressions/issue_1133_js_link_core_trait_identity run --target js --deny-warn main
```

## Candidate not yet included

[moonbitlang/moonbit-docs#1272](https://github.com/moonbitlang/moonbit-docs/issues/1272)
reports a Wasm `moon check` ICE on macOS arm64 with MoonBit `0.1.20260618` /
`moonc v0.10.1`; the reporter could not reduce the linked project, and an
upstream maintainer suggested keeping files below 16,383 lines as a workaround.
This is relevant context for MoonSmith's conservative 16,300-line generated-
source guard, but it is not a regression fixture: the available project is not
a small self-contained reproducer, the issue predates the current toolchain,
and current behavior on the reported platform has not been checked. Do not
present the guard or this historical report as a MoonSmith discovery.

[moonbitlang/core#1594](https://github.com/moonbitlang/core/issues/1594) reported
undefined-behavior-sanitizer findings in generated C for signed integer
overflow in the native backend; GitHub's issue API reports it closed since
2025-02-11. The linked reproducer is a full third-party project, not a small
self-contained source fixture; the report concerns native runtime semantics
and does not directly match MoonSmith's current JS/wasm/wasm-gc matrix. It is
not included as a regression because its source, license, exact toolchain,
sanitizer setup, and current reproduction status have not been audited. It is
not a MoonSmith-discovered bug.

Additional candidates reviewed on 2026-10-12:

- [moonbitlang/moonbit-docs#1123](https://github.com/moonbitlang/moonbit-docs/issues/1123)
  reports invalid Wasm-GC validation when `#external` values flow through
  trait-object/supertrait casts. The report explicitly says the standalone
  minimal source may not trigger reliably; the required external types,
  trait-object conversion, and imports are outside the current generator. The
  linked [compiler PR #6](https://github.com/moonbitlang/moonbit-compiler/pull/6)
  describes the corresponding cast fix, but is still open in the reviewed
  snapshot. Not added: no stable small reproducer or verified current-toolchain
  outcome, and it cannot enter the generated differential pipeline.
- [moonbitlang/moonbit-docs#1289](https://github.com/moonbitlang/moonbit-docs/issues/1289)
  reports a native link ICE while building a 31,323,407-byte whitebox-test
  core. The author's standalone attempts with 30,000 functions and 1,000
  layouts did not reproduce it. Not added: the only verified trigger depends
  on a large third-party test project, and the issue says a single selected
  test still builds that package-wide core. This is not a valid small fixture;
  current-toolchain status is also unverified.
- [moonbitlang/moonbit-docs#1292](https://github.com/moonbitlang/moonbit-docs/issues/1292)
  reports that an `implicit_impl_as_method` warning's suggested `pub extend`
  fix can be invalid for tuple types or use a package name not in scope. The
  report's reproduction is enabling a warning in `moonbitlang/core`, not a
  self-contained case in MoonSmith's generated expression language. Not added
  to this backend-regression corpus: it is a diagnostic/actionability issue
  and would need a separate warning/fix-it test harness plus a current
  toolchain reproduction.

## What this corpus can and cannot show

The included case tests whether a known historical compiler-tooling failure
still reproduces. It does not measure issue-detection recall, current compiler
quality, or comparative fuzzing effectiveness. Add further cases only with a
stable upstream source, a small redistributable fixture or reproducible fetch
procedure, exact expected behavior, and a current-toolchain result.
