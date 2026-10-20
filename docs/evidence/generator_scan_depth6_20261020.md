# Depth-6 generated corpus scan — 2026-10-20

This is a bounded local exploratory scan, not a compiler-bug discovery claim.

## Protocol and result

- MoonSmith revision: `9c3ff7dc4b989fa55f6eb23c74acd92ab48eb418`
- MoonBit toolchain: `0.1.20260920 (914d7da 2026-09-20)`
- Seeds: `20000–20019` (20 unique generated program bodies)
- Generator depth: 6
- Targets: JavaScript, Wasm, Wasm-GC; 30-second per-target timeout
- Reference checks: 20/20; Target Parity pass: 20/20
- Backend executions: 60; all 20 findings were `consistent`
- Unexpected findings, failures, timeouts, environment failures, and size-limit
  exclusions: 0
- Maximum generated source size: 916 lines
- Harness digest, start and end: `692420ae44cdbbaa60008dd1c43e242336c2434c759f5968c1f57ea48f1b3fc9`
- Elapsed time: 127,992 ms

The raw batch report is [generator_scan_depth6_20261020.json](generator_scan_depth6_20261020.json),
SHA-256 `822f868d913e0e28680f973eb22cfc9ba5ac113d1bf78579cf62a4cd599e94da`.
It contains per-seed source hashes, reference outcomes, Target Parity results,
and construct/path counts. Re-run with:

```powershell
./scripts/run_batch.ps1 -SeedStart 20000 -Count 20 -Depth 6 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

## Limits

An initial 100-seed attempt was stopped after it exceeded the practical
interactive time budget; it produced no complete batch report and is excluded.
Seed `20055`, which was being compiled when that attempt was stopped, was
replayed separately and passed all three targets with the same `consistent`
result. This does not establish a compiler hang or defect. The 20-seed scan is
small, uses an older local toolchain than the latest hosted CI, and exercises
only the generator's supported language subset. It found no new compiler
issue; #1322 and #2228 remain upstream-reported cases and are not credited as
MoonSmith discoveries.
