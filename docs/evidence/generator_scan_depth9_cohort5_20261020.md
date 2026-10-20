# Depth-9 generated corpus scan, cohort 5 — 2026-10-20

This bounded exploratory scan found no new compiler difference.

## Protocol and result

- MoonSmith revision used: `e2f46684e02da6fcaa5ae2ad859112044089ddda`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20200–20239` (40 unique generated program bodies)
- Generator depth: 9
- Targets: JavaScript, Wasm, and Wasm-GC; 30-second per-target timeout
- Reference checks: 40/40
- Target Parity passes: 40/40
- Backend executions: 120; all cases were `consistent`
- Failures, mismatches, timeouts, harness errors, and source-limit exclusions: 0
- Source size: 3,547–15,683 lines; none exceeded the 16,300-line guard
- Reference interpreter path-kind labels observed: 56; this is not backend runtime coverage
- Harness digest, start and end: `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 257,660 ms
- Raw report: [`generator_scan_depth9_cohort5_20261020.json`](generator_scan_depth9_cohort5_20261020.json)
- Raw report SHA-256: `10fb772948fbcd5397319f28624c6f0dc65fa337e64750b92c545110f846fdf7`

Reproduce from the repository root:

```powershell
pwsh -NoProfile -Command "& './scripts/run_batch.ps1' -SeedStart 20200 -Count 40 -Depth 9 -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30"
```

## Limits

This expands the bounded sample of MoonSmith's generated grammar on one local
toolchain only. It is not evidence of compiler correctness, issue-detection
recall, or a discovery claim. No backend mismatch or new compiler issue was
observed. Upstream reports #1322, #2228, and #2262 remain externally reported
issues; their known-issue probes are not new MoonSmith discoveries.
