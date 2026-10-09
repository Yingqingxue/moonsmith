# Seeded differential scan evidence

Date: 2026-10-09 (Asia/Shanghai)  
Toolchain: `moon 0.1.20260920 (914d7da 2026-09-20)`  
Harness digest: `cfe0663a2d37b86d00f63065b22555d60fff48623aab82dfdc6916ecf7cc6b67`
at both the beginning and end of every run.

## Runs

| Run | Seeds | Depth | Targets | Distinct bodies | Reference checks | Backend executions | Unexpected findings | Duration |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| `20261009_133613_232` | 0–99 | 4 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 0 | 534,291 ms |
| `20261009_142423_321` | 0–99 | 5 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 0 | 543,728 ms |
| `20261009_143600_489` | 1000–1299 | 5 | Wasm | 300 | 300 | 300 | 0 | 947,698 ms |
| `20261009_145621_257` | 2000–2029 | 6 | Wasm | 30 | 30 | 30 | 0 | 92,701 ms |
| **Combined** | — | — | — | **530** | **530** | **930** | **0** | **2,118,418 ms** |

The body hashes were compared across all four reports: all 530 program bodies
were distinct. Every case was `consistent`; no compile/runtime failures,
timeouts, reference mismatches, output mismatches, or harness errors were
reported.

## `#valtype`/`raise` probe observations

- Depth-4 full-matrix run: probe source in 43 cases; reference interpreter
  visited the probe in 29 cases (success 18, error 14; overlap is possible).
- Depth-5 full-matrix run: probe source in 67 cases; reference interpreter
  visited the probe in 46 cases (success 20, error 31; overlap is possible).
- Depth-5 Wasm-only run: probe source in 201 cases; reference interpreter
  visited the probe in 140 cases (success 85, error 75; overlap is possible).
- Depth-6 Wasm-only run: probe source in 26 cases; reference interpreter
  visited the probe in 21 cases (success 17, error 11; overlap is possible).

These path counts come from MoonSmith's reference interpreter. They do not
instrument branch execution inside JS/Wasm/Wasm-GC backends and are not a bug
discovery rate. No compiler defect was found in these runs.

## Reproduce

```powershell
./scripts/run_batch.ps1 -SeedStart 0 -Count 100 -Depth 4
./scripts/run_batch.ps1 -SeedStart 0 -Count 100 -Depth 5
./scripts/run_batch.ps1 -SeedStart 1000 -Count 300 -Depth 5 -Targets @('wasm')
./scripts/run_batch.ps1 -SeedStart 2000 -Count 30 -Depth 6 -Targets @('wasm')
```

The raw 100/100/300/30-case JSON reports are machine-local under
`.moonsmith/runs/` and are ignored by Git. This page records their verified
summary; a fresh run is needed to recreate the raw reports on another machine.
