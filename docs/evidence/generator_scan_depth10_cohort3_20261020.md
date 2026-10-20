# Depth-10 generated corpus scan, cohort 3 — 2026-10-20

This small exploratory cohort observed no backend difference among the cases
that passed the source-size guard; half of the requested seeds were censored
before compilation.

## Protocol and result

- MoonSmith revision used: `9db50f38dac666202da17a69892442561a3cc706`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20080–20089` (10 unique generated program bodies)
- Generator depth: 10
- Targets: JavaScript, Wasm, and Wasm-GC; 60-second per-target timeout
- Reference checks: 5/10
- Target Parity passes: 5/10 (15 successful backend executions)
- Executable cases: 5/5 were consistent, with no backend failures or mismatches
- Source-size exclusions: 5/10 exceeded the 16,300-line pre-compilation guard;
  they were not compiled and are neither passes nor compiler failures
- Executed source size: 12,708–15,716 lines; all five were below the guard
- All generated source sizes: 12,708–24,760 lines
- Reference interpreter path-kind labels among executed cases: 55; this is not
  backend runtime coverage
- Harness digest, start and end: `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 42,052 ms
- Raw report: [`generator_scan_depth10_cohort3_20261020.json`](generator_scan_depth10_cohort3_20261020.json)
- Raw report SHA-256: `f8156fc25640a6aca1916845383833dae8b38be29c0f2f40475068d3a0a0d010`

Reproduce from the repository root:

```powershell
& ./scripts/run_batch.ps1 -SeedStart 20080 -Count 10 -Depth 10 -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 60
```

## Limits

Half of this cohort was excluded because of generated source size. The
executed cases therefore cannot be treated as representative of the requested
depth-10 cohort. This is a bounded negative result on one local toolchain, not
evidence of compiler correctness, issue-detection recall, or a discovery
claim. Upstream reports #1322, #2228, and #2262 remain externally reported
issues.
