# MoonSmith

MoonSmith is a differential-testing and automatic test-case reduction tool for
MoonBit compiler backends.

Current maintainer: [Yingqingxue](https://github.com/Yingqingxue).

The repository is in its first implementation stage. The current vertical
slice provides:

- a small typed expression IR;
- a boolean pattern-match generator, interpreter, printer, and shrinker;
- deterministic generation from an integer seed;
- a printer that emits a self-contained MoonBit program;
- a MoonBit differential oracle with stable failure signatures;
- an IR interpreter that computes an expected output for generated programs;
- bounded subprocess execution, corpus persistence, and batch summaries;
- deterministic, type-preserving AST shrink candidates;
- cross-target tests for generator determinism, classification, and reduction
  invariants.

The reference check can flag the case where all backends agree with each
other but disagree with the expected value. The interpreter itself runs on
MoonBit, so this remains a cross-check rather than an independent formal
semantics.

Run the tests:

```bash
moon test --target js
moon test --target wasm
moon test --target wasm-gc
moon test --target native
```

Print the program generated for seed 42 at depth 4:

```bash
moon run --target js cmd/main 42 4
```

Generate a case, execute it on the three bootstrap backends, and compare the
results:

```powershell
pwsh -File scripts/verify_seed.ps1 -Seed 42 -Depth 4
```

Every generator, build, execution, and oracle subprocess has an independent
timeout (10 seconds by default). Non-consistent findings persist under
`.moonsmith/corpus`; injected findings and missing local prerequisites are kept
in separate `injected` and `environment` collections.

Run a deterministic corpus and save a batch summary under `.moonsmith/runs`:

```powershell
pwsh -File scripts/run_batch.ps1 -SeedStart 0 -Count 100 -Depth 4
```

Exercise the complete mismatch-detection path with an explicitly labelled
fault injection (the command intentionally exits with status 1):

```powershell
pwsh -File scripts/verify_seed.ps1 -Seed 42 -Depth 4 `
  -InjectOutputMismatchTarget wasm-gc
```

Reduce a reproducible generated case. This fixture injects a difference only
while an `if` expression is present, so the reducer must retain that construct:

```powershell
pwsh -File scripts/reduce_case.ps1 -Seed 42 -Depth 4 `
  -InjectOutputMismatchTarget wasm-gc `
  -InjectOnlyWhenSourceContains '(if'
```

The result contains `original.mbt`, `minimal.mbt`, and `reduction.json` under
`.moonsmith/reduced/injected`. Real findings use `.moonsmith/reduced/corpus`.
See [the reduction design](docs/reduction.md) for the preservation rule and
current scope.

See `MoonSmith_项目计划书.md` for the complete project scope and delivery plan.
