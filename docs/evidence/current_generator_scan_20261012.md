# Current-generator fixed-seed scan

Date: 2026-10-12 (UTC, GitHub-hosted runner)  
Source commit: `5bc6eec`  
Toolchain: `moon 0.1.20261012 (748b63c 2026-10-12)`  
The Linux batches shared harness digest
`a08ed04fe0597aa6e1e3b8f97fa6e39c27eb39eb68cf551beea6f6714db762e0`; the
Windows batches shared
`d6866c1ad10ebfc3bae7cedcccd64b04a6d3cf5b0660a9bdb28128e5f9bbd1dc`. Each
digest was unchanged at the start and end of its batches.

Workflows: [GitHub Actions run 38246227150](https://github.com/Yingqingxue/moonsmith/actions/runs/38246227150) and [follow-up CI run 38247014970](https://github.com/Yingqingxue/moonsmith/actions/runs/38247014970), both fully successful. Linux raw JSON reports are in the `moonsmith-current-generator-seed-scan` artifact; Windows reports are in `moonsmith-windows-native-report`. Both artifacts are retained for 30 days.

This scan uses the current generator, including the composed `#valtype`/raise
probe and its empty-array, two-push, and post-growth indexed-read paths. It is a
bounded regression/consistency sample, not a claim of exhaustive correctness or
a compiler-bug discovery rate.

| Seeds | Depth | Target configuration | Bodies | Reference checks | Backend executions | Consistent | Size limits | Max source lines | Array probe visited by reference | Raise probe in source / visited | Both probe paths visited |
|---|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 10000–10099 | 4 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 100 | 0 | 166 | 58 | 41 / 31 | 19 |
| 11000–11099 | 6 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 100 | 0 | 639 | 93 | 88 / 63 | 57 |
| 12000–12029 | 8 | JS, Wasm, Wasm-GC | 30 | 30 | 90 | 30 | 0 | 2,347 | 30 | 30 / 29 | 29 |
| 9000–9099 | 6 | Windows native-release | 100 | 100 | 100 | 100 | 0 | 584 | 98 | 89 / 67 | 66 |
| 9200–9229 | 8 | Windows native-release | 30 | 30 | 30 | 30 | 0 | 2,680 | 30 | 30 / 30 | 30 |
| **Total** | — | **separate configurations** | **360 unique** | **360** | **820** | **360** | **0** | **2,680** | **309** | **278 / 220** | **201** |

All five reports had zero unexpected findings, zero generator limits, and
`harnessChangedDuringRun = false`. The five disjoint seed ranges produced 360
distinct source-body hashes. There were 690 executions across JS/Wasm/Wasm-GC
and 130 separate Windows native-release executions. Each generated body had one
reference check in its batch. The aggregate reference trace visited
the `#valtype`/raise success path in 155 cases and its error path in 138 cases;
a case may visit both, so these are not mutually exclusive totals. The enum-
array probe's trace records 309 cases visiting its modeled path. These counts
come from MoonSmith's reference evaluator; they are not instrumentation of
execution inside the backends.

Linux batch durations were depth 4: 56,436 ms; depth 6: 56,354 ms; and depth
8: 20,052 ms. Windows native-release batch durations were depth 6: 184,221 ms
and depth 8: 62,848 ms. Raw report IDs are `20261012_120016_093`,
`20261012_120112_615`, `20261012_120209_024`, `20261012_120053_744`, and
`20261012_120358_122` respectively.

Native debug is not part of these generated batches because the known
upstream-reported #1322 ICE is checked by its dedicated regression. The two
Windows batches exercised only native-release; they do not establish Windows
native-debug consistency for the generated growth probe. No MoonSmith-discovered
compiler defect is claimed from this scan.
