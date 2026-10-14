# Source-size-matched semantic-selection replication (2026-10-14)

This is the preregistered cohort described in
[`semantic_selection_replication_preregistration_20261014.md`](semantic_selection_replication_preregistration_20261014.md).
GitHub Actions run [38540175723](https://github.com/Yingqingxue/moonsmith/actions/runs/38540175723)
completed successfully on commit `bd1541257ca51acfee27aa3cd41e6cead256fc4e`.
The workflow's Linux `verify`, Windows `windows-native`, and experiment jobs
all passed. The raw report is retained in the
`moonsmith-semantic-selection-replication` artifact.

| Arm | Programs | Backend executions | Distinct reference paths | Mean source lines | Arm time |
| --- | ---: | ---: | ---: | ---: | ---: |
| Sequential control | 20 | 60 | 51 | 98.6 | 11.6 s |
| Semantic-guided | 20 | 60 | 55 | 100.8 | 11.4 s |

Both arms contained 20 unique program bodies, had zero unavailable backends,
and were consistent in all 40 cases. Their generated-source size quartiles
matched exactly (9, 6, 4, and 1 selected cases in quartiles 0–3); the arms
shared four seeds. The 100-candidate pool contained 55 distinct reference
path kinds, all represented by the guided arm. Prescreening took 11.8 s.

The runner recorded MoonBit `0.1.20261012 (748b63c 2026-10-12)`, matching the
previous registered cohort's toolchain. The current report's harness digest
was unchanged during the run. Since the repository gained a dedicated FMA AST
profile between cohorts, the harness digest is not identical to the earlier
cohort; that profile is a separate deterministic mode and does not alter the
ordinary seeded generator. This is evidence for the current selector on a
second fixed seed cohort, not a controlled estimate of compiler-internal
coverage or bug-finding probability.

Across the two registered size-matched cohorts, the guided arm represented 53
versus 52 path kinds in the first cohort and 55 versus 51 in this cohort. These
are descriptive outcomes from two finite, deterministic cohorts—not a
statistical significance claim. No unexpected compiler finding occurred. The
result supports only a bounded reference-path diversity observation; the
additional 100-candidate prescreen cost remains relevant to practical value.
