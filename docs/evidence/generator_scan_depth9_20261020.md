# Depth-9 generated corpus scan — 2026-10-20

This is a bounded exploratory differential scan, not a compiler-bug discovery
claim.

## Protocol and result

- MoonSmith revision: `aa569e05747bba04c0686f17467e8fe57f77987b`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20030–20049` (20 unique generated program bodies, disjoint from the
  archived depth-6/depth-8 cohorts)
- Generator depth: 9
- Targets: JavaScript, Wasm, Wasm-GC; 30-second per-target timeout
- Reference checks: 20/20; Target Parity pass: 20/20
- Backend executions: 60; all 20 findings were `consistent`
- Compile/runtime failures, timeouts, output/reference mismatches,
  environment/harness errors, and source-limit exclusions: 0
- Maximum generated source size: 8,895 lines
- Harness digest, start and end:
  `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 130,703 ms on the local host

Every case included let/match/if, arithmetic and boolean operators, arrays,
growth and alias updates, functions, structs, Choice matching, for/while
loops, and both valtype probe kinds. The reference interpreter observed 55
distinct path-kind labels across the cohort; this is not backend runtime
coverage.

The raw report contains per-seed generated source hashes, reference outcomes,
Target Parity results, path/construct counts, and toolchain metadata. Its
SHA-256 is
`b208dbfdb8312fb66ae5da250c68209215b3fcc15dc7656d3897e8f3a1532b4a`.
Re-run with:

```powershell
./scripts/run_batch.ps1 -SeedStart 20030 -Count 20 -Depth 9 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

## Limits

This scan found no new compiler issue. It samples only MoonSmith's generated
language subset and one older local MoonBit toolchain. Twenty consistent
programs do not establish that a compiler is free of defects; upstream
issues #1322 and #2228 remain externally reported cases and are not credited
as MoonSmith discoveries. Raw report:
[`generator_scan_depth9_20261020.json`](generator_scan_depth9_20261020.json).
