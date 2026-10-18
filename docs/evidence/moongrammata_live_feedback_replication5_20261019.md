# MoonGrammata live-feedback replication 5 — 2026-10-19

This larger exploratory cohort repeats the online three-arm comparison with
fresh disjoint seeds and 16 selected cases per arm. It is descriptive, not a
paired or statistically powered test.

## Protocol and result

MoonBit was `0.1.20260920 (914d7da)` and MoonGrammata was `0.1.1` at pinned
revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`. All arms used depth 1,
JS/Wasm/Wasm-GC, and a 30-second timeout per backend. Each arm completed 16
cases, 48 backend checks, and 48 execution attempts. Every case was
`consistent`; all configured backend executions succeeded. The controls
preflighted 64 fresh proposals each. MoonGrammata performed 16 synchronous
Target callbacks and 16 verifier calls, with no generator-limit observations.

| Arm | Distinct reference-path kinds | Cases | Backend checks / attempts | Proposal generation ms | Reference evaluation ms | Trace ms | Verifier wall ms | Campaign wall ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Sequential | 21 | 16 consistent | 48 / 48 | 30,547 | 29,730 | 29,992 | 88,183 | 178,997 |
| Semantic-guided | 35 | 16 consistent | 48 / 48 | 29,943 | 30,443 | 30,015 | 89,097 | 179,892 |
| MoonGrammata | 32 | 16 consistent | 48 / 48 | 7,713 | 7,916 | 8,091 | 111,223 | 112,947 |

The selected-case path-kind accumulation (selection order) was:

| Arm | After 4 cases | After 8 | After 12 | After 16 |
|---|---:|---:|---:|---:|
| Sequential | 14 | 19 | 19 | 21 |
| Semantic-guided | 14 | 26 | 32 | 35 |
| MoonGrammata | 16 | 22 | 27 | 32 |

The semantic-guided control explicitly selects by unseen reference-path kinds
per source line, so path diversity is aligned with its optimization rule.
Its lead on this metric is not a neutral measure of overall fuzzer quality.
Moreover, the controls preflighted 64 proposals each while MoonGrammata made
16 callbacks; candidate-generation and total-compute budgets are therefore
not matched. Equal backend checks and timeout configuration do not establish
equal total cost. Wall-clock values are descriptive only and cannot support a
throughput claim.

This run found no backend mismatch, crash, compiler issue, or generator-limit
observation in its 144 backend executions. This small result does not show
that such defects are absent. Path diversity remains a proxy, not a count of
bugs discovered.

## Reproducibility and artifacts

The harness digest was unchanged during the campaign
(`60f91cd9ab591397aacdc867a0a2dd43bf5b4a108c8d288c7dc57c25d6d7cb79`). All
16 MoonGrammata callback source snapshots have a matching verifier report;
rehashing each source reproduced its report's `sourceSha256`.

Raw files share basename `moongrammata_live_feedback_replication5_20261019`:
the `.configuration.json`, aggregate `.json`, `.sequential.json`,
`.semantic-guided.json`, `.moongrammata.json`, and corresponding `.artifacts/`
directories. The callback artifact directory contains 16 source/report pairs.

```powershell
./scripts/compare_semantic_selection.ps1 `
  -SeedStart 630000 -CandidateCount 64 -ExecutionBudget 16 -Depth 1 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30 -SizeMatched `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication5_20261019.configuration.json'

./scripts/run_live_feedback_campaign_comparison.ps1 `
  -SelectionReport 'docs/evidence/moongrammata_live_feedback_replication5_20261019.configuration.json' `
  -SequentialSeedStart 640000 -SemanticGuidedSeedStart 641000 `
  -MoonGrammataSeedMinimum 642000 -MoonGrammataSeedMaximum 643000 `
  -ExecutionBudget 16 -ProposalBatchSize 4 `
  -SequentialProposalOrderSeed 20261501 -SemanticProposalOrderSeed 20261502 `
  -MoonGrammataCampaignSeed 20261503 `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication5_20261019.json'
```
