# Implementation status

Last updated: 2026-10-09

Current developer and project owner: `Yingqingxue`. Development is currently
single-person; no second team member is recorded.

## Verified today

- MoonBit toolchain: `moon 0.1.20260920 (914d7da 2026-09-20)`.
- The library and tests compile without warnings.
- Sixty-seven main-package tests pass on each of `js`, `wasm`, and `wasm-gc`;
  reference, reducer, and CLI integration scripts also pass after the added
  report/JSON and variable-scope cases.
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
- A probe-scoped injected mismatch was replayed and reduced across all three
  backends in CI: 5 accepted steps in 10 attempts, complexity 39,300 → 18,133,
  with the trigger scaffold retained. A separate 100-budget local run accepted
  15 steps in 84 attempts, reduced bytes 2,376 → 1,367 and complexity
  39,300 → 11,014, then exhausted the current candidate set without hitting
  its budget. Final reduction key was revalidated; this is not a global-minimum
  guarantee or a real compiler bug.

## Native backend status and local environment limitation

The `native` target cannot be tested on this workstation because no system C
compiler (`cc`, `gcc`, or `clang`) is installed. It is now validated remotely:
GitHub Actions run `37967094871` for commit `0cfac5a` passed both
`moon test --target native --deny-warn` and a deterministic seed-0/depth-4
generate/reference/native differential execution. This is one native smoke
case plus the package test suite, not the 1,245-case scan; local native replay
still requires an appropriate C toolchain.

## Current vertical slice

```text
seed + depth -> typed Expr -> MoonBit source -> three target executions
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
expression bodies from the first 100 seeds. A GitHub Actions workflow has
been added for static checks, the three backend test suites, integration
tests, and a 10-seed smoke scan. It has only been checked locally; no remote
GitHub CI run is available yet because this checkout has no commit or remote.

## Unified host CLI

`scripts/moonsmith.ps1` now exposes `doctor`, `fuzz`, `replay`, `reduce`, and
`report`.
`doctor` executes a small real backend probe; `fuzz` delegates to the stable
batch runner; `replay` rechecks a saved finding against its original finding
kind and reduction key; `reduce` runs the generated-seed reducer. A CLI
integration test validates `doctor`, a two-seed batch, and an explicitly
injected saved-case replay. This is a PowerShell host adapter, not yet a
standalone native MoonBit executable. HTML case reports and arbitrary-source
reduction remain unfinished.

## Markdown finding report

The host CLI now renders a saved finding and optional matching reduction as
`report.md`. It includes the source hash, toolchain and host metadata for new
cases, per-backend status/output/diagnostics, reference output, reduction
metrics, and a replay command. Reports explicitly mark injected demonstrations
and environment failures as non-defects; real findings are labelled
unconfirmed candidates. Source hashes, reduction identity, and equality of
the reduction's original source with the saved canonical case are checked
before rendering. The CLI integration test exercises this path. Existing
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
real MoonBit compiler defect was found.

## Ecosystem comparison baseline

A source-based comparison of Csmith, YARPGen, C-Reduce, and MoonBit QuickCheck
is recorded in `docs/ecosystem_comparison.md`. It distinguishes the current
MoonSmith implementation from unverified claims: the tool has a MoonBit-targeted
typed generator, reference evaluator, three-backend comparison, and generated-AST
reducer, but no proven real compiler bug, arbitrary-source reducer, or
optimizer-directed generator. This is desk research, not an external review or
a comparative effectiveness experiment. The next validation gap is a larger
redistributable set of previously reported MoonBit compiler regressions and an
external scope review. One minimal coverage-tool ICE regression from
`moonbitlang/moonbit-docs#1071` and one reported Wasm backend regression from
`moonbitlang/moonbit-docs#1274` are now included; both pass under the current
toolchain. See `docs/regressions.md`. The Wasm issue remains open upstream, and
neither case was discovered by MoonSmith or estimates detection recall.
