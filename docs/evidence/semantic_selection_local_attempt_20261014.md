# Local semantic-selection cohort attempt (2026-10-14)

This records the first execution of the preregistered 24220–24319 cohort on the
developer workstation. It is reported separately from the planned hosted-runner
replication because its toolchain differs from the preceding registered cohort.

| Metric | Sequential control | Semantic-guided |
| --- | ---: | ---: |
| Selected programs | 20 | 20 |
| Backend executions (`js`, `wasm`, `wasm-gc`) | 60 | 60 |
| Distinct reference-interpreter path kinds | 51 | 55 |
| Unique program bodies | 20 | 20 |
| Mean generated source lines | 98.6 | 100.8 |
| Arm duration | 119.2 s | 119.6 s |

The 100-candidate prescreen took 91.1 s. Both arms were consistent in all
40 selected cases; there were no unexpected findings. Source-size quartile
quotas matched (9, 6, 4, 1 cases from quartiles 0–3), and the arms shared four
seeds.

The report recorded MoonBit `0.1.20260920 (914d7da 2026-09-20)`, whereas the
preceding registered cohort used MoonBit `0.1.20261012 (748b63c 2026-10-12)`.
The harness digest was unchanged during this run, but the checkout was dirty
because the new preregistration and workflow integration were not committed
yet. Accordingly, these are local exploratory results under a different
toolchain, not a clean same-toolchain replication or a compiler-defect finding.
The primary within-run comparison remains descriptive: four more reference
path kinds for semantic guidance at the same selected-case, backend-execution,
and source-size-quartile budgets. This does not establish a practical bug-
finding advantage. The ignored raw JSON is at
`.moonsmith/runs/selection_24220_100_20_d4_size_matched.json` on the local
workstation.
