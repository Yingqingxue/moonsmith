# Second hosted semantic-selection cohort — 2026-10-16

This is the second, non-overlapping descriptive cohort, run according to
[`semantic_selection_replication2_preregistration_20261016.md`](semantic_selection_replication2_preregistration_20261016.md)
on [GitHub Actions run 38876082331](https://github.com/Yingqingxue/moonsmith/actions/runs/38876082331).
The full workflow completed successfully, including the Linux verify,
Windows-native, and semantic-selection jobs. Its artifact is preserved
locally, in the ignored
`.moonsmith/runs/hosted_38876082331/selection_24320_100_20_d4_size_matched.json`.

The artifact records MoonBit `0.1.20261012 (748b63c 2026-10-12)`, clean commit
`10ae6aa44c8df3337d6c28b4c18deecf06428b6a`, an unchanged start/end harness
digest, 100 candidate seeds 24320–24419 at depth 4, and 20 selected programs
per arm. Both arms used `js`, `wasm`, and `wasm-gc`.

| Arm | Selected programs | Backend executions | Distinct reference paths | Unique bodies | Mean source lines | Arm time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sequential | 20 | 60 | 53 | 20 | 133.8 | 9.0 s |
| Size-matched semantic-guided | 20 | 60 | 53 | 20 | 134.1 | 9.0 s |

Both arms were consistent on all 20 cases, with zero unexpected findings and
zero unavailable backends. Source-size quartile counts matched exactly
(`5, 4, 3, 8` for quartiles 0–3); the selected sets shared five seeds. The
candidate prescreen took 8.7 s. Here semantic guidance added no distinct
reference paths at equal backend execution budget, while still requiring the
prescreen.

Together with the first hosted cohort, the results are mixed: that cohort
showed 55 versus 51 path kinds; this one showed 53 versus 53. Both used the
same MoonBit version, disjoint candidate ranges, equal backend budgets, and
source-size-quartile matching, but two small cohorts do not estimate
effectiveness reliably. The measured signal does not justify making semantic
guidance a default or claiming better compiler coverage or bug-finding. Keep it
optional and do not spend feature-development effort on it without a stronger
pre-registered evaluation.
