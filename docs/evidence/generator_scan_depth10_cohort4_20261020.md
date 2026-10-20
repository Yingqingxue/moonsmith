# Depth-10 generated corpus scan, cohort 4 — 2026-10-20

This exploratory cohort found no backend difference among programs that passed
the source-size guard; 6/20 seeds were censored before compilation.

## Protocol and result

- MoonSmith revision used: `0ac3b88002912894b3665fa2d0a58b8582b2930e`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20090–20109` (20 unique generated program bodies)
- Generator depth: 10
- Targets: JavaScript, Wasm, and Wasm-GC; 60-second per-target timeout
- Reference checks: 14/20
- Target Parity passes: 14/20 (42 successful backend executions)
- Executable cases: 14/14 were consistent, with no backend failures or mismatches
- Source-size exclusions: 6/20 exceeded the 16,300-line pre-compilation guard;
  they were not compiled and are neither passes nor compiler failures
- Executed source size: 8,348–15,269 lines; all 14 were below the guard
- Largest generated source, including excluded cases: 31,427 lines
- Reference interpreter path-kind labels among executed cases: 55; this is not
  backend runtime coverage
- Harness digest, start and end: `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 108,020 ms
- Raw report: [`generator_scan_depth10_cohort4_20261020.json`](generator_scan_depth10_cohort4_20261020.json)
- Raw report SHA-256: `d661777cb6461fb26d6452d1ca525bf1f1dcddbea47941ba8797061381f34b24`

Reproduce from the repository root:

```powershell
& ./scripts/run_batch.ps1 -SeedStart 20090 -Count 20 -Depth 10 -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 60
```

## Limits

Thirty percent of this cohort was excluded due to generated source size. Results
therefore describe only the 14 executable cases and are not representative of
all requested seeds. This is a bounded negative result on one local toolchain,
not evidence of compiler correctness, issue-detection recall, or a discovery
claim. Upstream reports #1322, #2228, and #2262 remain externally reported
issues.
