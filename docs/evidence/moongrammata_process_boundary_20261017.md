# MoonGrammata process-boundary evidence (2026-10-17)

This is a scope comparison plus a MoonSmith regression result, not a head-to-
head effectiveness benchmark.

- MoonGrammata revision reviewed: `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`
- Primary source: [README scope boundaries at that revision](https://github.com/erzhuzi259/MoonGrammata/blob/d9cf3512b636fd45e941f30010d3fceb7cc2e4fc/README.md#scope-boundaries)
- MoonSmith result: [hosted run 39014185307](https://github.com/Yingqingxue/moonsmith/actions/runs/39014185307), source commit `5df8b03af00bdb484df829f5460f938039f9b1ea`
- Runner configuration: Ubuntu 22.04, 8 MiB stack, core dumps disabled, bounded child-process timeout.

At the reviewed revision, MoonGrammata's README says its targets are controlled
in-process functions and lists native process isolation and crash-signal
capture as out of scope. MoonSmith ran the already-public Moon issue #2228
reproducer as a native child and captured exit 139 with empty redirected
stdout, while the JavaScript control produced a stack `RangeError`. This
demonstrates that MoonSmith's process verifier can retain a failure shape that
the documented MoonGrammata 0.1 target model does not directly represent.

Limits: #2228 is an upstream-reported case, not a MoonSmith discovery; a custom
MoonGrammata target or future release could change the boundary; the run does
not compare corpus quality, execution cost, or defect-finding rate. Therefore
this evidence supports a narrow operational distinction, not a claim that
MoonSmith is generally more effective or has eliminated functional overlap.
