# Preregistered second hosted semantic-selection cohort — 2026-10-16

This is a new, non-overlapping descriptive cohort, fixed after the first
hosted cohort was completed. It is not pooled with the 2026-10-14 cohort; the
first result has been observed, so this follow-up should be read as replication
attempt two rather than a blinded confirmatory test.

## Fixed design

- Candidate seeds: 24320–24419 inclusive (100 consecutive seeds, disjoint from
  the prior 24220–24319 cohort).
- Selection budget: 20 programs per arm; depth 4.
- Backend matrix: `js`, `wasm`, and `wasm-gc` (60 backend executions per arm).
- Control: the first 20 seeds in this candidate range.
- Treatment: the same greedy inverse candidate-pool-frequency reference-path
  selector, with previously selected path counts discounted.
- Size control: match the sequential arm's source-line rank quartile counts,
  with ties ordered by seed.
- Run order: control first, then guided treatment.
- Timeout: 30 seconds per Moon command.
- Record the exact MoonBit toolchain version; do not combine results across
  toolchain versions as if they were one controlled cohort.

## Interpretation rules

Primary descriptive outcome: distinct path kinds visited by MoonSmith's
reference evaluator. This is not compiler-internal coverage. A valid comparison
requires exactly 60 successful backend executions per arm, equal backend
execution budgets, matching size-quartile counts, unchanged harness digest, and
no unexpected findings. Report invalid budgets, timeouts, unavailable targets,
and findings as observed. Include prescreen time as selection overhead.

This second cohort is still small and descriptive; no statistical significance,
bug-finding probability, compiler-bug discovery, or award competitiveness may
be inferred from it. Keep guided selection optional regardless of its outcome;
the outcome only informs whether further study or engineering effort is
warranted.
