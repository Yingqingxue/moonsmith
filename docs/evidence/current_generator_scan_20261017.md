# Current generator scan and Windows cross-check (2026-10-17)

This is a new bounded scan of MoonSmith's current generator, not a compiler-bug
discovery claim.

- Workflow: [MoonSmith CI run 39014342692](https://github.com/Yingqingxue/moonsmith/actions/runs/39014342692)
- Commit: `5df8b03af00bdb484df829f5460f938039f9b1ea`
- Toolchain: `moon 0.1.20261012 (748b63c 2026-10-12)`
- Linux targets: JS, Wasm, Wasm-GC; Windows target: native-release.
- Cohort: seeds 16450–16679, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

| Check | Result |
|---|---:|
| Distinct generated program bodies | 230 / 230 |
| Matching source hashes between Linux and Windows | 230 / 230 |
| Matching reference-expected outputs | 230 / 230 |
| Linux backend executions | 690 |
| Windows native-release executions | 230 |
| Cases consistent on both platforms | 230 / 230 |
| Unexpected findings | 0 |

The scan and report-comparison jobs completed successfully. This is evidence
only for this finite seed cohort, grammar, toolchain, and backend set; it does
not establish compiler correctness or that MoonSmith will find a new defect.
The raw Linux and Windows batch JSON plus the cross-platform summary are
preserved as the workflow's `moonsmith-current-generator-seed-scan`,
`moonsmith-windows-current-generator-crosscheck`, and
`moonsmith-cross-platform-seed-comparison` artifacts.

## Independent follow-up cohort

A second, non-overlapping range was run on the same toolchain and workflow:

- Workflow: [MoonSmith CI run 39016632668](https://github.com/Yingqingxue/moonsmith/actions/runs/39016632668)
- Commit: `424bcfa9a85fc062ab60054a9960ae29bb8e49bd`
- Cohort: seeds 16680–16909, again split into depth 4 (100), depth 6 (100),
  and depth 8 (30).

The Windows native-release cross-check and report-comparison jobs passed. The
summary records 230/230 distinct source bodies within this cohort, identical
Linux/Windows source hashes and reference-expected outputs, 690 Linux
JS/Wasm/Wasm-GC executions, 230 Windows native-release executions, 230/230
cross-platform-consistent cases, and zero unexpected findings. These 1,840
backend executions across both cohorts still yielded no new compiler issue;
they provide bounded negative evidence, not proof that none exists.

## Third independent follow-up cohort

A third non-overlapping range was dispatched with Linux and Windows jobs
enabled:

- Workflow: [MoonSmith CI run 39046264932](https://github.com/Yingqingxue/moonsmith/actions/runs/39046264932)
- Commit: `a4946da56ac3c03e9c5c5a9cea2963b29c8cfeb9`
- Cohort: seeds 16910–17139, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

The workflow, extended Linux scan, Windows native-release cross-check, and
cross-platform report comparison all passed. The summary records 230/230
distinct generated bodies, matching source hashes and expected outputs,
690 Linux JS/Wasm/Wasm-GC executions, 230 Windows native-release executions,
230/230 cross-platform-consistent cases, and zero unexpected findings. The
three independent cohorts now cover seeds 16450–17139 without overlap: 690
programs, 2,070 Linux backend executions, and 690 Windows executions. No new
compiler issue was found in these bounded samples; this remains negative
evidence limited to the sampled generator, seeds, toolchain, and targets.

## Fourth independent follow-up cohort

A fourth non-overlapping range was dispatched with Linux and Windows jobs
enabled:

- Workflow: [MoonSmith CI run 39047215894](https://github.com/Yingqingxue/moonsmith/actions/runs/39047215894)
- Commit: `a4946da56ac3c03e9c5c5a9cea2963b29c8cfeb9`
- Cohort: seeds 17140–17369, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs, including extended Linux scan, Windows native-release
cross-check, and cross-platform report comparison, succeeded. Results again
show 230/230 distinct bodies, matching source hashes and expected outputs,
690 Linux JS/Wasm/Wasm-GC executions, 230 Windows native-release executions,
230/230 cross-platform-consistent cases, and zero unexpected findings. Across
the four independent cohorts the range is 16450–17369 with no gaps or overlap:
920 programs, 2,760 Linux backend executions, and 920 Windows executions.
No new compiler issue was found in these bounded samples.

## Fifth independent follow-up cohort

A fifth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39048540857](https://github.com/Yingqingxue/moonsmith/actions/runs/39048540857)
- Commit: `a4946da56ac3c03e9c5c5a9cea2963b29c8cfeb9`
- Cohort: seeds 17370–17599, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs succeeded. The comparison artifact reports 230/230 distinct
program bodies, matching source hashes and expected outputs, 690 Linux
JS/Wasm/Wasm-GC executions, 230 Windows native-release executions, and zero
unexpected findings. The artifact comparison was also rerun locally with
`compare_batch_reports.ps1` and reproduced the 230-seed result. Across the five
independent cohorts, seeds 16450–17599 are covered without gaps or overlap:
1,150 programs, 3,450 Linux backend executions, and 1,150 Windows executions.
No new compiler issue was found in these samples.
