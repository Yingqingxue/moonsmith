# MoonGrammata synchronous live-target prototype (2026-10-18)

## Scope

This prototype replaces the selection benchmark's cached target annotations
with a synchronous MoonGrammata `Target` callback. On each callback, the JS
host launches `scripts/verify_seed.ps1` through `pwsh`, regenerates the
MoonSmith source for that candidate seed, runs the reference trace and the
configured backends, then returns the observed reference-path, finding, and
backend-outcome features to `run_campaign` before its next scheduling step.
The verifier duration is also passed as the observation's coarse `cost_class`.

The campaign still selects integer identifiers from a finite, prebuilt pool;
this is not a grammar-native generator or an open-ended fuzzing campaign. The
sequential and semantic-guided comparison arms remain offline. The prototype
therefore demonstrates live feedback wiring only, not a fair effectiveness,
throughput, or bug-finding comparison. For live runs, cached-arm intersection
metrics are set to `null` rather than presented as comparable outcomes.

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
- Three local smoke runs used the real `scripts/verify_seed.ps1`, the same
  candidate-pool report from run `39113950702`, and targets JS, Wasm, and
  Wasm-GC, with campaign budget 4. Run seed `351882` completed 4/4 callbacks,
  0 verifier-bridge failures, 46 observed path kinds, and 28,890 ms aggregate
  verifier wall time. Seed `351883` completed 4/4 callbacks, 0 bridge
  failures, 42 observed path kinds, and 26,190 ms aggregate verifier wall time.
  Seed `351884` completed 4/4 callbacks, 0 bridge failures, 47 observed path
  kinds, and 27,816 ms aggregate verifier wall time. All three reported
  `consistent` and all three backend statuses as `succeeded`.

The three four-execution smoke runs are too small and too seed-specific to
estimate effectiveness. The measured duration includes process startup,
generation, reference tracing, and backend build/execution; it is not a
compiler-only or per-target benchmark and was not matched against sequential
and semantic-guided campaigns under equal wall-clock budgets.

## Remaining work

1. Move from fixed seed IDs to a generator whose mutations create new valid
   MoonSmith programs, while preserving reproducible seeds and source-level
   provenance.
2. Run a matched sequential / semantic-guided / MoonGrammata experiment with
   the same per-target timeout, evaluation budget, candidate source-size
   strata, and independent campaign seeds. Include wall-clock and verifier
   cost in the stopping budget, not just callback counts.
3. Repeat across multiple preregistered seeds and report unique reference
   paths, backend divergence/crashes, verifier outcomes, and total generation
   and verification costs. Keep all raw run artifacts and report failures as
   well as successes.

No new MoonBit compiler issue is claimed by this prototype.
