# MoonGrammata live-feedback replication 6 — 2026-10-19

This larger exploratory cohort repeats the online three-arm comparison with
24 cases per arm, up from 16 in replication 5. It is descriptive, unpaired,
and not statistically powered.

The live claim is limited to a synchronous target callback, not an asynchronous
service: in pinned MoonGrammata 0.1.1, [`Target` stores an
`(Bytes) -> TargetObservation` evaluator](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/feedback.mbt), and
[`run_campaign` repeatedly executes candidates through that target](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/campaign.mbt).
MoonSmith's adapter is a MoonBit JavaScript-target `extern "js"` bridge that
uses Node's `child_process.spawnSync` to run the verifier. The non-JavaScript
build has an explicit unsupported-host error branch, so this prototype proves
the Node-hosted synchronous path only; it does not claim browser, async, or
cross-host FFI portability.

## Protocol and result

MoonBit was `0.1.20260920 (914d7da)` and MoonGrammata was `0.1.1` at pinned
revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`. All arms used depth 1,
JS/Wasm/Wasm-GC, and a 30-second timeout per backend. Each arm completed 24
cases and 72 backend execution attempts; all cases were `consistent`, and all
configured backends succeeded. MoonGrammata made 24 synchronous Target
callbacks, with no verifier failures or generator-limit observations.

| Arm | Distinct reference-path kinds | Cases | Backend checks / attempts | Candidate proposals / callbacks | Proposal-generation ms | Reference-evaluation ms | Trace ms | Verifier wall ms | Campaign wall ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Sequential | 39 | 24 | 72 / 72 | 96 proposals | 47,813 | 48,309 | 48,519 | 134,597 | 279,883 |
| Semantic-guided | 44 | 24 | 72 / 72 | 96 proposals | 47,012 | 47,193 | 47,767 | 132,329 | 274,884 |
| MoonGrammata | 34 | 24 | 72 / 72 | 24 callbacks | 12,612 | 12,670 | 11,966 | 170,903 | 172,398 |

Selected-case path-kind accumulation at six-case intervals was:

| Arm | After 6 | After 12 | After 18 | After 24 |
|---|---:|---:|---:|---:|
| Sequential | 17 | 29 | 34 | 39 |
| Semantic-guided | 13 | 26 | 43 | 44 |
| MoonGrammata | 13 | 15 | 25 | 34 |

The semantic-guided control directly selects by unseen reference-path kinds,
so this metric is aligned with its optimization rule and does not imply
general fuzzer effectiveness. As in replication 5, the controls preflighted
four proposals per selected case (96 total) while MoonGrammata made one
verifying callback per case (24 total). The selected-case backend-check count
and timeout configuration match, but candidate-generation, reference-trace,
and total-compute budgets do not. Wall-clock numbers are descriptive and do
not support a throughput comparison.

The run found no backend mismatch, crash, compiler issue, or generator-limit
observation in its 216 backend executions. This bounded random sample is not
evidence that such defects are absent. Path diversity is a proxy, not a count
of bugs found.

## Reproducibility and artifacts

The verifier harness digest was unchanged during the run
(`60f91cd9ab591397aacdc867a0a2dd43bf5b4a108c8d288c7dc57c25d6d7cb79`); the
selection harness digest was also unchanged. All 24 MoonGrammata callback
source snapshots have a verifier report whose `sourceSha256` matches the
rehash of `source.mbt`. The configuration records `gitDirty=true` because
the user's untracked project-application draft was present; no project source
changes were made during the campaign.

Raw files share basename `moongrammata_live_feedback_replication6_20261019`:
the `.configuration.json`, aggregate `.json`, `.sequential.json`,
`.semantic-guided.json`, `.moongrammata.json`, and corresponding `.artifacts/`
directories. The live callback artifact directory contains 24 source/report
pairs.

```powershell
./scripts/compare_semantic_selection.ps1 `
  -SeedStart 660000 -CandidateCount 96 -ExecutionBudget 24 -Depth 1 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30 -SizeMatched `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication6_20261019.configuration.json'

./scripts/run_live_feedback_campaign_comparison.ps1 `
  -SelectionReport 'docs/evidence/moongrammata_live_feedback_replication6_20261019.configuration.json' `
  -SequentialSeedStart 670000 -SemanticGuidedSeedStart 671000 `
  -MoonGrammataSeedMinimum 672000 -MoonGrammataSeedMaximum 673000 `
  -ExecutionBudget 24 -ProposalBatchSize 4 `
  -SequentialProposalOrderSeed 20261505 -SemanticProposalOrderSeed 20261506 `
  -MoonGrammataCampaignSeed 20261504 `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication6_20261019.json'
```
