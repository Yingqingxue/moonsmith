# Seeded differential scan evidence

Date: 2026-10-09 (Asia/Shanghai)  
Toolchain: `moon 0.1.20260920 (914d7da 2026-09-20)`  
Harness digest: `cfe0663a2d37b86d00f63065b22555d60fff48623aab82dfdc6916ecf7cc6b67`
at both the beginning and end of the first twelve selected runs. The two
guarded depth-10 runs use digest
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
| `20261009_171554_872` | 8200–8299 | 10 | JS, Wasm, Wasm-GC | 100 | 97 | 291 | 3 | 675,202 ms |
| **Combined** | — | — | — | **1,250** | **1,245** | **2,935** | **5** | **6,209,334 ms** |

The body hashes were compared across all fourteen selected reports: all 1,250
program bodies were distinct. Of these, 1,245 completed reference and backend
checks consistently. Five depth-10 sources (seeds 8163, 8167, 8236, 8238, and
8242) exceeded the runner's 16,300-line safety bound. An earlier unguarded scan
showed MoonBit's `text_segment_excceed` diagnostic at line 16,384 for two such
inputs on all three targets. The guarded runs classified all five as
`generator-limit` before reference/backend execution. There were no backend
disagreements, timeouts, reference mismatches, output mismatches, compiler
failures, or harness errors.

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
- Depth-10 full-matrix runs (230 seeds): all sources contained the probe;
  reference interpreter visited it in 224 cases (success 223, error 224;
  overlap possible). Five size-limited source cases were not interpreted or
  executed.

These path counts come from MoonSmith's reference interpreter. They do not
instrument branch execution inside JS/Wasm/Wasm-GC backends and are not a bug
discovery rate. No compiler defect was found in these runs.

## Windows native CI scan

GitHub Actions run [37973978393](https://github.com/Yingqingxue/moonsmith/actions/runs/37973978393)
for commit `7001786` passed both Linux and Windows jobs. On `windows-latest`,
MSVC `cl.exe` was configured and the native package tests passed. The retained
artifact `moonsmith-windows-native-report` contains a depth-6 native scan of
seeds 9000–9099: 100 unique program bodies (also independently confirmed from
the report's SHA-256 body hashes), 100 reference checks, 100 consistent native
executions, zero unexpected findings, and an unchanged harness digest. The
probe appeared in 89 generated sources. The reference interpreter visited the
modeled success path in 43 cases and error path in 39 (overlap possible); these
are not backend runtime branch counts. No compiler defect was found.

The preceding run [37973349079](https://github.com/Yingqingxue/moonsmith/actions/runs/37973349079)
scanned seeds 9000–9029 (30/30 consistent); the expanded 100-seed run repeats
those seeds and should not be added to the earlier 1,250 unique-body
JS/Wasm/Wasm-GC totals.

The first attempt at this scan (run `37971881681`, commit `f772858`) did not
reach native compilation: a cold Windows generator startup exceeded the
per-seed 10-second timeout. The workflow now allows 60 seconds for Windows seed
generation and batch runs. This was a CI budget issue, not a native compiler
failure; the subsequent run completed the scan and integration checks.

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
./scripts/run_batch.ps1 -SeedStart 8200 -Count 100 -Depth 10
```

The raw 100/100/300/30/100/30/100/30/100/30/100/30/100/100-case JSON reports are machine-local under
`.moonsmith/runs/` and are ignored by Git. This page records their verified
summary; a fresh run is needed to recreate the raw reports on another machine.
