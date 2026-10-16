# Hosted source-size-matched semantic-selection replication — 2026-10-16

This report records the preregistered 2026-10-14 cohort on a clean GitHub
runner. The design was fixed before inspecting this cohort in
[`semantic_selection_replication_preregistration_20261014.md`](semantic_selection_replication_preregistration_20261014.md).
The workflow run is [38873580951](https://github.com/Yingqingxue/moonsmith/actions/runs/38873580951).
Its artifact was downloaded locally to the ignored
`.moonsmith/runs/hosted_38873580951/selection_24220_100_20_d4_size_matched.json`.

The artifact reports MoonBit `0.1.20261012 (748b63c 2026-10-12)`, clean
commit `a1ef743c0fa41489438f21b13c9c356de40d8e36`, matching start/end harness
digests, and no harness changes during the run. It selected 20 programs per
arm from candidate seeds 24220–24319 at depth 4 and used the same `js`, `wasm`,
and `wasm-gc` matrix in each arm.

| Arm | Selected programs | Backend executions | Distinct reference paths | Unique bodies | Mean source lines | Arm time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sequential | 20 | 60 | 51 | 20 | 98.6 | 11.6 s |
| Size-matched semantic-guided | 20 | 60 | 55 | 20 | 100.8 | 11.4 s |

Both arms were consistent in all 20 cases, with no unexpected findings or
unavailable backends. The source-size quartile counts matched exactly
(`9, 6, 4, 1` in quartiles 0–3). The selected arms shared four seeds. The
100-candidate reference-evaluator prescreen took 11.7 s, so the additional
selection cost was about 11.7 s for this run; the backend execution budget was
equal, but the end-to-end workflow was not cost-free. The guided arm visited
four more reference-interpreter path kinds in this cohort.

This is one descriptive replication, not a powered comparison. The prior
registered cohort used another MoonBit toolchain version and is not pooled
with this result. Reference-interpreter paths are not compiler-internal
coverage; these data do not establish improved bug-finding probability or a
MoonSmith-discovered compiler bug. Keep semantic guidance optional until
additional preregistered cohorts show that its added cost is worthwhile.
