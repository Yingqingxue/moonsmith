# Depth-9 generated corpus scan, cohort 4 — 2026-10-20

This bounded exploratory scan did not discover a new compiler issue.

## Protocol and result

- MoonSmith revision used: `4f984ae98bf225d943a86bdb3fe719f2ce321578`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20150–20169` (20 unique generated program bodies)
- Generator depth: 9
- Targets: JavaScript, Wasm, and Wasm-GC; 30-second per-target timeout
- Reference checks: 20/20
- Target Parity passes: 20/20
- Backend executions: 60; all cases were `consistent`
- Failures, mismatches, timeouts, harness errors, and source-limit exclusions: 0
- Source size: 609–9,590 lines
- Reference interpreter path-kind labels observed: 56; this is not backend runtime coverage
- Harness digest, start and end: `e25b260d61b943a1570ba7391a650e4c892805e1903b4ee4b325ed53da16a703`
- Elapsed time: 132,730 ms
- Raw batch report: [`generator_scan_depth9_cohort4_20261020.json`](generator_scan_depth9_cohort4_20261020.json)
- Original run artifact: `.moonsmith/runs/batch_20261020_125015_673.json`
- Raw report SHA-256: `534a43ba0195763240182bba3ea085c6fbb4bb20d8ba192faeb9505cf9d39cb7`

Reproduce from the repository root:

```powershell
pwsh -NoProfile -Command "& './scripts/run_batch.ps1' -SeedStart 20150 -Count 20 -Depth 9 -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30"
```

## Limits

No new compiler difference was observed. This is a bounded scan of MoonSmith's
generated subset on one local toolchain, not evidence of compiler correctness
or a discovery claim. The user's untracked proposal draft was not modified.
Upstream reports #1322 and #2228 remain externally reported issues, not
MoonSmith discoveries.
