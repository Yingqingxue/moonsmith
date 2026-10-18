# Three-arm live-feedback smoke pilot — 2026-10-18

## What this run checks

This is a small end-to-end plumbing and feasibility pilot for three fresh-seed campaigns, not a statistical effectiveness study. It checks that (1) a sequential controller, (2) a reference-path-novelty-guided controller, and (3) the pinned MoonGrammata campaign can generate candidates and synchronously evaluate candidates against the same current MoonSmith reference evaluator and backend matrix.

For each control round, the harness generated a two-seed proposal window, computed source, reference output, and reference trace for both proposals, then backend-verified one selected candidate. Each arm deterministically shuffled its own disjoint seed range using a separately recorded proposal-order seed. The sequential controller chose the first valid seed in that randomized window. The novelty-guided controller chose the proposal with the highest count of unseen reference-path kinds per source line within the first valid source-size band, with deterministic tie-breaks. It updated its seen-path set only after the selected candidate completed verification. Those reference preflights are extra work, recorded separately; they are not charged as backend checks.

MoonGrammata used its synchronous Target callback on newly generated integer seeds. On every callback it invoked the same verifier, received the current finding, path trace, and backend outcomes, and returned those features before campaign scheduling resumed. Its random campaign used a separate seed and a disjoint generator-seed range.

## Matched settings and observations

- MoonBit toolchain: `moon 0.1.20260920 (914d7da 2026-09-20)`.
- MoonGrammata: `0.1.1`, pinned revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`.
- Backend matrix: JavaScript, Wasm, and Wasm-GC; depth 1; 30-second timeout per backend.
- Requested/observed selected cases: 2 per arm; actual backend-check rows: 6 per arm. All checks reached execution and were `succeeded`; all six cases were `consistent`.
- Independent seed ranges: sequential `410000..410003` (proposal-order seed `20261020`); novelty-guided `420000..420003` (proposal-order seed `20261021`); MoonGrammata generator range `430000..430100`, campaign seed `20261019`.
- Distinct selected reference-path kinds: sequential 10; novelty-guided 14; MoonGrammata 8.
- Selected seeds: sequential `410003, 410000`; novelty-guided `420000, 420001`; MoonGrammata `430076, 430067`.
- Selected source sizes: sequential 13 and 7 lines; novelty-guided 7 and 48 lines; MoonGrammata 17 and 14 lines.
- Control-arm proposal generation/reference/trace costs (ms): sequential `1904 / 1888 / 1852`; novelty-guided `1711 / 1682 / 1692`.
- Selected-case verifier wall time: sequential `12016 ms`; novelty-guided `10446 ms`. MoonGrammata verifier wall time `13705 ms`, including `7297 ms` of backend build/execution; campaign wall time `15119 ms`.

The raw arm reports, seed-window configuration, generated source files, expected outputs, and reference traces are preserved beside this note under the matching `moongrammata_live_feedback_three_arm_smoke_20261018` basename. The wrapper also records SHA-256 checks and rejects a stale/changed verifier harness.

The configuration report records `gitDirty=true` because local/untracked files were present. The harness digest at the beginning and end is identical, and the exact generated candidates and traces are preserved; treat the source/configuration JSON and its digests as the authoritative run identity rather than the Git cleanliness bit.

## Interpretation and limits

The novelty-guided control selected a more diverse set of reference-path kinds in this two-case smoke cohort, but one of its selected programs was 48 lines versus 7 and 13 lines in the sequential arm. The statistic is therefore highly sensitive to this tiny, unpaired cohort and candidate complexity. MoonGrammata's two callbacks produced 8 path kinds; this is not directly evidence of superiority or inferiority. The arms have equal selected-case and backend-check budgets, targets, depth, and per-target timeout, but they do **not** have equal reference-probe counts, total compute, or wall-clock stopping budgets. The controls preflight two candidates for each selected case; MoonGrammata verifies one generated candidate per callback. Wall-clock values are descriptive only.

No compiler mismatch, crash, compile failure, runtime failure, or new compiler issue was observed in these 18 backend checks. This does not rule out such failures elsewhere and does not claim discovery of an issue already reported upstream. The run is only a smoke-scale demonstration that the online feedback loop and accounting work. Larger preregistered repetitions with more independent ranges, matched candidate-size strata, and explicit reference-probe/compute budgets are needed before comparing effectiveness.

Reproduce the plumbing test with:

```powershell
pwsh -NoProfile -File scripts/test_live_feedback_campaign_comparison.ps1
```

The test runs a fresh configuration report and a minimal three-arm comparison and checks equal observed backend checks, disjoint seed ranges, per-callback live observations, retained raw artifacts, and a disabled throughput claim. It does not assert any particular path-diversity result.

To repeat a similarly small (two selected cases per arm) run with fresh independent seed ranges:

```powershell
$selection = '.moonsmith/runs/live-selection-input.json'
./scripts/compare_semantic_selection.ps1 `
  -SeedStart 400000 -CandidateCount 6 -ExecutionBudget 2 -Depth 1 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30 -OutputPath $selection
./scripts/run_live_feedback_campaign_comparison.ps1 `
  -SelectionReport $selection -SequentialSeedStart 410000 -SemanticGuidedSeedStart 420000 `
  -MoonGrammataSeedMinimum 430000 -MoonGrammataSeedMaximum 430100 `
  -ExecutionBudget 2 -ProposalBatchSize 2 `
  -SequentialProposalOrderSeed 20261020 -SemanticProposalOrderSeed 20261021 `
  -MoonGrammataCampaignSeed 20261019 `
  -OutputPath 'docs/evidence/moongrammata_live_feedback_three_arm_smoke_20261018.json'
```
