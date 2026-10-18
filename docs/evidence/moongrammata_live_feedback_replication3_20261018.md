# Independent online-feedback replication 3 — 2026-10-18

This is the third completed exploratory run of the online three-arm harness. It uses fresh, disjoint arm seeds and is descriptive rather than paired, statistically powered, or representative of general fuzzer effectiveness.

## Setup and result

The campaign used MoonBit `0.1.20260920 (914d7da 2026-09-20)` and MoonGrammata `0.1.1` at pinned revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`, at depth 1, on JS/Wasm/Wasm-GC with a 30-second timeout per backend. Each arm selected 8 cases and completed 24 backend checks and 24 execution attempts. All selected cases were classified `consistent`; all configured backend runs succeeded. MoonGrammata made 8 synchronous Target callbacks and 8 reference checks, with no generator-limit observations. The harness digest was unchanged during the campaign (`60f91cd9…7cb79`).

| Arm | Distinct reference-interpreter path kinds | Findings | Backend checks / attempts | Proposal generation ms | Reference evaluation ms | Trace ms | Verifier wall ms | Campaign wall ms |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| Sequential | 18 | 8 consistent | 24 / 24 | 15,507 | 16,139 | 15,988 | 47,474 | 95,376 |
| Semantic-guided | 20 | 8 consistent | 24 / 24 | 16,357 | 15,559 | 15,748 | 46,553 | 94,436 |
| MoonGrammata | 19 | 8 consistent | 24 / 24 | 3,905 | 4,066 | 4,093 | 58,199 | 59,719 |

The control arms each preflighted 32 proposals; MoonGrammata evaluated 8 generated or mutated seeds inside synchronous callbacks. Selected source sizes were 4–23 lines (sequential), 4–28 (semantic-guided), and 7–28 (MoonGrammata). Equal backend checks therefore do not imply equal candidate-generation or total-compute budgets, and wall times must not be interpreted as throughput comparisons.

Across the three completed online-feedback runs, path-kind counts were sequential 15, 17, 18; semantic-guided 24, 27, 20; MoonGrammata 19, 13, 19. Semantic-guided was higher in these three observed cohorts; MoonGrammata varied around the sequential counts. Each arm had only eight selected cases per run, so these are small descriptive observations, not inferential evidence of a general advantage. No backend mismatch, crash, or compiler issue appeared in the 216 backend executions across the three completed runs; this is not evidence that such defects are absent.

## Same-run artifacts and reproducibility

The MoonGrammata verifier now stores each callback's exact generated `source.mbt` and corresponding `report.json` under a distinct `callback_N/candidate_SEED/` directory. All eight source hashes in this run matched the `sourceSha256` in their same-run verifier reports. The raw comparison report explicitly lists this artifact directory. This removes the need to regenerate the candidates after the experiment to recover their source.

Raw files use basename `moongrammata_live_feedback_replication3b_20261018`:

- `.configuration.json` and `.json` (candidate configuration and aggregate report)
- `.sequential.json` and `.semantic-guided.json`, including their `.artifacts/` directories
- `.moongrammata.json` and `.moongrammata.json.artifacts/` (eight exact callback sources and verifier reports)

The third-run candidate preflight started from seed `590000`, 32 candidates, and path-size matching; control proposal ranges began at `600000` and `601000`, and MoonGrammata generated IDs in `602000..603000`. The three arms use separate proposal-order/campaign seeds. Reproduce with:

```powershell
./scripts/compare_semantic_selection.ps1 `
  -SeedStart 590000 -CandidateCount 32 -ExecutionBudget 8 -Depth 1 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30 -SizeMatched `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication3b_20261018.configuration.json'

./scripts/run_live_feedback_campaign_comparison.ps1 `
  -SelectionReport 'docs/evidence/moongrammata_live_feedback_replication3b_20261018.configuration.json' `
  -SequentialSeedStart 600000 -SemanticGuidedSeedStart 601000 `
  -MoonGrammataSeedMinimum 602000 -MoonGrammataSeedMaximum 603000 `
  -ExecutionBudget 8 -ProposalBatchSize 4 `
  -SequentialProposalOrderSeed 20261301 -SemanticProposalOrderSeed 20261302 `
  -MoonGrammataCampaignSeed 20261303 `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication3b_20261018.json'
```

An earlier attempt on this seed range was invalidated when the harness digest changed during setup and stopped before the three-arm comparison. Its configuration is not included in these results; only the completed `replication3b` aggregate and raw reports above are counted. The workspace was dirty because the user's untracked application draft and that aborted setup configuration were present; tracked harness sources were unchanged while this completed run executed.
