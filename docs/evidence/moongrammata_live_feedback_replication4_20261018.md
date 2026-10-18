# MoonGrammata live-feedback replication 4 — 2026-10-18

This fourth run repeats the exploratory online-feedback comparison with new,
disjoint seed ranges. It remains descriptive: the three arms do not receive
paired candidates, and eight selected cases per arm are too few for an
effectiveness claim.

## Protocol and result

MoonBit was `0.1.20260920 (914d7da)` and MoonGrammata was `0.1.1` at pinned
revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`. All arms used depth 1,
JS/Wasm/Wasm-GC, and a 30-second timeout per backend. Each arm completed 8
cases, 24 backend checks, and 24 execution attempts; all cases were
`consistent`, and all backend executions succeeded. The sequential and
semantic-guided controls each preflighted 32 fresh proposals. MoonGrammata
performed 8 synchronous Target callbacks, with 8 verifier calls and no
generator-limit observations.

| Arm | Distinct reference-path kinds | Cases | Backend checks / attempts | Proposal generation ms | Reference evaluation ms | Trace ms | Verifier wall ms | Campaign wall ms |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Sequential | 13 | 8 consistent | 24 / 24 | 15,980 | 15,736 | 16,264 | 47,720 | 96,077 |
| Semantic-guided | 21 | 8 consistent | 24 / 24 | 16,240 | 16,094 | 16,195 | 46,623 | 95,377 |
| MoonGrammata | 12 | 8 consistent | 24 / 24 | 3,976 | 4,335 | 4,153 | 58,950 | 60,535 |

The controls prescreened 32 proposals each while MoonGrammata generated and
mutated integer seed IDs online. Therefore equal backend checks and timeouts
do not mean equal proposal-generation or total-compute budgets. The wall-clock
figures are descriptive and must not be read as throughput superiority.
Semantic-guided selection had more distinct path kinds in this cohort; this
single small cohort is not proof of general superiority. There were no
backend mismatches, crashes, compiler issues, or generator-limit observations
in this run; that is not evidence such outcomes are absent generally.

The harness digest was unchanged during the campaign
(`60f91cd9ab591397aacdc867a0a2dd43bf5b4a108c8d288c7dc57c25d6d7cb79`). The
eight callback source snapshots each have a corresponding verifier
`report.json`; rehashing all eight sources reproduced each report's
`sourceSha256`. This demonstrates live callback artifact capture, not fuzzer
effectiveness.

Across the four completed online runs, distinct path-kind counts were:

| Run | Sequential | Semantic-guided | MoonGrammata |
|---|---:|---:|---:|
| 1 | 15 | 24 | 19 |
| 2 | 17 | 27 | 13 |
| 3 | 18 | 20 | 19 |
| 4 | 13 | 21 | 12 |

Semantic-guided was higher in all four observed cohorts, while MoonGrammata
varied around or below sequential. This is hypothesis-generating only: arms
are unpaired, sample size is eight per arm per run, candidate generation is
not budget-matched, and path diversity is a proxy rather than a bug-finding
outcome. More importantly, semantic-guided selection explicitly chooses
candidates by unseen reference-path kinds per source line, so this outcome
metric is aligned with that arm's optimization rule. Its higher counts are
therefore not a neutral test of overall fuzzer effectiveness and are partly
expected by construction. No statistical or general-purpose fuzzer comparison
is justified.

## Raw files and reproduction

Raw files share basename `moongrammata_live_feedback_replication4_20261018`:
the `.configuration.json`, aggregate `.json`, `.sequential.json`,
`.semantic-guided.json`, `.moongrammata.json`, and their `.artifacts/`
directories. The MoonGrammata artifact directory contains eight callback
candidate source/report pairs.

```powershell
./scripts/compare_semantic_selection.ps1 `
  -SeedStart 610000 -CandidateCount 32 -ExecutionBudget 8 -Depth 1 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30 -SizeMatched `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication4_20261018.configuration.json'

./scripts/run_live_feedback_campaign_comparison.ps1 `
  -SelectionReport 'docs/evidence/moongrammata_live_feedback_replication4_20261018.configuration.json' `
  -SequentialSeedStart 620000 -SemanticGuidedSeedStart 621000 `
  -MoonGrammataSeedMinimum 622000 -MoonGrammataSeedMaximum 623000 `
  -ExecutionBudget 8 -ProposalBatchSize 4 `
  -SequentialProposalOrderSeed 20261401 -SemanticProposalOrderSeed 20261402 `
  -MoonGrammataCampaignSeed 20261403 `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_replication4_20261018.json'
```
