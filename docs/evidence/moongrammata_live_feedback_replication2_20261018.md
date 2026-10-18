# Independent live-feedback replication 2 — 2026-10-18

This is a second, independent exploratory run of the same online three-arm harness, with fresh, disjoint seeds. It is not a paired or statistically powered comparison. See `moongrammata_live_feedback_expanded_20261018.md` for protocol details, exact commands, and the first run.

## Configuration and observed outcomes

MoonBit `0.1.20260920 (914d7da 2026-09-20)`, MoonGrammata `0.1.1` at revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`; depth 1; JS/Wasm/Wasm-GC; 30-second per-backend timeout; 8 selected cases per arm. Each arm completed 24 backend checks and 24 execution attempts, all successful and consistent. MoonGrammata made 8 live Target callbacks and 8 reference checks, with no generator-limit observations. Harness digests matched at run start/end.

| Arm | Distinct selected reference-path kinds | Findings | Checks / executions | Proposal generation ms | Reference eval ms | Reference trace ms | Verifier wall ms | Campaign wall ms |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| Sequential | 17 | 8 consistent | 24 / 24 | 14,696 | 14,549 | 14,651 | 42,704 | 86,845 |
| Semantic-guided | 27 | 8 consistent | 24 / 24 | 14,609 | 14,429 | 14,738 | 43,854 | 87,832 |
| MoonGrammata | 13 | 8 consistent | 24 / 24 | 3,583 | 3,772 | 3,618 | 54,316 | 56,042 |

The control arms each preflighted 32 proposals; MoonGrammata evaluated 8 generated/mutated seeds in synchronous callbacks. Selected source lengths were 4–28 lines (sequential), 4–48 (semantic-guided), and 4–28 (MoonGrammata). Equal backend-check counts therefore do not mean equal proposal or total-compute budgets. The smaller observed MoonGrammata campaign wall time is not a throughput result. These independent cohorts have different seeds and candidate sizes, so path-kind counts are descriptive only.

Across just these two runs, the path-kind counts were sequential 15 and 17, semantic-guided 24 and 27, MoonGrammata 19 and 13. Semantic-guided was higher in both observed runs; MoonGrammata varied around the sequential result. With only two runs of 8 cases each, no inferential or general effectiveness claim is warranted. No backend mismatch, crash, or compiler issue was found in these 144 target executions (24 per arm × 3 arms × 2 runs); this is not evidence that such bugs are absent.

## Raw data and artifacts

Raw arm reports, candidate-window configuration, control source/expected-output/trace files, and generated MoonGrammata source snapshots plus per-seed verifier reports are stored beside this note with basename `moongrammata_live_feedback_replication2_20261018`. The 8 generated MoonGrammata source SHA-256 values were checked against their verifier reports. The user's untracked申报书 draft was present but untouched; the campaign harness digest was stable during the run.
