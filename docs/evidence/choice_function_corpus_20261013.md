# Choice-returning function corpus check (2026-10-13)

The `Choice`-returning local-function generator extension was checked in
[GitHub Actions run 38303300833](https://github.com/Yingqingxue/moonsmith/actions/runs/38303300833)
on commit `dd55868585cade86222ca2dcc4882990bc70952d`. The run used MoonBit
`0.1.20261012 (748b63c 2026-10-12)` and seeds 14990–15989 at depth 4.

## Results

- 1,000 distinct source bodies were checked against the reference evaluator and
  executed on JS, Wasm, and Wasm-GC (3,000 backend executions).
- All 1,000 were consistent; there were no unexpected findings, generator
  limits, or harness errors.
- The batch report recorded 402 cases with the `#valtype`/raise probe, 234 with
  the direct raise/enum-array composition, and 198 whose reference trace visited
  both probe kinds. The trace also visited 164 raise-success and 142
  raise-error paths. These are generator/source and reference-evaluator
  observations, not backend runtime coverage.
- Compared with the immediately preceding 1,000-seed run
  [38294697813](https://github.com/Yingqingxue/moonsmith/actions/runs/38294697813),
  which used the same seed range, depth, and toolchain, 251 body hashes changed.
  The batch's generic local-function count increased by 305 while its old
  `functionInt` and `functionBool` counts were unchanged. The code change only
  adds conditional `Choice`-returning local functions at generated choice
  inputs; spot checks confirmed the new `fn(q...)` shape in changed seed 14990
  and its absence in unchanged seed 14991. Thus the comparison shows the new
  branch is exercised, including multiple such functions in some bodies.
- Seed 4 at depth 4 was independently verified across JS, Wasm, and Wasm-GC;
  its generated source contains a `Choice`-returning local function. A
  source-triggered injected output mismatch on that seed reduced from
  complexity 24,167 to 7,007 in 20 attempts, accepting 7 steps while retaining
  the trigger. This is reducer validation, not evidence of a compiler bug.
- Cross-platform native-release coverage is also green: CI run
  [38302194136](https://github.com/Yingqingxue/moonsmith/actions/runs/38302194136)
  includes seed 4 in its Linux native-release seeds 0–9 batch, and
  [38304756522](https://github.com/Yingqingxue/moonsmith/actions/runs/38304756522)
  explicitly verified seed 4 at depth 4 on Windows/MSVC native-release. The
  latter run passed both Linux and Windows jobs. This workstation still lacks a
  compatible C compiler, so native is verified remotely, not locally.

The uploaded artifact `moonsmith-nightly-generator-corpus-38303300833` contains
the JSON report and standalone HTML report. The HTML is 231,300 bytes, has five
tables and 1,081 rows, and contains no `<script>` or `<img>` tags. Both reports
span seeds 14990–15989. This check is Linux-only and makes no native-backend
claim.

## Follow-up telemetry gate

The batch-report schema is now version 8 and records
`casesWithChoiceReturningFunction` and `choiceReturningFunctionCount` directly,
in addition to per-case `sourceConstructCounts.functionChoice`. The nightly
summary validator now requires both aggregate metrics to be nonzero, preventing
a future 1,000-seed run from passing while silently missing this newly added
generator branch. It also recomputes the number of affected cases and total
functions from all per-case source metrics and rejects aggregate mismatches.
The report fixture checks missing/zero coverage and both mismatch modes. The
first schema-8 run below confirms the gate against the full corpus; the
preceding measurements above are from schema 7.
The HTML renderer and cross-platform report comparer continue to accept schema
7 as well as schema 8, so previously saved batch reports remain usable.

The refreshed schema-8 run completed successfully in
[GitHub Actions run 38307212651](https://github.com/Yingqingxue/moonsmith/actions/runs/38307212651)
on commit `f81c3c9067e7dbba21f457c50e4012c08d4ccd97`. It again checked 1,000
unique bodies and 3,000 JS/Wasm/Wasm-GC executions with no unexpected findings,
generator limits, or harness errors. The new direct metric recorded 251 cases
containing Choice-returning local functions and 305 such functions in total.
The corpus also recorded 234 direct raise/enum-array compositions, 198 cases
whose reference trace visited both probe kinds, and 164/142 raise-success/error
paths. These are source/reference observations, not backend runtime coverage.
The uploaded schema-8 JSON and HTML span seeds 14990–15989; the HTML is 231,391
bytes and contains no `<script>` or `<img>` tags.

After strengthening the validator to reconcile the aggregate metrics with all
1,000 per-case records, the same nightly passed again on commit `4dd7768` in
[run 38347193204](https://github.com/Yingqingxue/moonsmith/actions/runs/38347193204).
The preserved JSON was downloaded and independently revalidated with the new
per-case reconciliation; the counts remained 251 cases and 305 functions,
with 1,000/1,000 consistent results and zero generator limits or harness
errors.
