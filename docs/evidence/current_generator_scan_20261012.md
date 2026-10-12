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

# Fresh follow-up scans

The manual `MoonSmith CI` workflow accepts `scan_start` for a new 230-seed
Linux batch (depth 4: 100; depth 6: 100; depth 8: 30). After recording the
13000–13229 scan below, the next default start is 13300; the workflow rejects
smaller values to avoid the documented samples. To compare Windows
native-release against a completed Linux range, set
`extended_windows_crosscheck` and select that range's start. Each batch needs
its own run/artifact link; seed volume alone is not a measured defect-finding
rate.

Additional scan (2026-10-12 UTC): [manual CI run 38274803979](https://github.com/Yingqingxue/moonsmith/actions/runs/38274803979), source commit `4fdfd52`, used the default fresh range starting at 13000. The extended scan and Linux verification jobs passed. The artifact's three reports shared toolchain `moon 0.1.20261012 (748b63c 2026-10-12)` and the same harness digest at start and end (`a08ed04fe0597aa6e1e3b8f97fa6e39c27eb39eb68cf551beea6f6714db762e0`).

| Seeds | Depth | Targets | Program bodies | Backend executions | Consistent | Unexpected | Generator limits | Max source lines |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| 13000–13099 | 4 | JS, Wasm, Wasm-GC | 100 | 300 | 100 | 0 | 0 | 174 |
| 13100–13199 | 6 | JS, Wasm, Wasm-GC | 100 | 300 | 100 | 0 | 0 | 648 |
| 13200–13229 | 8 | JS, Wasm, Wasm-GC | 30 | 90 | 30 | 0 | 0 | 1,654 |
| **Total** | — | **three backends** | **230** | **690** | **230** | **0** | **0** | **1,654** |

Across the 230 reports there were 186 reference visits to the array-growth
push and 186 visits to the post-growth indexed read; the `#valtype`/raise
probe's success and error paths were each visited 88 times. These are
reference-interpreter path observations, not backend runtime coverage. This
sample is reported separately from the earlier fixed scan; no combined
cross-run body-hash deduplication is claimed here. It found no new compiler
defect.

Windows same-seed cross-check (2026-10-12 UTC): [manual CI run 38276715973](https://github.com/Yingqingxue/moonsmith/actions/runs/38276715973), source commit `eb7c59a`, ran the same 230 seeds at depths 4, 6, and 8 on Windows `native-release`. All 230 checks were consistent, with zero unexpected findings, generator limits, or harness errors. The three Windows reports shared MoonBit `0.1.20261012 (748b63c)` and an unchanged Windows harness digest (`d6866c1ad10ebfc3bae7cedcccd64b04a6d3cf5b0660a9bdb28128e5f9bbd1dc`).

I compared the per-seed report `bodySha256` values with Linux run 38274803979: all 230 seeds had matching hashes and consistent findings on both platforms. The 230 Linux inputs were also pairwise distinct by body hash. Together these runs cover 230 distinct generated bodies and 920 backend executions (JS, Wasm, Wasm-GC, and Windows native-release per body), all consistent. This is a bounded sample, not proof of language-wide equivalence; native-debug is intentionally excluded because upstream issue #1322 has a known native-debug ICE. The Windows C compiler file version was not recorded in this run; later CI now emits the `cl.exe` file/product versions so future reports can state it explicitly.
