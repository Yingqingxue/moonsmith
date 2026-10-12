# Valtype composition scan — 2026-10-12

Command:

```powershell
./scripts/run_batch.ps1 -SeedStart 44607 -Count 30 -Depth 4 -Targets @('js','wasm','wasm-gc')
```

Toolchain: MoonBit `0.1.20260920 (914d7da 2026-09-20)`.

Results for seeds 44607–44636:

- 30/30 cases were checked by the reference evaluator and consistent.
- All 90 backend executions (30 cases × JS, Wasm, and Wasm-GC) agreed with
  their reference outputs; there were no failures or timeouts.
- The 30 generated program bodies were unique.
- 14 generated sources contained the direct composition where the raise probe's
  input is an enum-array probe. Nine reference traces visited both probe kinds
  during evaluation.
- Runtime was 186,503 ms on this workstation; this is not a benchmark.

The source count is a syntactic corpus-presence check; the reference trace count
is interpreter-path evidence, not backend runtime coverage. No compiler defect
was found. The raw batch report is ignored local data at
`.moonsmith/runs/batch_20261012_065755_458.json` and is not committed.
