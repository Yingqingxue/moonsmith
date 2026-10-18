# MoonGrammata live-feedback replication 7 — 2026-10-19

This is a seventh exploratory, unpaired three-arm cohort. It increases the
selected cases per arm from 24 to 32; it is descriptive, not statistically
powered, and it does not establish general fuzzer effectiveness.

## Protocol

All arms used depth 1, JS/Wasm/Wasm-GC, 30 seconds per backend, and 32 selected
cases. Each arm made 96 backend execution attempts; all succeeded. Seed ranges
were disjoint. The two controls each generated and preflighted 128 candidate
proposals, then selected 32 for backend verification. MoonGrammata generated
and verified 32 callback candidates online, of which 25 seeds were unique.
Thus the selected-case backend-call budget and timeout matrix match, but
candidate generation, reference preflight, and total compute do not. Semantic
guidance explicitly optimizes the reported path-novelty metric. Wall-clock is
reported as descriptive only; this design cannot support a throughput ranking.

## Results

| Arm | Distinct reference-path kinds | Selected cases | Backend attempts | Candidate proposals / callbacks | Campaign wall ms |
|---|---:|---:|---:|---:|---:|
| Sequential | 38 | 32 | 96 | 128 proposals | 379,577 |
| Semantic-guided | 48 | 32 | 96 | 128 proposals | 379,986 |
| MoonGrammata | 24 | 32 callbacks | 96 | 32 callbacks (25 unique seeds) | 230,982 |

Path-kind accumulation at eight-case intervals was sequential 20/33/38/38,
semantic-guided 21/39/46/48, and MoonGrammata 15/22/23/24. All 32 selected
cases in each arm were consistent. Each configured backend succeeded on all
32 cases per arm. MoonGrammata had 32 reference checks, zero generator-limit
observations, and zero callback failures.

The result is consistent with the prior small cohorts on this particular
path-diversity proxy, but seed streams were disjoint and runs were not paired.
Semantic-guided's higher count is aligned with its explicit selection
objective, not evidence of higher defect-finding effectiveness. The run found
no mismatch, crash, compiler issue, or generator-limit observation in its 288
backend attempts; this bounded sample does not show that such failures are
absent. Reference-path diversity is not a bug count.

## Reproduction and audit

MoonBit was `0.1.20260920 (914d7da)`. The pinned MoonGrammata 0.1.1 callback
and Node-hosted synchronous FFI limitations remain as documented in
[replication 6](moongrammata_live_feedback_replication6_20261019.md). The
configuration records `gitDirty=true` because the user's untracked application
draft was present; it was not modified or included in the commit. An artifact
audit confirmed all 32 callback source snapshots have matching report
`sourceSha256`, a checked reference result, a `consistent` finding, and three
backend records.

Raw files share basename `moongrammata_live_feedback_replication7_20261019`:
the `.configuration.json`, aggregate `.json`, per-arm `.sequential.json`,
`.semantic-guided.json`, `.moongrammata.json`, and corresponding artifact
directories. The callback artifact directory contains 32 source/report pairs.

```powershell
./scripts/compare_semantic_selection.ps1 `
  -SeedStart 680000 -CandidateCount 128 -ExecutionBudget 32 -Depth 1 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30 -SizeMatched `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication7_20261019.configuration.json'

./scripts/run_live_feedback_campaign_comparison.ps1 `
  -SelectionReport 'docs/evidence/moongrammata_live_feedback_replication7_20261019.configuration.json' `
  -SequentialSeedStart 690000 -SemanticGuidedSeedStart 691000 `
  -MoonGrammataSeedMinimum 692000 -MoonGrammataSeedMaximum 693000 `
  -ExecutionBudget 32 -ProposalBatchSize 4 `
  -SequentialProposalOrderSeed 20261508 -SemanticProposalOrderSeed 20261509 `
  -MoonGrammataCampaignSeed 20261507 `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication7_20261019.json'
```
