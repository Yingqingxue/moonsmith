# Depth-10 generated corpus scan, cohort 2 — 2026-10-20

This is a bounded exploratory scan, not a compiler-bug discovery claim. Half
of the generated programs hit the source-size guard and were not compiled.

## Protocol and result

- MoonSmith revision: `de696979c02ee71c221bb2d715493f43fcd8b6f7`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20060–20079` (20 fresh generated program bodies)
- Generator depth: 10
- Targets: JavaScript, Wasm, Wasm-GC; 30-second per-target timeout
- Reference checks: 10/20; Target Parity passes: 10/20
- Backend executions: 30; all ten executable cases were `consistent`
- Source-size guard exclusions: 10/20; seeds `20062`, `20063`, `20065`,
  `20067`, `20071`, `20072`, `20075`, `20076`, `20078`, and `20079`
- Compile/runtime failures, timeouts, mismatches, environment/harness errors:
  0 among checked cases
- Largest generated source: 29,661 lines; the configured pre-compilation
  limit is 16,300 lines
- Harness digest, start and end:
  `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 85,425 ms

The ten in-limit programs passed reference and three-target checks. The other
ten are censored before compilation, not compiler failures or passes. The raw
report contains per-seed hashes, source lengths, outcomes, and traces. Its
SHA-256 is
`688b906f62b466acd1a8ff4d74c15b57ffa369f4cc5676ac8626a56e9b9097f7`.
Re-run with:

```powershell
./scripts/run_batch.ps1 -SeedStart 20060 -Count 20 -Depth 10 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

## Limits

No new issue was observed among the ten executable cases. The source-size
guard heavily censors this depth-10 cohort, so its executed cases should not
be treated as a representative sample of all generated depth-10 programs.
This is not evidence of compiler correctness; upstream issues #1322 and
#2228 remain external reports. Raw report:
[`generator_scan_depth10_cohort2_20261020.json`](generator_scan_depth10_cohort2_20261020.json).
