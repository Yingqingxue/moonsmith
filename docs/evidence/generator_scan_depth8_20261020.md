# Depth-8 generated corpus scan — 2026-10-20

This is a bounded exploratory scan, not a compiler-bug discovery claim.

## Protocol and result

- MoonSmith revision: `928a5613f68b29f9d9ce38320e7084816ea9d49e`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20020–20029` (10 unique generated program bodies)
- Generator depth: 8
- Targets: JavaScript, Wasm, Wasm-GC; 30-second per-target timeout
- Reference checks: 10/10; Target Parity pass: 10/10
- Backend executions: 30; all 10 findings were `consistent`
- Unexpected findings, failures, timeouts, environment failures, and size-limit
  exclusions: 0
- Maximum generated source size: 4,054 lines
- Harness digest, start and end:
  `692420ae44cdbbaa60008dd1c43e242336c2434c759f5968c1f57ea48f1b3fc9`
- Elapsed time: 62,799 ms

The raw report is [generator_scan_depth8_20261020.json](generator_scan_depth8_20261020.json),
SHA-256 `c836127bd9de9e6a4035548ee2185f9796819b55d57a4a15485e092fe2aa8d46`.
It contains per-seed source hashes, reference outcomes, Target Parity results,
and construct/path counts. Re-run with:

```powershell
./scripts/run_batch.ps1 -SeedStart 20020 -Count 10 -Depth 8 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

## Limits

This is a small sample from MoonSmith's supported generated-language subset,
run locally on an older toolchain than hosted CI. The recorded reference-path
counts come from MoonSmith's interpreter and are not backend runtime coverage.
It found no new compiler issue; #1322 and #2228 remain upstream-reported cases
and are not credited as MoonSmith discoveries. Ten clean cases cannot establish
that a compiler is free of defects.
