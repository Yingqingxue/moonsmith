# Depth-9 generated corpus scan, cohort 3 — 2026-10-20

This is a bounded exploratory differential scan, not a compiler-bug discovery
claim.

## Protocol and result

- MoonSmith revision: `b403c82bcf19af25f4ab53fb6414fba46576e72a`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20130–20149` (20 distinct generated program bodies)
- Generator depth: 9
- Targets: JavaScript, Wasm, Wasm-GC; 30-second per-target timeout
- Reference checks: 20/20; Target Parity passes: 20/20
- Backend executions: 60; all 20 cases were `consistent`
- Compile/runtime failures, timeouts, output/reference mismatches,
  environment/harness errors, and source-limit exclusions: 0
- Maximum generated source: 8,171 lines
- The reference interpreter observed 56 path-kind labels across the cohort;
  this is not backend runtime instrumentation or backend coverage.
- Harness digest, start and end:
  `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 125,904 ms

The raw report stores per-seed body hashes, interpreter traces, target parity,
construct counts, and toolchain metadata. SHA-256:
`5f7b7fc60107526fd2802f34b5b5e352a92439e2ff9c9364d002d4880b20dadb`.
Re-run with:

```powershell
./scripts/run_batch.ps1 -SeedStart 20130 -Count 20 -Depth 9 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

## Limits

No mismatch or new compiler issue was found in this cohort. It exercises only
MoonSmith's generated subset on one local toolchain. This negative result is
bounded and is not evidence of compiler correctness; upstream issues #1322 and
#2228 are not MoonSmith discoveries. Raw report:
[`generator_scan_depth9_cohort3_20261020.json`](generator_scan_depth9_cohort3_20261020.json).
