# Optional MoonReduce checker adapter

MoonSmith's built-in reducer edits its own typed generated AST. It does not
reduce arbitrary MoonBit source. For a saved finding that already has a
reproducer, `scripts/moonreduce_checker.ps1` exposes MoonSmith's backend
verification as the external-checker protocol used by
[MoonReduce](https://github.com/Hing7/moonreduce). MoonReduce remains the
text/JSON reducer; this adapter only decides whether a candidate still
reproduces the exact MoonSmith finding.

The checker takes a saved finding report as a fixed option and receives the
candidate source as its final positional argument. Exit codes follow
MoonReduce's documented checker protocol: `0` means the same finding and
`reductionKey` remain, `1` means the candidate no longer has that exact
finding, and `125` means the result is unknown (for example, the baseline
artifact is invalid or the toolchain is unavailable). The baseline must have
its original `source.mbt` and a valid matching `sourceSha256`; the checker
reuses its seed, depth, backend matrix, timeout, and reference-output contract.

Example from an environment with MoonReduce, PowerShell 7, MoonBit, and this
MoonSmith checkout available:

```sh
moonreduce reduce \
  --input /absolute/path/to/finding/source.mbt \
  --format lines \
  --checker "$(command -v pwsh)" \
  --checker-arg -NoProfile \
  --checker-arg -File \
  --checker-arg /absolute/path/to/moonsmith/scripts/moonreduce_checker.ps1 \
  --checker-arg -BaselineReportPath \
  --checker-arg /absolute/path/to/finding/report.json \
  --out /absolute/path/to/moonreduce-results/finding-reduction \
  --timeout-ms 60000 \
  --max-tests 1000
```

The command uses MoonReduce's line-deletion strategy, so many intermediate
candidates will not parse as MoonBit; the checker treats a changed finding as
`1`, and toolchain/environment failures as `125`. Increase its per-candidate
timeout only when the local compile/run cost requires it. Prefer MoonSmith's
typed AST reducer for generated cases, since it preserves syntax structure.

`scripts/test_cli.ps1` tests the protocol with a deliberately injected
output mismatch: it checks a preserved candidate (`0`), a candidate that loses
the mismatch (`1`), and an unverifiable/hashless baseline (`125`). This is
adapter-contract testing, not a compiler-bug discovery. MoonReduce's own CLI is
documented for Linux; this repository has not yet run a full end-to-end
reduction through an installed MoonReduce binary, so the example is an
integration path rather than a validated performance result.
