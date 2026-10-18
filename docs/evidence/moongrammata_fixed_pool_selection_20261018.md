# MoonGrammata on MoonSmith's frozen candidate pools (2026-10-18)

## Question and scope

This is a first executable integration of MoonGrammata 0.1.1's campaign API
with two already-recorded MoonSmith candidate pools. It asks a narrow question:
when both selection approaches see the same 100 generated MoonBit programs and
the same cached reference-path labels, how much path-label diversity appears
among the programs each approach selects? It does not compare compiler bug
finding or end-to-end fuzzer effectiveness.

The isolated MoonBit benchmark imports
[`erzhuzi259/moongrammata@0.1.1`](https://github.com/erzhuzi259/MoonGrammata/tree/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc)
only in `benchmarks/moongrammata_selection`; MoonSmith's production module has
no new dependency. `scripts/run_moongrammata_selection.ps1` passes the candidate
IDs and their recorded features into a dictionary grammar. The benchmark target
returns the saved reference-path features for each ID, and the campaign is
seeded with a fixed campaign seed. A repeated-run regression verifies that IDs
stay inside the frozen pool, requested target-evaluation counts are honored,
size-quartile counts agree in the matched subset, and the selected metrics are
deterministic.

## Exploratory results

The two input cohorts were previously run with 100 candidates and 20 selected
programs per MoonSmith arm. In this experiment, MoonGrammata also completed 20
campaign target evaluations, but duplicate candidate evaluations meant that
only 18 and 17 distinct candidates were seen. For a limited size-controlled
comparison, all three arms were then restricted to the intersection of the
observed candidate counts in each source-size quartile. This left only 14 and
10 distinct candidates, respectively.

| Frozen pool | MoonGrammata: 20 evaluations / distinct candidates | Common size-quartile-matched unique budget | Sequential MoonSmith paths | MoonSmith semantic-guided paths | MoonGrammata paths |
| --- | ---: | ---: | ---: | ---: | ---: |
| Seeds 24120–24219 | 20 / 18 | 14 | 52 | 53 | 51 |
| Seeds 24220–24319 | 20 / 17 | 10 | 50 | 55 | 50 |

At the full campaign-evaluation budget, MoonGrammata observed 51 path kinds in
the first pool and 52 in the second. These full-set counts are not size matched.
The size-matched intersection results are the last three columns: the first
cohort has MoonGrammata one path below sequential and two below MoonSmith's
semantic-guided selection; the second ties sequential and is five below the
semantic-guided selection. These are descriptive observations from two fixed
cohorts, not a statistically supported winner.

The MoonSmith input reports record candidate-pool prescreen times of 88.8 s and
91.1 s. Those reference-evaluator costs are included here as context, not
charged to MoonGrammata: its benchmark target looks up cached path labels and
does not re-run the live reference evaluator. The prior MoonSmith result also
performed 60 backend executions per arm; the MoonGrammata campaign performed
zero compiler/backend executions. Therefore these data cannot support claims
about relative total cost, compiler coverage, defects found, or overall
effectiveness. The in-memory lookup is a deliberate limitation imposed by
MoonGrammata's in-process target API; it is not a process-isolated integration.

## Reproduction

The input reports are the artifacts produced by the optional
`semantic_selection_replication` workflow input. The same workflow now runs this
adapter and repeats its determinism/invariant test before uploading both
reports as one artifact. To repeat from a local report:

```powershell
pwsh -File scripts/run_moongrammata_selection.ps1 `
  -InputReport .moonsmith/runs/selection_24120_100_20_d4_size_matched.json `
  -ExecutionBudget 20 -Seed 20261018 `
  -OutputPath .moonsmith/runs/moongrammata_selection_24120_100_20.json

pwsh -File scripts/test_moongrammata_selection.ps1 `
  -InputReport .moonsmith/runs/selection_24120_100_20_d4_size_matched.json `
  -ExecutionBudget 20 -Seed 20261018
```

The separately pinned upstream benchmark at commit
`d9cf3512b636fd45e941f30010d3fceb7cc2e4fc` remains useful ecosystem context,
but its framed-command target and logical benchmark counts are not combined with
these MoonSmith reference-path results. See the
[source-checked limits](moongrammata_head_to_head_limits_20261018.md).
