# Ninth standard mixed-depth cross-platform cohort — 2026-10-20

## Result

Workflow [39439726435](https://github.com/Yingqingxue/moonsmith/actions/runs/39439726435)
completed successfully at MoonSmith commit
`76d806cf00414a98432d791aa9ee3965b5e858e4`. It checked a disjoint cohort of
230 generated bodies, seeds `21360–21589`: 100 at depth 4, 100 at depth 6,
and 30 at depth 8. All bodies were executable; there were no generator-limit
exclusions, unexpected findings, or cross-platform mismatches.

The Linux job ran JS, Wasm, and Wasm-GC (690 backend executions); the matching
Windows job ran native-release (230 executions). All 230 reference outcomes,
body hashes, expected outputs, and Linux/Windows comparisons matched. The
workflow installed Moon `0.1.20261016 (1af328f 2026-10-16)` on both runners.
The Linux and Windows harness digests differ because they are recorded from
platform-specific checkouts; the comparison job independently required
matching seeds, source hashes, expected outputs, and successful reports.

This is bounded cross-platform evidence for MoonSmith's generated language
subset and the recorded toolchain/configuration. It does not establish general
compiler correctness or estimate issue-detection recall; no new compiler issue
was found in this cohort.

## Reproduction

From the workflow-dispatch page or CLI, run `MoonSmith CI` on `main` with:

```text
extended_scan=true
extended_windows_crosscheck=true
scan_start=21360
scan_profile=standard
```

The workflow scans the three depth ranges and compares the matching Windows
native-release reports. The raw Linux and Windows reports and comparison
summary are preserved in this directory. SHA-256:

```text
9098e64f0490f0f6aa258a3fbb7c6e67a2c3a20aa0c9a1c80402cc463e4b24f8  cross_platform_summary.json
5fd147cfe4290468236ae58f842f7e9661f8b2c00e2bf315859d7d82f58c7754  linux_depth4_21360_100.json
9d4ff03be0605dd676c8f0a8be92a16b65dec02a9382eba10f6e82e5a41ee381  linux_depth6_21460_100.json
41b38c0faf120075c31f622a7937d6f140df2eddf16b4ce5d0739476bad1e82f  linux_depth8_21560_30.json
e6ec44215af7efaa85c4d240734e761605ee8c7d26b5a5490c371b46415edeac  windows_depth4_21360_100.json
02a665a5cd72d0d6157820d6117598144ff90a63e48006ab9b66d8d725e24c44  windows_depth6_21460_100.json
e3261a47fad9c55c5df4a0fc84d98d01567c0c09a3f211789988c650f0542b90  windows_depth8_21560_30.json
```
