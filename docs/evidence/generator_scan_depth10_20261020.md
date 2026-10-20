# Depth-10 generated corpus scan — 2026-10-20

This is a bounded exploratory scan, not a compiler-bug discovery claim. Four
generated programs hit MoonSmith's source-size guard and were not compiled;
they are exclusions, not backend failures.

## Protocol and result

- MoonSmith revision: `278d0ace26f13257ea82fdde8467f5812f570d6f`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20050–20059` (fresh cohort)
- Generator depth: 10
- Targets: JavaScript, Wasm, Wasm-GC; 30-second per-target timeout
- Reference checks: 6/10; Target Parity pass: 6/10
- Backend executions: 18; all six compiled cases were `consistent`
- Source-size guard exclusions: 4/10 (`20052`, `20054`, `20056`, `20058`)
- Compile/runtime failures, timeouts, mismatches, environment/harness errors:
  0
- Largest source: 24,493 lines; the configured pre-compilation guard is
  16,300 lines
- Harness digest, start and end:
  `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 47,234 ms

Six cases were successfully checked against the reference interpreter and all
three backends. Four were stopped before compilation by the source-size guard;
no compiler behavior is inferred for them. The raw report has per-seed source
hashes, findings, target outcomes, line counts, and interpreter traces. Its
SHA-256 is
`7adfab3d15e10ceb6d88d4f24c5a776fe4b5ada5caf60ecee7dbd945a8e8783c`.
Re-run with:

```powershell
./scripts/run_batch.ps1 -SeedStart 20050 -Count 10 -Depth 10 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

## Limits

No new compiler issue was found among the six executable cases. The four
size-limited cases are censored before backend execution, and this small local
cohort does not establish compiler correctness. Upstream issues #1322 and
#2228 remain externally reported and are not credited as MoonSmith
discoveries. Raw report:
[`generator_scan_depth10_20261020.json`](generator_scan_depth10_20261020.json).
