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

## Result

| Selection arm | Unique live-verified candidates | Backend executions | Distinct live reference paths | Verifier findings |
| --- | ---: | ---: | ---: | --- |
| Sequential | 15 | 45 | 51 | 15 consistent |
| MoonSmith semantic-guided | 15 | 45 | 53 | 15 consistent |
| MoonGrammata-selected | 15 | 45 | 51 | 15 consistent |

The live traces for all 45 candidates matched the path labels stored in the
fresh frozen-pool report. The three verifier-arm durations were approximately
107.9 s, 107.0 s, and 108.0 s respectively. Runs were sequential, so these
small timing differences are not a controlled throughput comparison.

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
