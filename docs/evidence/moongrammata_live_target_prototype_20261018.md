# MoonGrammata synchronous live-target prototype (2026-10-18)

## Scope

This prototype adds a synchronous MoonGrammata `Target` callback. On each
callback, the JS host launches `scripts/verify_seed.ps1` through `pwsh`,
regenerates the MoonSmith source for that candidate seed, runs the reference
trace and the configured backends, then returns the observed reference-path,
finding, backend-outcome, and source-size features to `run_campaign` before its
next scheduling step. The verifier duration is also passed as the
observation's coarse `cost_class`.

Two modes are available. `-LiveTarget` selects identifiers from the original
finite candidate pool but verifies them synchronously. The newer
`-LiveGeneratedSeeds` mode instead gives MoonGrammata an integer grammar over
an explicit seed range; generation and mutation can therefore produce seeds
not present in the prior report's pool. The input selection report is used
only for verifier configuration and harness-digest validation in this mode;
its cached candidate outcomes are not given to the target. Each seed
reproducibly regenerates a MoonSmith program at the report's configured depth.
Generated programs that exceed the verifier's source-size safety limit still
produce a `generator-limit` feedback observation, but do not pretend to have a
reference check or backend execution. The output separately counts total live
callbacks, generator-limit observations, reference checks, and attempted
backend executions.

The online modes are still prototypes, not a matched comparison. Sequential
and semantic-guided comparison arms remain offline in this harness. There is
no equal-wall-clock, multi-seed effectiveness or throughput result. For online
runs, cached-arm intersection metrics are set to `null` rather than presented
as comparable outcomes.

## Tests and smoke observations

- `scripts/test_moongrammata_live_target.ps1` passes with a test-only verifier
  that emits path labels absent from the cached pool and alternates between
  consistent and simulated mismatch reports (including a simulated Wasm-GC
  runtime failure). With campaign seed `20261018` and budget 18, all 18
  callbacks ran synchronously, no bridge failed, and the live and cached
  campaigns shared the same deterministic initial 16 executions but diverged
  on the post-initial schedule. This checks that callback results, including
  nonzero verifier findings, rather than cached annotations, reach the corpus
  and can influence later scheduling. It also verifies stale harness metadata
  is rejected before an output report is written. It is a control-flow
  regression test, not a real-target effectiveness result.
- The same test also runs the integer-grammar mode over `100000..1000000`.
  All 18 callbacks are live, emitted seeds stay in range and outside the cached
  pool, runtime paths and source-size feedback are consumed, and the report
  does not expose cached arms as comparable outcomes. A deterministic mock
  generator-limit response verifies it is counted separately from reference
  checks and attempted backend executions.
- Three local smoke runs used the real `scripts/verify_seed.ps1`, the same
  candidate-pool report from run `39113950702`, and targets JS, Wasm, and
  Wasm-GC, with campaign budget 4. Run seed `351882` completed 4/4 callbacks,
  0 verifier-bridge failures, 46 observed path kinds, and 28,890 ms aggregate
  verifier wall time. Seed `351883` completed 4/4 callbacks, 0 bridge
  failures, 42 observed path kinds, and 26,190 ms aggregate verifier wall time.
  Seed `351884` completed 4/4 callbacks, 0 bridge failures, 47 observed path
  kinds, and 27,816 ms aggregate verifier wall time. All three reported
  `consistent` and all three backend statuses as `succeeded`.
- A real generated-seed smoke run used range `100000..101000`, campaign seed
  `351885`, and budget 4. It evaluated seeds `100443`, `100576`, `100403`, and
  `100230` live (4/4, 0 bridge failures), observed 49 reference-path kinds,
  and took 30,681 ms in aggregate. All findings were `consistent`, with JS,
  Wasm, and Wasm-GC succeeding. The observed source-size buckets were
  `50-to-99` and `100-or-more` lines.
- After adding explicit safety-limit accounting, a second real generated-seed
  smoke run used campaign seed `351886` and the same range, budget, and target
  matrix. It evaluated seeds `100652`, `100785`, `100612`, and `100439`: 4 live
  callbacks, 4 reference checks, 12 attempted backend executions, 0
  generator-limit observations, and 0 bridge failures. It observed 49 path
  kinds and took 28,385 ms in aggregate; all findings were `consistent` and
  all three backend statuses succeeded. This remains a four-input smoke test,
  not an effectiveness comparison.

The four-execution smoke runs are too small and too seed-specific to estimate
effectiveness. The measured duration includes process startup, generation,
reference tracing, and backend build/execution; it is not a compiler-only or
per-target benchmark and was not matched against sequential and
semantic-guided campaigns under equal wall-clock budgets.

## Remaining work

1. Build live sequential and semantic-guided control arms against the same
   integer-seed proposal space, target matrix, per-target timeout, and actual
   verifier-cost stopping budget. Define the semantic-guided policy before
   comparing it with MoonGrammata.
2. Repeat across multiple preregistered campaign seeds and report unique reference
   paths, backend divergence/crashes, verifier outcomes, and total generation
   and verification costs. Keep all raw run artifacts and report failures as
   well as successes.

No new MoonBit compiler issue is claimed by this prototype.
