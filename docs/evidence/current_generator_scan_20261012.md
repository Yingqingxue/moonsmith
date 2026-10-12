# Current-generator fixed-seed scan

Date: 2026-10-12 (UTC, GitHub-hosted runner)  
Source commit: `5bc6eec`  
Toolchain: `moon 0.1.20261012 (748b63c 2026-10-12)`  
Harness digest: `a08ed04fe0597aa6e1e3b8f97fa6e39c27eb39eb68cf551beea6f6714db762e0`
at the start and end of all three batches.  
Workflow: [GitHub Actions run 38246227150](https://github.com/Yingqingxue/moonsmith/actions/runs/38246227150), job `extended-seed-scan`. Raw JSON reports are retained in the `moonsmith-current-generator-seed-scan` artifact for 30 days.

This scan uses the current generator, including the composed `#valtype`/raise
probe and its empty-array, two-push, and post-growth indexed-read paths. It is a
bounded regression/consistency sample, not a claim of exhaustive correctness or
a compiler-bug discovery rate.

| Seeds | Depth | Bodies | Reference checks | JS/Wasm/Wasm-GC executions | Consistent | Size limits | Max source lines | Array probe visited by reference | Raise probe in source / visited | Both probe paths visited |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10000–10099 | 4 | 100 | 100 | 300 | 100 | 0 | 166 | 58 | 41 / 31 | 19 |
| 11000–11099 | 6 | 100 | 100 | 300 | 100 | 0 | 639 | 93 | 88 / 63 | 57 |
| 12000–12029 | 8 | 30 | 30 | 90 | 30 | 0 | 2,347 | 30 | 30 / 29 | 29 |
| **Total** | — | **230 unique** | **230** | **690** | **230** | **0** | **2,347** | **181** | **159 / 123** | **105** |

All three reports had zero unexpected findings, zero generator limits, and
`harnessChangedDuringRun = false`. The three disjoint seed ranges produced 230
distinct source-body hashes. The aggregate reference trace visited the
`#valtype`/raise success path in 86 cases and its error path in 74 cases; a case
may visit both, so these are not mutually exclusive totals. The enum-array
probe's trace records 181 cases visiting its modeled path. These counts come
from MoonSmith's reference evaluator; they are not instrumentation of execution
inside the backends.

Each batch took about 56 seconds (depth 4: 56,436 ms; depth 6: 56,354 ms; depth
8: 20,052 ms). Its raw report IDs are `20261012_120016_093`,
`20261012_120112_615`, and `20261012_120209_024` respectively.

The scan exercised only JS, Wasm, and Wasm-GC. Native release is scanned
separately on Windows CI; native debug is not part of these batches because the
known upstream-reported #1322 ICE is checked by its dedicated regression. No
MoonSmith-discovered compiler defect is claimed from this scan.
