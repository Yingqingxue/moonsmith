# Seeded differential scan evidence

Dates: 2026-10-09 to 2026-10-10 (Asia/Shanghai); GitHub runner-generated run IDs use UTC.
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

GitHub Actions run [37978979627](https://github.com/Yingqingxue/moonsmith/actions/runs/37978979627)
for commit `01cbfa2` passed both Linux and Windows jobs. On `windows-latest`,
MSVC `cl.exe` was configured and the native package tests passed. The retained
artifact `moonsmith-windows-native-report` contains a depth-6 native scan of
seeds 9000–9099: 100 unique program bodies (also independently confirmed from
the report's SHA-256 body hashes), 100 reference checks, 100 consistent native
executions, zero unexpected findings, and an unchanged harness digest. The
probe appeared in 89 generated sources. The reference interpreter visited the
modeled success path in 43 cases and error path in 39 (overlap possible); these
are not backend runtime branch counts. No compiler defect was found.

The 100-seed depth-6 run repeats seeds 9000–9029 from the preceding
[30-seed scan](https://github.com/Yingqingxue/moonsmith/actions/runs/37973349079)
and should not be added to the earlier 1,250 unique-body JS/Wasm/Wasm-GC totals.
The same CI run also added a deeper native scan: seeds 9200–9229 at depth 8
completed 30 reference checks and 30 consistent native executions in 59,285 ms,
with zero unexpected findings and a stable harness digest. All 30 sources
contained the probe; reference traces visited its modeled success path in 29
cases and error path in 24 (overlap possible). Body-hash checks show these 30
cases are distinct. Cross-report body-hash comparison confirms all 130 bodies
across both scans in run `37977586946` are unique; each was reference-checked
and agreed with native. These two depth/seed cohorts are not a substitute for
broader native fuzzing. Run `37978979627` repeated the same corpus and passed
after the PRNG reference-vector tests were added.

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

## Depth-11 size-boundary probe (2026-10-10)

Run `20261009_212300_782` tested seeds 8300–8399 at requested depth 11 across
JS, Wasm, and Wasm-GC. The 100 generated program bodies were unique and the
harness digest was unchanged. Only 29 programs were below the runner's 16,300
line safety bound; those 29 passed the reference check and all three backends
(87 executions). The other 71 were classified as `generator-limit` before
reference evaluation or compilation; their emitted sources ranged above the
bound, with a maximum of 44,034 lines. There were no compiler/runtime failures,
timeouts, differential mismatches, reference mismatches, or harness errors.

This is evidence that depth 11 is currently an unreliable operating range for
the generator, not evidence of a compiler problem. The existing safety check
worked as intended and kept oversized sources out of the compiler. Until the
generator has a size-aware budget, depth 10 or below is the practical range;
depth 10 itself still had 5 `generator-limit` results among 230 prior seeds.
Raw report: `.moonsmith/runs/batch_20261009_212300_782.json` (ignored and local
only).

## Depth-10 follow-up (2026-10-10)

Run `20261009_212902_452` tested seeds 8400–8499 at depth 10 across the same
three targets. It completed in 668,768 ms with 99 reference checks and 297
consistent backend executions; seed 8482 emitted 16,816 lines and was safely
classified as `generator-limit`. There were no compiler/runtime failures,
timeouts, mismatches, or harness changes. All 100 sources contained the
`#valtype`/`raise` probe; the reference trace visited each modeled success and
error path in 98 cases (these are interpreter counts, not backend coverage).

Cross-report SHA-256 comparison of this cohort against the previous fourteen
depth-4–10 runs confirms all 1,350 source bodies are distinct. The combined
depth-4–10 evidence is therefore 1,344 checked/consistent cases, 3,232 backend
executions, and six explicit size-limit rejections. The depth-11 scan above is
kept separate and not included in these totals. Raw report:
`.moonsmith/runs/batch_20261009_212902_452.json` (ignored and local only).

## Broader depth-5 and depth-6 follow-ups (2026-10-10)

Run `20261009_214412_087` scanned seeds 10000–10499 at depth 5 across JS,
Wasm, and Wasm-GC. All 500 distinct bodies passed reference evaluation and
1,500 backend executions in 2,779,274 ms. The probe appeared in 319 sources;
the reference trace visited it in 220 cases (success 118, error 133; overlap
possible). There were no size limits, failures, mismatches, or harness changes.

Run `20261009_224035_689` scanned seeds 11000–11099 at depth 6 across the same
three targets. All 100 distinct bodies passed reference evaluation and 300
backend executions in 531,433 ms. All cases now report source line counts;
the largest source was 752 lines. The probe appeared in 90 sources, with
reference traces visiting it in 68 cases (success 45, error 36; overlap
possible). There were no size limits, failures, mismatches, or harness changes.

Cross-report SHA-256 comparison across the original fourteen depth-4–10 runs
and these three follow-ups (the 100-seed depth-10, 500-seed depth-5, and
100-seed depth-6 runs) confirms 1,950 unique bodies, 1,944 reference-checked
and consistent cases, 5,032 backend executions, and six explicit
`generator-limit` rejections. Depth-11 data above remains separate. Raw reports
are local and ignored at `.moonsmith/runs/batch_20261009_214412_087.json` and
`.moonsmith/runs/batch_20261009_224035_689.json`.

Run `20261009_225236_634` added 100 depth-7 full-matrix cases (seeds
12000–12099). All 100 unique bodies passed reference evaluation and 300
backend executions in 419,386 ms. The schema-6 batch measured every source;
the maximum was 1,685 lines. The probe appeared in 97 sources and was visited
by the reference interpreter in 79 cases (success 56, error 65; overlap
possible). There were no size limits, failures, mismatches, or harness changes.

Cross-report SHA-256 comparison of the fourteen original depth-4–10 runs and
all four follow-ups confirms 2,050 unique bodies, 2,044 reference-checked and
consistent cases, 5,332 backend executions, and six explicit size-limit
rejections. The depth-11 cohort remains outside these totals. Raw report:
`.moonsmith/runs/batch_20261009_225236_634.json` (ignored and local only).

Run `20261009_230253_164` added 100 depth-8 full-matrix cases (seeds
13000–13099). All 100 unique bodies passed reference evaluation and 300
backend executions in 430,266 ms. The schema-6 batch measured every source;
the maximum was 4,221 lines. All sources contained the probe, and the reference
trace visited it in 97 cases (success 84, error 90; overlap possible). There
were no size limits, failures, mismatches, or harness changes.

Cross-report SHA-256 comparison of the fourteen original depth-4–10 runs and
all five follow-ups confirms 2,150 unique bodies, 2,144 reference-checked and
consistent cases, 5,632 backend executions, and six explicit size-limit
rejections. The depth-11 cohort remains separate. Raw report:
`.moonsmith/runs/batch_20261009_230253_164.json` (ignored and local only).

## Depth-9 follow-up (2026-10-10)

Run `20261009_231924_625` scanned seeds 14000–14099 at depth 9 across JS,
Wasm, and Wasm-GC. All 100 distinct bodies passed reference evaluation and
300 backend executions in 609,965 ms. The schema-6 batch measured every
source; the maximum was 8,862 lines. All 100 sources contained the probe, and
the reference trace visited it in 97 cases (success 92, error 94; overlap
possible). There were no size limits, failures, mismatches, or harness changes.

Cross-report SHA-256 comparison of the fourteen original depth-4–10 runs and
all six follow-ups confirms 2,250 unique bodies, 2,244 reference-checked and
consistent cases, 5,932 backend executions, and six explicit size-limit
rejections. The depth-11 cohort remains separate. Raw report:
`.moonsmith/runs/batch_20261009_231924_625.json` (ignored and local only).

## Depth-10 follow-up (2026-10-10)

Run `20261009_233158_232` scanned seeds 15000–15099 at depth 10 across JS,
Wasm, and Wasm-GC. Ninety-seven distinct bodies passed reference evaluation
and 291 backend executions in 672,921 ms. Three sources exceeded the 16,300
line safety bound and were classified as `generator-limit` before reference
evaluation or compilation; the largest had 21,308 lines. The schema-6 batch
measured all 100 sources. All contained the probe; reference traces visited it
in 97 cases (success 97, error 95; overlap possible). There were no compiler
failures, timeouts, mismatches, or harness changes.

Cross-report SHA-256 comparison of the fourteen original depth-4–10 runs and
all seven follow-ups confirms 2,350 unique bodies, 2,341 reference-checked and
consistent cases, 6,223 backend executions, and nine explicit size-limit
rejections. Depth 11 remains a separate cohort. Raw report:
`.moonsmith/runs/batch_20261009_233158_232.json` (ignored and local only).

Run `20261009_234550_219` added 200 depth-10 seeds (16000–16199). All 200
bodies were unique, with line counts recorded; the largest had 21,980 lines.
One hundred ninety-seven cases passed reference evaluation and 591 backend
executions in 1,346,965 ms. Three inputs were rejected by the 16,300-line
guard before reference evaluation or compilation. The probe appeared in all
200 sources; 196 reference traces visited it (success 193, error 194; overlap
possible). There were no other findings or harness changes.

Cross-report comparison now covers the fourteen original depth-4–10 runs and
all eight follow-ups: 2,550 unique program bodies, 2,538 reference-checked and
consistent cases, 6,814 backend executions, and twelve size-limit rejections.
The six depth-10 cohorts contain 630 samples; 12 exceeded the source bound.
Depth-11 remains separate. Raw report:
`.moonsmith/runs/batch_20261009_234550_219.json` (ignored and local only).

Run `20261010_001035_699` added 200 full-matrix depth-9 seeds (17000–17199).
All 200 bodies passed reference evaluation and 600 backend executions in
1,205,945 ms; all source line counts were recorded, with a maximum of 10,230.
The probe occurred in all sources and was visited in all 200 reference traces
(success 196, error 191; overlap possible). No size limits, failures,
mismatches, or harness changes occurred. Raw report:
`.moonsmith/runs/batch_20261010_001035_699.json` (ignored and local only).

Cross-report SHA-256 comparison of the fourteen original runs and all nine
follow-ups now confirms 2,750 unique bodies, 2,738 reference-checked and
consistent cases, 7,414 backend executions, and twelve explicit size-limit
rejections. The depth-9 cohorts contain 430 samples, all reference-checked;
the depth-10 cohorts remain 630 samples, with twelve size-limit rejections.
Depth 11 remains separate.
