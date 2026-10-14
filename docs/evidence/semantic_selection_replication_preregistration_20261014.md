# Preregistered replication: source-size-matched semantic selection (2026-10-14)

This is a fresh replication of the committed source-size-matched selection
protocol. It is fixed before collecting or inspecting this cohort's results.
It does not alter or pool the earlier registered cohort.

## Fixed design

- Candidate seeds: 24220–24319 inclusive (100 consecutive seeds, no overlap
  with the prior 24120–24219 cohort).
- Selection budget: 20 programs per arm; depth 4.
- Backend matrix: `js`, `wasm`, and `wasm-gc` (60 runtime launches per arm).
- Control: the first 20 seeds in this candidate range.
- Treatment: the existing greedy inverse candidate-pool-frequency reference-
  path selector, with previously selected path counts discounted.
- Size control: four generated-source-line rank quartiles, ties ordered by
  seed; treatment must match the control's count in each quartile.
- Run order: control first, then treatment, counterbalancing the preceding
  registered run's treatment-first order.
- Timeout: 30 seconds per Moon command.
- Record the exact MoonBit toolchain version. The previous registered cohort
  used a different environment unless confirmed otherwise; cross-cohort result
  differences must not be attributed to the selector without controlling for
  toolchain version.

## Outcomes and interpretation

Primary descriptive outcome: distinct path kinds visited by MoonSmith's
reference evaluator in each selected arm. This is not compiler-internal
coverage. Secondary outcomes are unique body hashes, source-line counts,
findings, arm durations, and prescreen duration. A valid comparison requires
60 backend executions per arm and matching size-quartile counts.

Do not change this seed range, budget, depth, targets, selection policy, size
matching, or metrics after inspecting results. Report invalid budgets,
timeouts, and unexpected findings as observed. This is one replication, not a
powered statistical study, and cannot establish defect-finding probability.
No compiler defect is presumed or claimed.
