# Bounded array alias-update evidence (2026-10-14)

MoonSmith now generates a two-element `Array[Int]` or `Array[Bool]`, binds a
second reference to it, writes a generated replacement through that alias,
and reads the selected element through the original binding. Generated code
also checks that the other element was not changed. The reference interpreter
models the expected replacement and records the selected index. The AST
reducer can shrink all three child expressions while retaining this scaffold.
The slice is bounded: it does not generate arbitrary indices, removals,
multi-array alias graphs, or general mutable-array programs.

The measurements below apply to commits before the later no-op candidate
guard. That guard substitutes a distinct value when the generated replacement
equals the selected old value; its tests and remote corpus must be assessed
separately rather than attributing these counts to it.

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

A later [paired CI run 38488243292](https://github.com/Yingqingxue/moonsmith/actions/runs/38488243292)
at source commit `d3a3fa8` used fresh seeds 23000–23229: 100 at depth 4,
100 at depth 6, and 30 at depth 8. Linux ran JS/Wasm/Wasm-GC and Windows ran
native-release on the *same* 230 seeds. All five workflow jobs passed. The
comparison artifact records 230/230 matching source hashes, 230/230 matching
reference outputs, and 230/230 cases consistent on both platforms (690 Linux
and 230 Windows backend executions). All 230 generated bodies were distinct.
Both platform reports recorded 191 sources containing alias updates and 173
reference cases visiting an alias update; index 0 was visited in 149 cases
and index 1 in 120. Each platform checked all 230 reference cases and reported
zero unexpected findings. This establishes parity for this bounded sample,
not for every possible generated program or compiler version.

All path figures are reference-interpreter case counts, not compiler-backend
coverage instrumentation. The finite samples do not prove general compiler
correctness or bug-finding effectiveness. The historical upstream #1322
issue was not discovered by MoonSmith.

## Equal-candidate observability guard

Commit `8b5796a` closes a blind spot in the earlier probe: if a generated
replacement equaled the selected old element, omitting the alias write could
still satisfy the check. The source and reference evaluator now substitute a
different `Int` or `Bool` value in that case. A dedicated trace event records
when the fallback is used. Hand-built unit cases cover zero/nonzero integers
and booleans, while generated seed 23002 exercises a fallback through the
compiled JS/Wasm/Wasm-GC pipeline.

Locally, 99 MoonBit tests passed on each of those three targets; reference,
reducer, CLI, and batch-report integration suites passed. A 20-seed depth-4
sample (23000–23019) produced 20 distinct bodies, 20 reference checks, 60
consistent backend executions, 11 sources with alias updates, two reference
cases visiting the equal-candidate fallback, and zero unexpected findings.
This local toolchain was `0.1.20260920`; it is not the same toolchain as the
earlier Actions measurements.

The stronger guard adds generated lines. In the local CLI size-limit test,
seed 8164 at depth 10 now has 16,346 lines and correctly reaches the 16,300-line
generator limit; seed 8165 remains below it at 15,958 lines and executes
consistently on Wasm. These two seeds do not estimate a general size-limit
rate. The previous 1,000- and 230-seed measurements above predate this guard.

In the
[paired rerun 38503810364](https://github.com/Yingqingxue/moonsmith/actions/runs/38503810364),
the same 230 seeds produced 230 distinct bodies, 230 reference checks, and
230 consistent cases on Linux JS/Wasm/Wasm-GC (690 configured executions).
There were 191 alias-update source cases and 83 reference cases visiting the
equal-candidate fallback; the three depth cohorts contributed 14, 41, and 28
fallback cases. Exactly 191 of the 230 source hashes changed from the earlier
`d3a3fa8` paired run, matching the number of sources containing an alias
update. The harness digest was unchanged during all three reports, and no
unexpected findings or generator limits were recorded. Windows native-release
ran the same seeds on the same toolchain and recorded the same alias and
fallback case counts. All five workflow jobs passed. The comparison artifact
records 230/230 matching source hashes, 230/230 matching expected outputs,
and 230/230 consistent cases on both platforms (920 configured backend
executions in total). This is same-seed cross-platform evidence for the new
guard, not a claim that outputs stayed identical across the old and new
generator versions.

The new [fixed-seed nightly run 38503792844](https://github.com/Yingqingxue/moonsmith/actions/runs/38503792844)
also passed: 1,000 distinct bodies, 1,000 reference checks, 1,000 consistent
cases across JS/Wasm/Wasm-GC (3,000 configured executions), 656 alias-update
source cases, and 131 reference cases visiting the fallback. Index 0 was
visited in 373 cases and index 1 in 250; the nightly balance gate passed.
The harness digest stayed unchanged and no unexpected findings or generator
limits were reported. The separate
[CI run 38503757215](https://github.com/Yingqingxue/moonsmith/actions/runs/38503757215)
passed Linux verification and Windows native checks. Its fixed Windows
native-release cohorts had 100/100 consistent depth-6 cases (42 fallback
paths) and 30/30 consistent depth-8 cases (28 fallback paths). These are
additional samples, not proof of general correctness or a newly discovered
compiler defect.
