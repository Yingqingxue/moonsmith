# Depth-9 generated corpus scan, cohort 2 — 2026-10-20

This is a bounded exploratory differential scan, not a compiler-bug discovery
claim.

## Protocol and result

- MoonSmith revision: `1b7c8c73d5944a8a06343d64922e0511dc76f61b`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20100–20129` (30 fresh generated program bodies)
- Generator depth: 9
- Targets: JavaScript, Wasm, Wasm-GC; 30-second per-target timeout
- Reference checks: 30/30; Target Parity passes: 30/30
- Backend executions: 90; all 30 cases were `consistent`
- Compile/runtime failures, timeouts, output/reference mismatches,
  environment/harness errors, and source-limit exclusions: 0
- Maximum source size: 10,253 lines
- The reference interpreter observed 56 distinct path-kind labels across the
  cohort; this is not backend runtime coverage.
- Harness digest, start and end:
  `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 192,105 ms

The raw report stores per-seed body hashes, interpreter traces, target parity,
construct counts, and toolchain metadata. SHA-256:
`0c558bd129c2150cfc39ec5c59be013d8c4f844506a4f522cf3faf107b6e5802`.
Re-run with:

```powershell
./scripts/run_batch.ps1 -SeedStart 20100 -Count 30 -Depth 9 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

## Limits

No mismatch or new compiler issue was found in this cohort. The cases exercise
only MoonSmith's generated subset on one older local toolchain. This is a
negative exploratory result, not evidence of compiler correctness; upstream
issues #1322 and #2228 are not MoonSmith discoveries. Raw report:
[`generator_scan_depth9_cohort2_20261020.json`](generator_scan_depth9_cohort2_20261020.json).
