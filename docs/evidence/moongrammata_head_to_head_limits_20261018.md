# MoonGrammata comparison: evidence and limits (2026-10-18)

## Sources checked

- MoonGrammata `main` was `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`
  (2026-10-01) when checked. The source reviewed is its
  [`examples/benchmark/main.mbt`](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/examples/benchmark/main.mbt)
  and [`docs/BENCHMARK.md`](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/docs/BENCHMARK.md).
- The benchmark target accepts a framed `BEGIN[...]END` command document,
  reports document/command features, and contains a known `ABCD` ordering
  failure. Its two arms are a 2,000-execution single-byte mutation baseline
  and a 2,000-execution grammar/corpus-feedback campaign.
- The upstream report records 4 features, 3 signatures, and no failure for the
  byte baseline, versus 17 features, 147 signatures, and one known failure for
  structured feedback. It explicitly reports logical counts, not throughput.
- MoonSmith's registered comparison instead selects 20 programs from a pool
  of 100 MoonSmith-generated MoonBit programs. Its primary measure is distinct
  paths visited by MoonSmith's reference evaluator; both arms then perform 60
  backend executions. The source-size-matched cohorts recorded 53 vs 52,
  55 vs 51, and 53 vs 53 paths (guided vs sequential). The 100-candidate
  prescreen is additional work. See the
  [first cohort](semantic_selection_size_match_20261014.md),
  [second cohort](semantic_selection_replication_20261014.md), and
  [third cohort](semantic_selection_hosted_replication2_20261016.md).

## What this does and does not establish

MoonGrammata's published example is evidence that its structured campaign
beats a one-byte mutation baseline on that particular framed-command target.
MoonSmith's cohorts are evidence about reference-path diversity when selecting
among its own generated MoonBit programs. These are different generators,
input families, target functions, feedback features, and outcome measures.
Comparing `17 features` directly with `53 reference paths`, or comparing their
failure counts, would be invalid. Neither data set establishes an overall
bug-finding advantage over the other project.

There is also an execution-model difference: the reviewed MoonGrammata 0.1.1
scope describes controlled in-process target callbacks and excludes native
process isolation/crash-signal capture; MoonSmith launches compiler/backend
processes and classifies their exits. This is a narrow capability boundary,
not a substitute for a common-effectiveness benchmark.

## Requirement for a valid head-to-head

A meaningful head-to-head still requires a mutually supported workload and a
pre-registered protocol: the same canonical candidate corpus or grammar, the
same target and feedback-feature ontology, equal target-execution and wall-clock
budgets, fixed seeds and timeouts, and an identical injected-fault/known-failure
contract. Report invalid inputs, target invocations, unique valid cases,
features, preserved failures, and total orchestration cost separately. A
process-isolated compiler target must not be silently replaced with an
in-process toy target, and any in-process-only result must be labelled as such.

An experimental fixed-pool adapter now connects the MoonGrammata campaign API
to two existing MoonSmith candidate-pool reports. Its exact result and
limitations are in the
[fixed-pool selection evidence](moongrammata_fixed_pool_selection_20261018.md).
This is a narrow, cached-feature selection comparison—not the common live target,
process-isolated workload, or equal end-to-end cost required above. The evidence
does **not** establish that MoonSmith is more effective overall.

A follow-up now executes all three selected arms through the same current
MoonSmith verifier on a matched, unique-candidate subset. One current cohort
showed the MoonGrammata arm tying sequential selection on live reference-path
diversity and trailing semantic-guided selection by two paths, with no backend
disagreements in any arm. This is a post-selection blind check using cached
feedback for the MoonGrammata selection phase—not an online, live-feedback
head-to-head. See the [live selected-outcomes record](moongrammata_live_selected_outcomes_20261018.md)
for the exact protocol, sample counts, and limitations.
