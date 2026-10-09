# Seeded differential scan evidence

Date: 2026-10-09 (Asia/Shanghai)  
Toolchain: `moon 0.1.20260920 (914d7da 2026-09-20)`  
Harness digest: `cfe0663a2d37b86d00f63065b22555d60fff48623aab82dfdc6916ecf7cc6b67`
at both the beginning and end of the first twelve selected runs. The guarded
depth-10 rerun uses digest
`139408356f4636814ff028179bfcf3c351005ba761c052fbdc1eeaec71cfa23e`, also
unchanged from start to end.

## Runs

| Run | Seeds | Depth | Targets | Distinct bodies | Reference checks | Backend executions | Unexpected findings | Duration |
|---|---:|---:|---|---:|---:|---:|---:|---:|
| `20261009_133613_232` | 0–99 | 4 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 0 | 534,291 ms |
| `20261009_142423_321` | 0–99 | 5 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 0 | 543,728 ms |
| `20261009_143600_489` | 1000–1299 | 5 | Wasm | 300 | 300 | 300 | 0 | 947,698 ms |
| `20261009_150151_741` | 2000–2029 | 6 | JS, Wasm, Wasm-GC | 30 | 30 | 90 | 0 | 162,745 ms |
| `20261009_150733_048` | 3000–3099 | 6 | Wasm | 100 | 100 | 100 | 0 | 310,515 ms |
| `20261009_152126_201` | 4000–4029 | 7 | JS, Wasm, Wasm-GC | 30 | 30 | 90 | 0 | 162,050 ms |
| `20261009_152857_146` | 5000–5099 | 7 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 0 | 543,907 ms |
| `20261009_154042_081` | 6000–6029 | 8 | JS, Wasm, Wasm-GC | 30 | 30 | 90 | 0 | 164,444 ms |
| `20261009_154604_335` | 6100–6199 | 8 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 0 | 555,440 ms |
| `20261009_161038_538` | 7000–7029 | 9 | JS, Wasm, Wasm-GC | 30 | 30 | 90 | 0 | 172,209 ms |
| `20261009_161448_637` | 7100–7199 | 9 | JS, Wasm, Wasm-GC | 100 | 100 | 300 | 0 | 586,626 ms |
| `20261009_162727_808` | 8000–8029 | 10 | JS, Wasm, Wasm-GC | 30 | 30 | 90 | 0 | 208,573 ms |
| `20261009_165647_384` | 8100–8199 | 10 | JS, Wasm, Wasm-GC | 100 | 98 | 294 | 2 | 641,906 ms |
| **Combined** | — | — | — | **1,150** | **1,148** | **2,644** | **2** | **5,534,132 ms** |

The body hashes were compared across all thirteen selected reports: all 1,150
program bodies were distinct. Of these, 1,148 completed reference and backend
checks consistently. Two depth-10 sources (seeds 8163 and 8167) exceeded the
runner's 16,300-line safety bound; an earlier unguarded scan showed MoonBit's
`text_segment_excceed` diagnostic at line 16,384 on all three targets. The
guarded rerun classified both as `generator-limit` before reference/backend
execution. There were no backend disagreements, timeouts, reference mismatches,
output mismatches, or harness errors.

## `#valtype`/`raise` probe observations

- Depth-4 full-matrix run: probe source in 43 cases; reference interpreter
  visited the probe in 29 cases (success 18, error 14; overlap is possible).
- Depth-5 full-matrix run: probe source in 67 cases; reference interpreter
  visited the probe in 46 cases (success 20, error 31; overlap is possible).
- Depth-5 Wasm-only run: probe source in 201 cases; reference interpreter
  visited the probe in 140 cases (success 85, error 75; overlap is possible).
- Depth-6 full-matrix run: probe source in 26 cases; reference interpreter
  visited the probe in 21 cases (success 17, error 11; overlap is possible).
- Depth-6 Wasm-only run: probe source in 89 cases; reference interpreter
  visited the probe in 69 cases (success 43, error 40; overlap is possible).
- Depth-7 full-matrix run: all 30 sources contained the probe; reference
  interpreter visited it in 26 cases (success 19, error 19; overlap possible).
- Depth-7 full-matrix run (100 seeds): probe source in 98 cases; reference
  interpreter visited it in 89 cases (success 60, error 68; overlap possible).
- Depth-8 full-matrix run: all 30 sources contained the probe; reference
  interpreter visited it in 28 cases (success 21, error 25; overlap possible).
- Depth-8 full-matrix run (100 seeds): all 100 sources contained the probe;
  reference interpreter visited it in 95 cases (success 86, error 78; overlap
  possible).
- Depth-9 full-matrix run: all 30 sources contained the probe; reference
  interpreter visited it in all 30 cases (success 29, error 26; overlap
  possible).
- Depth-9 full-matrix run (100 seeds): all 100 sources contained the probe;
  reference interpreter visited it in 96 cases (success 94, error 88; overlap
  possible).
- Depth-10 full-matrix run: all 30 sources contained the probe; reference
  interpreter visited it in all 30 cases (success 30, error 30; overlap
  possible).
- Depth-10 full-matrix run (100 seeds): all sources contained the probe; 98
  reference traces visited it (success 98, error 98; overlap possible). The
  two size-limited source cases were not interpreted or executed.

These path counts come from MoonSmith's reference interpreter. They do not
instrument branch execution inside JS/Wasm/Wasm-GC backends and are not a bug
discovery rate. No compiler defect was found in these runs.

## Reproduce

```powershell
./scripts/run_batch.ps1 -SeedStart 0 -Count 100 -Depth 4
./scripts/run_batch.ps1 -SeedStart 0 -Count 100 -Depth 5
./scripts/run_batch.ps1 -SeedStart 1000 -Count 300 -Depth 5 -Targets @('wasm')
./scripts/run_batch.ps1 -SeedStart 2000 -Count 30 -Depth 6
./scripts/run_batch.ps1 -SeedStart 3000 -Count 100 -Depth 6 -Targets @('wasm')
./scripts/run_batch.ps1 -SeedStart 4000 -Count 30 -Depth 7
./scripts/run_batch.ps1 -SeedStart 5000 -Count 100 -Depth 7
./scripts/run_batch.ps1 -SeedStart 6000 -Count 30 -Depth 8
./scripts/run_batch.ps1 -SeedStart 6100 -Count 100 -Depth 8
./scripts/run_batch.ps1 -SeedStart 7000 -Count 30 -Depth 9
./scripts/run_batch.ps1 -SeedStart 7100 -Count 100 -Depth 9
./scripts/run_batch.ps1 -SeedStart 8000 -Count 30 -Depth 10
./scripts/run_batch.ps1 -SeedStart 8100 -Count 100 -Depth 10
```

The raw 100/100/300/30/100/30/100/30/100/30/100/30/100-case JSON reports are machine-local under
`.moonsmith/runs/` and are ignored by Git. This page records their verified
summary; a fresh run is needed to recreate the raw reports on another machine.
