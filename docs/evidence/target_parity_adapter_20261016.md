# Target Parity adapter smoke evidence

Date: 2026-10-16 (Asia/Shanghai)

This note records a local end-to-end check of the MoonSmith per-seed oracle
adapter to the pinned, currently published
`zhangbowen2006/moonbit-target-parity@0.5.0` dependency. The upstream GitHub
main branch declares 0.5.1, but that version is not available from the
Mooncakes registry at validation time, so the project pins the latest
registry-published release rather than relying on a local checkout/cache.
The adapter only invokes Target Parity when it has at least two successful
backend observations with exit code 0. It supplies the MoonSmith reference
output as an expected-result contract when available. Compiler failure,
runtime failure, timeout, and unavailable-toolchain states remain classified by
MoonSmith and are not converted into normal observations.

## Matching generated case

Command:

```powershell
pwsh -NoProfile -Command {
  $raw = & ./scripts/verify_seed.ps1 -Seed 2147483647 -Depth 3 `
    -Targets @('js','wasm','wasm-gc') -NoPersist
  $report = $raw | ConvertFrom-Json
  $report | Select-Object finding,referenceChecked,targetParity
}
```

Observed MoonSmith finding: `consistent`; reference checked: `true`; Target
Parity status: `pass`; compared targets: `js`, `wasm`, and `wasm-gc`; no missing
targets or differences.

## Deliberately injected common-mode wrong output

Command:

```powershell
pwsh -NoProfile -Command {
  $raw = & ./scripts/verify_seed.ps1 -Seed 42 -Depth 4 `
    -InjectCommonWrongOutput '999' -NoPersist
  $report = $raw | ConvertFrom-Json
  $report | Select-Object finding,targetParity
}
```

Observed MoonSmith finding: `reference-mismatch`; Target Parity status:
`divergent`. All three backends reported `999\n`, while the reference
expectation was `-23\n`. This demonstrates independent reporting of a common-mode
wrong result; it is an injected test fault, not a real MoonBit compiler bug.

## Validation boundary

`moon check --deny-warn` passed. The main package's 107 tests passed separately
on JS, Wasm, and Wasm-GC. The reference, reducer, and CLI integration scripts
passed. Batch schema 11 preserves each per-seed Target Parity report, and the
fixed nightly gate requires a pass for every successful target matrix. The
two-seed CLI smoke report recorded two per-case passes; the batch-report suite
also checks that a non-passing parity case is rejected. The local Windows host
has no C compiler, so native tests were not available here. A fresh remote CI
run for the published dependency and batch-schema changes is still required.
