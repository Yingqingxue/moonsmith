# Expanded live-feedback comparison — 2026-10-18

## Purpose and scope

This is a single exploratory 3-arm run to exercise the synchronous feedback loop and preserve measurable outcomes. It is not a powered effectiveness study, a paired-seed comparison, or a throughput benchmark. The harness used MoonGrammata `0.1.1` (pinned revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`) and MoonBit `0.1.20260920 (914d7da 2026-09-20)`.

All arms used depth 1, JavaScript/Wasm/Wasm-GC, and a 30-second timeout per backend. Each arm selected 8 cases and completed 24 backend checks. The sequential and semantic-guided controls each generated/preflighted a 32-candidate window per round-policy campaign, using separate deterministic proposal-order seeds and disjoint integer seed ranges. MoonGrammata synchronously called the same MoonSmith verifier from its Target callback for 8 newly generated integer seeds; its seed range and campaign seed were disjoint from both controls. Harness digests were unchanged from run start to end. The workspace was dirty because the user's untracked申报书 draft was present; it was not included in or modified by this experiment.

## Observed outcomes

| Arm | Selected reference-path kinds | Selected findings | Backend checks / execution attempts | Proposal generation ms | Reference eval ms | Reference trace ms | Verifier wall ms | Campaign wall ms |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| Sequential | 15 | 8 consistent | 24 / 24 | 15,487 | 15,679 | 15,733 | 47,422 | 94,600 |
| Semantic-guided | 24 | 8 consistent | 24 / 24 | 15,590 | 15,583 | 16,542 | 46,298 | 94,234 |
| MoonGrammata | 19 | 8 consistent | 24 / 24 | 4,382 | 4,674 | 4,281 | 60,163 | 61,698 |

MoonGrammata made 8 live callbacks and 8 reference checks; no generator-limit observations occurred. All 24 JS/Wasm/Wasm-GC backend results succeeded with exit code 0 in every arm. No backend mismatch, crash, or new compiler issue was observed. This does not test or establish absence of compiler bugs.

Selected control source lengths were 4–13 lines (sequential) and 4–15 lines (semantic-guided); MoonGrammata selected 7–28 lines. Thus equal backend-check counts and target settings do not imply equal generated-program complexity or equal total work: both control arms pay for 32 candidate preflights per round-policy campaign, whereas MoonGrammata verified 8 callback candidates, and candidate lengths differ. The lower observed MoonGrammata campaign wall time is therefore not a throughput or efficiency result. The controls use fresh path preflight and feedback between rounds; MoonGrammata gets synchronous callback feedback. The seed sets are independent and unpaired. The path-kind totals are descriptive observations from this run only.

## Reproduction and raw data

The exact configuration and raw arm reports, including per-candidate source, expected output, reference trace, and backend results, are preserved as:

- `moongrammata_live_feedback_expanded_20261018.configuration.json`
- `moongrammata_live_feedback_expanded_20261018.sequential.json` and `.sequential.json.artifacts/`
- `moongrammata_live_feedback_expanded_20261018.semantic-guided.json` and `.semantic-guided.json.artifacts/`
- `moongrammata_live_feedback_expanded_20261018.moongrammata.json`
- `moongrammata_live_feedback_expanded_20261018.moongrammata.artifacts/` (the 8 selected MoonGrammata sources and per-seed verifier JSON)

The MoonGrammata source snapshots were regenerated from each selected seed at depth 1 and individually re-verified on JS/Wasm/Wasm-GC; their SHA-256 values matched the corresponding verifier reports' `sourceSha256` fields. This adds direct source artifacts to the callback observations, which the runner's aggregate report alone does not embed.
- `moongrammata_live_feedback_expanded_20261018.json`

Re-run from the repository root (these seeds are already used; choose fresh non-overlapping ranges for another run):

```powershell
scripts/compare_semantic_selection.ps1 `
  -SeedStart 550000 -CandidateCount 32 -ExecutionBudget 8 -Depth 1 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30 -SizeMatched `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_expanded_20261018.configuration.json'

scripts/run_live_feedback_campaign_comparison.ps1 `
  -SelectionReport 'docs/evidence/moongrammata_live_feedback_expanded_20261018.configuration.json' `
  -SequentialSeedStart 560000 -SemanticGuidedSeedStart 561000 `
  -MoonGrammataSeedMinimum 562000 -MoonGrammataSeedMaximum 563000 `
  -ExecutionBudget 8 -ProposalBatchSize 4 `
  -SequentialProposalOrderSeed 20261101 -SemanticProposalOrderSeed 20261102 `
  -MoonGrammataCampaignSeed 20261103 `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_expanded_20261018.json'
```

The harness and verification workflow at commit `df501797c17b2ade67f48bdaa0278bb18c552cde` passed local tests and GitHub Actions run [39133073194](https://github.com/Yingqingxue/moonsmith/actions/runs/39133073194), including Linux verification, CaseKit interoperability, and Windows native smoke. The run checks integration and reproducibility; it is not evidence of comparative effectiveness.
