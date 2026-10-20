# Same-host MoonBit toolchain differential pilot — 2026-10-20

## Question and protocol

This small pilot checks whether a fixed corpus of MoonSmith-generated programs
changes behavior between two explicitly recorded MoonBit toolchains. It is a
toolchain-regression screen, not a claim of a compiler bug discovery or proof
that either compiler is correct.

Both runs used the same detached MoonSmith worktree at commit
`76d806cf00414a98432d791aa9ee3965b5e858e4`, the same harness digest, the same
20 seeds (`21400–21419`), depth 8, three targets (`js`, `wasm`, `wasm-gc`),
and 30-second per-target timeouts. They ran serially on one Windows workstation
with the same host environment. The baseline was Moon `0.1.20260920`
(`moonc 0.10.14+7d59c7ec9`, 2026-09-18); the candidate was Moon `0.1.20261012`
(`moonc 0.10.15+943464bfa`, 2026-10-12), installed into a separate temporary
toolchain home. MoonBit and MoonC changed together; this does not isolate a
single compiler component. The same pinned module dependency cache was reused.

## Result

| Metric | Baseline | Candidate |
| --- | ---: | ---: |
| Reference-checked cases | 20/20 | 20/20 |
| Target Parity passes | 20/20 | 20/20 |
| Consistent cases | 20/20 | 20/20 |
| Unexpected findings, failures, or timeouts | 0 | 0 |
| Source-body hash differences | — | 0/20 |
| Per-seed finding/output/aggregate-signature/Target-Parity differences | — | 0/20 |
| Harness digest | `3e2c2433ab9a88c15a1eace792cc636d28c782b67ce3911dca8d01ff1786420b` | same |
| Batch elapsed time | 123,955 ms | 116,682 ms |

The timings are not a performance comparison: runs were sequential, caches
and startup state were not randomized, and this was not a benchmark protocol.
No compiler difference or new issue was observed in this bounded sample.

## Reproduction

From the repository root, with the two official toolchains installed and
available one at a time on `PATH`:

```powershell
./scripts/run_batch.ps1 -SeedStart 21400 -Count 20 -Depth 8 `
  -Targets @('js','wasm','wasm-gc') -TimeoutSeconds 30
```

Run once with Moon `0.1.20260920` / MoonC `0.10.14+7d59c7ec9` and once with
Moon `0.1.20261012` / MoonC `0.10.15+943464bfa`. Use the checked-in
[`compare_toolchain_reports.ps1`](../../../scripts/compare_toolchain_reports.ps1)
to validate the matched reports and compare each seed's `bodySha256`,
`finding`, `expectedOutput`, `signature`, and `targetParity`:

```powershell
./scripts/compare_toolchain_reports.ps1 `
  -BaselineReport docs/evidence/toolchain_diff_20261020/moon_0.1.20260920_seed21400_depth8.json `
  -CandidateReport docs/evidence/toolchain_diff_20261020/moon_0.1.20261012_seed21400_depth8.json `
  -RequireEquivalent

./scripts/test_toolchain_report_comparison.ps1
```

The test also mutates temporary copies of the report to confirm that outcome
and Target Parity differences are rejected. Those deliberately changed test
fixtures are comparator tests only, not MoonBit compiler findings.

The two raw schema-11 reports are preserved beside this note. Their SHA-256
digests are:

- Baseline: `68e231dbc8a5afd846c1fec6eb644a234f2d76ad5a4aed31c6579bb4cbd5ab8f`
- Candidate: `c97b8aa0c6149c83867b9fdfa89bc1527136a185639633ea8af686c53ff04439`

## Limits

This is a 20-seed sample of MoonSmith's generated language subset, on one host,
one pair of toolchains, and three portable targets. It is not a general
regression guarantee, does not test native backends, and provides no estimate
of compiler-bug detection recall. A future mismatch must be reproduced on both
toolchains with the same source and then minimized before it is treated as a
reportable compiler regression. Public upstream issues #1322, #2228, and #2262
remain externally reported issues, not findings from this experiment.
