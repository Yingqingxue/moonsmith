# Bounded array alias-update evidence (2026-10-14)

MoonSmith now generates a two-element `Array[Int]` or `Array[Bool]`, binds a
second reference to it, writes a generated replacement through that alias,
and reads the selected element through the original binding. Generated code
also checks that the other element was not changed. The reference interpreter
models the expected replacement and records the selected index. The AST
reducer can shrink all three child expressions while retaining this scaffold.
The slice is bounded: it does not generate arbitrary indices, removals,
multi-array alias graphs, or general mutable-array programs.

Local MoonBit tests passed on JS, Wasm, and Wasm-GC (98 tests per target).
The reference/reducer/CLI integration suites passed. In an explicitly
injected wasm-gc output-mismatch demonstration, reduction kept the alias
write/read trigger while lowering complexity from 17,133 to 2,032 in four
accepted steps. This is **not** a compiler finding.

Two fixed-seed nightly runs used seeds 14990–15989, depth 4, and MoonBit
`0.1.20261012 (748b63c 2026-10-12)`:

| Reference/source metric | Initial `340491e` | Balanced `d3a3fa8` |
| --- | ---: | ---: |
| Distinct bodies / reference checks | 1,000 / 1,000 | 1,000 / 1,000 |
| Sources containing alias updates | 656 | 656 |
| Reference cases visiting updated index 0 | 187 | 374 |
| Reference cases visiting updated index 1 | 402 | 251 |
| Unexpected findings / generator limits | 0 / 0 | 0 / 0 |

The initial [nightly run 38483200825](https://github.com/Yingqingxue/moonsmith/actions/runs/38483200825)
passed but revealed a roughly 1:2.15 index skew. A separate child-seed
stream now chooses the alias-update index. The balanced
[nightly run 38486812310](https://github.com/Yingqingxue/moonsmith/actions/runs/38486812310)
passed the stricter gate: each index appeared in at least 2% of the corpus,
neither index had more than twice the other's case count, and aggregate source
and reference-path totals matched the per-case records. The index-selection
change altered 469 per-seed source hashes. Its downloaded JSON report had
1,000 consistent cases across the configured JS/Wasm/Wasm-GC targets and an
unchanged harness digest.

The corresponding [CI run 38486796867](https://github.com/Yingqingxue/moonsmith/actions/runs/38486796867)
passed Linux and Windows jobs. Its Windows native-release artifact separately
recorded 100/100 consistent cases for seeds 9000–9099 at depth 6 (98 sources
contained alias updates; reference paths visited index 0 in 75 cases and
index 1 in 69), and 30/30 consistent cases for seeds 9200–9229 at depth 8
(30 alias-update sources; each index path appeared in 30 cases). These are
different seed/depth cohorts from the Linux nightly; they are **not** a
per-seed cross-platform hash comparison.

All path figures are reference-interpreter case counts, not compiler-backend
coverage instrumentation. The finite samples do not prove general compiler
correctness or bug-finding effectiveness. The historical upstream #1322
issue was not discovered by MoonSmith.
