# Live blind verification of selected MoonGrammata candidates (2026-10-18)

## Protocol

This follow-up closes one narrow gap in the frozen-pool comparison: the
selected candidate IDs are no longer evaluated only by their saved path labels.
For each arm, MoonSmith regenerates each seed at the recorded depth and runs
the same differential verifier against the same configured backends. The
verifier runs after selection and does not feed results back into MoonGrammata.

The run used the fresh 100-candidate pool `24320..24419`, depth 4, selection
seed `20261018`, and targets JS, Wasm, and Wasm-GC. All three arms had 20
selection slots; MoonGrammata observed 18 distinct IDs because its campaign
can revisit candidates. To avoid counting repeats as extra independent
programs, the live comparison uses the 15 unique candidates common to all arms
after matching source-size quartile counts: quartiles 0/1/2/3 contributed
5/3/4/3 candidates. Each arm therefore received 45 backend executions.

The generator, reference interpreter, and verifier digest was
`6846500968acb92203cda413384f370637c71c4b3516cbc2eb3d97c4796dabee`. The
recorded Git head was `34c9aa47c051214b43eb89ad095872af163b442b`; the worktree
was marked dirty because the experiment runner and workflow update were in
progress. Those files are not part of the candidate-generation/verifier digest.

The same seed, pool, configuration, and digest were then reproduced in a clean
GitHub Actions run at commit
`6fbb953d25332d9c51a5b2fe3626143c5b934961` (`moon 0.1.20261012`), with
`gitDirty=false` and `harnessChangedDuringRun=false`. The optional
semantic-selection job in
[run 39109430420](https://github.com/Yingqingxue/moonsmith/actions/runs/39109430420)
passed, including the stale-pool rejection test; its artifact contains both
the frozen report and live-verification report (retained for 30 days).

## Result

| Selection arm | Unique live-verified candidates | Backend executions | Distinct live reference paths | Verifier findings |
| --- | ---: | ---: | ---: | --- |
| Sequential | 15 | 45 | 51 | 15 consistent |
| MoonSmith semantic-guided | 15 | 45 | 53 | 15 consistent |
| MoonGrammata-selected | 15 | 45 | 51 | 15 consistent |

The live traces for all 45 candidates matched the path labels stored in the
fresh frozen-pool report. On this Windows workstation, the three verifier-arm
durations were 107.9 s, 107.0 s, and 108.0 s. The GitHub-hosted Ubuntu rerun
recorded 15.4 s, 15.0 s, and 14.8 s. These machines and build-cache states
differ; cross-environment durations are not comparable. The arms were also
run sequentially, so within-run timing differences are not a controlled
throughput comparison.

## Independent second cohort

A second, non-overlapping pool (`24220..24319`) was run with the same depth,
selection seed, target set, budgets, size-quartile matching, and live verifier.
The clean hosted run used the same harness digest
`6846500968acb92203cda413384f370637c71c4b3516cbc2eb3d97c4796dabee`, Moon
`0.1.20261012`, and source commit
`6fbb953d25332d9c51a5b2fe3626143c5b934961`; the recorded start/end digests
matched and the worktree was clean. The result is preserved in
[GitHub Actions run 39113950702](https://github.com/Yingqingxue/moonsmith/actions/runs/39113950702)
(artifact retained for 30 days).

MoonGrammata observed 17 unique candidates in its 20 campaign executions. The
common, unique, size-quartile-matched subset contained 10 candidates per arm,
with quartiles 0/1/2/3 contributing 3/2/4/1 candidates. Each arm received 30
backend executions across JS, Wasm, and Wasm-GC. All 30 live traces matched the
frozen-pool reference-path labels. The arms each had 10 `consistent` outcomes
and no mismatch. Their distinct live reference-path counts were 50 for
sequential, 55 for semantic-guided, and 50 for MoonGrammata-selected. This
hosted cohort's per-arm verification durations were 10.460 s, 10.276 s, and
10.307 s respectively; these are descriptive sequential-run timings, not a
controlled throughput result.

Across the two independent pools, the narrow observed pattern repeated:
MoonGrammata tied sequential selection on the measured reference-path count
(51 vs. 51 in the first matched subset; 50 vs. 50 in the second) and was below
semantic-guided selection (53 and 55, respectively). No selected program in
either cohort produced a backend/reference mismatch. These two bounded cohorts
strengthen reproducibility of this specific fixed-pool observation, but do not
show general or online-feedback effectiveness, bug-finding superiority, or
statistical significance.

## Interpretation and limits

On this cohort, MoonGrammata's selected programs tied the sequential arm on
distinct MoonSmith reference-interpreter paths (51 vs. 51) and trailed the
semantic-guided arm (51 vs. 53). No selected candidate exposed a backend /
reference mismatch in any arm. This is a descriptive result for one fixed
candidate pool, not evidence of a general effectiveness difference.

The campaign still consumes cached MoonSmith path feedback to select from the
pool. Only the post-selection verification is live and common across arms;
this is not an online, live-feedback fuzzer comparison. The 100-candidate
prescreen and campaign costs are additional and are not normalized into the
post-selection durations. Reference-interpreter paths are not backend
coverage. The result does not establish which project finds more bugs overall.

Reproduce on a fresh size-matched report with:

```powershell
./scripts/run_moongrammata_selection.ps1 `
  -InputReport .moonsmith/runs/selection_24320_100_20_d4_size_matched.json `
  -ExecutionBudget 20 -Seed 20261018 `
  -OutputPath .moonsmith/runs/moongrammata_live_24320_100_20.json `
  -LiveVerifySelectedArms

./scripts/test_moongrammata_selection.ps1 `
  -InputReport .moonsmith/runs/selection_24320_100_20_d4_size_matched.json `
  -ExecutionBudget 20 -Seed 20261018 `
  -LiveVerificationPath .moonsmith/runs/moongrammata_live_24320_100_20.json
```

The runner refuses live verification if the frozen report's generator /
reference / verifier digest is stale or if regenerated reference paths do not
match the frozen pool. This guard matters: an exploratory attempt using an
older report generated from the same seed range produced path-label mismatches
for every checked case after the harness had changed, and was discarded rather
than counted as a comparison.
