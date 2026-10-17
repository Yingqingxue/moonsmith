# Windows single-target corpus comparison gate — 2026-10-17

This note records a MoonSmith harness correction found while extending the
current-generator scan. It is not a MoonBit compiler issue.

In [workflow run 39012293238](https://github.com/Yingqingxue/moonsmith/actions/runs/39012293238),
the Linux scan and Windows native-release cross-check jobs both completed, but
the final comparison job rejected Windows seed 15990 because its `targetParity`
field was null. That Windows job deliberately runs only `native-release`; a
single-backend report cannot produce the multi-backend Target Parity result.
The comparison helper had incorrectly applied the multi-backend parity gate to
that single-target report.

The failing job's preserved reports were replayed locally through the corrected
comparator: seeds 15990–16219 all matched their generated source hashes and
reference outputs (230 cases; 690 Linux JS/Wasm/Wasm-GC executions and 230
Windows native-release executions). The correction now requires a passing
Target Parity result only when the report itself has multiple targets, and it
does not compare parity objects across the three-target Linux matrix and the
single-target Windows matrix. A regression test accepts a schema-11
single-target report with `targetParity: null` while continuing to reject a
non-passing parity result in the three-target report.

The subsequent [run 39013235369](https://github.com/Yingqingxue/moonsmith/actions/runs/39013235369)
completed all jobs successfully on a fresh cohort, seeds 16220–16449. Its
comparison artifact records 230 matching source hashes and expected outputs,
with all 230 cases consistent on both platforms. This validates the corrected
report gate for that cohort; it does not establish general cross-platform
equivalence outside the tested seeds and toolchain.
