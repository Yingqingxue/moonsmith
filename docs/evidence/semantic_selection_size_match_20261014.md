# Source-size-matched semantic selection (2026-10-14)

This run follows the fixed design in
[`semantic_selection_size_match_preregistration_20261014.md`](semantic_selection_size_match_preregistration_20261014.md)
and used the committed harness at `c0b5497ee46bac063068aa86cf1721dccdf9afc9`.
The harness was clean and its start/end digest matched.

| Arm | Seeds | Programs | Backend launches | Reference paths | Unique bodies | Mean source lines | Arm time |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sequential | 24120–24139 | 20 | 60 | 52 | 20 | 120.6 | 120.7 s |
| Size-matched semantic-guided | see raw report | 20 | 60 | 53 | 20 | 124.6 | 124.8 s |

The four source-size quartile quotas matched exactly: 5, 6, 6, and 3 selected
programs in quartiles 0–3 for both arms. The selected sets shared four seeds.
All 40 selected programs were reference-checked and consistent across the
three configured backends. The complete candidate pool had 53 distinct
reference path kinds; guidance represented all 53, compared with 52 in the
sequential arm. Thus the measured gain was one additional reference path kind
at this budget. No compiler defect was found.

Prescreening all 100 candidates took 88.8 seconds. The sequential arm took
120.7 seconds and the guided arm 124.8 seconds; the full guided workflow
therefore cost about 213.6 seconds when prescreen time is included. The source
size match largely controls the size difference in this cohort, but one
additional path kind for that overhead is weak evidence of practical value.
The run does not measure compiler-internal coverage or defect-finding
probability, and one registered cohort cannot support statistical claims.

Raw report: `.moonsmith/runs/selection_24120_100_20_d4_size_matched.json`
(local and ignored by Git). Reproduce the selection protocol with:

```powershell
pwsh -File scripts/compare_semantic_selection.ps1 -SeedStart 24120 `
  -CandidateCount 100 -ExecutionBudget 20 -Depth 4 `
  -Targets @('js','wasm','wasm-gc') -GuidedFirst -SizeMatched
```
