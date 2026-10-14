# Preregistered source-size-matched seed-selection cohort

This protocol is recorded before running the cohort. It follows the three
exploratory cohorts documented in
[`semantic_selection_20261014.md`](semantic_selection_20261014.md).

## Fixed design

- Candidate seeds: 24120–24219 inclusive (100 consecutive seeds).
- Selection budget: 20 programs per arm.
- Generator depth: 4.
- Backend matrix: `js`, `wasm`, and `wasm-gc` (60 runtime launches per arm).
- Control: the first 20 seeds in the candidate range.
- Treatment: greedy inverse candidate-pool frequency of reference path kinds,
  with each selected path discounted by its count among earlier selected cases.
- Size control: divide the 100 candidates into four rank quartiles by generated
  source line count (ties ordered by seed). The treatment must select the same
  count from each quartile as the control.
- Run order: treatment first, then control, to counterbalance the two
  sequential-first exploratory cohorts and one guided-first cohort.
- Timeout: 30 seconds per Moon command, as configured by the runner.

## Reported outcomes

Primary descriptive outcome: distinct reference interpreter path kinds in
each 20-program arm. This is not backend runtime coverage. Both arms must
record exactly 60 runtime launches and identical source-size quartile counts;
otherwise the comparison is invalid. Secondary outcomes are unique generated
program bodies, mean and maximum source lines, findings, arm wall time, and
candidate prescreen time. Preserve any unexpected case through the existing
finding corpus.

Do not change the seed range, depth, budget, backend matrix, selection rule,
quartile assignment, or metrics after inspecting results. Report failures,
timeouts, and invalid budgets as observed. This single cohort cannot establish
defect-finding probability, MoonBit language coverage, or statistical
significance. No compiler defect is assumed.
