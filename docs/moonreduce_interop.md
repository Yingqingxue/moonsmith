# Optional MoonReduce checker adapter

MoonSmith's built-in reducer edits its own typed generated AST. It does not
reduce arbitrary MoonBit source. For a saved finding that already has a
reproducer, `scripts/moonreduce_checker.ps1` exposes MoonSmith's backend
verification as the external-checker protocol used by
[MoonReduce](https://github.com/Hing7/moonreduce). MoonReduce remains the
text/JSON reducer; this adapter only decides whether a candidate still
reproduces the exact MoonSmith finding.

The checker takes a saved finding report as a fixed option and receives the
candidate source as its final positional argument. Only compile failure, runtime
failure, timeout, output mismatch, reference mismatch, and mixed failure are
reducible baselines; consistent runs, environment failures, and empty results
are rejected as unknown rather than being mislabeled as failures. Exit codes follow
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
`1`, and toolchain/environment failures as `125`. MoonReduce names candidates
`unverified.txt`; the adapter makes a temporary `.mbt` copy for `moon run`
(which dispatches on the source extension), then removes that copy without
changing the candidate bytes. Increase its per-candidate timeout only when the
local compile/run cost requires it. Prefer MoonSmith's typed AST reducer for
generated cases, since it preserves syntax structure.

`scripts/test_cli.ps1` tests the protocol with a deliberately injected
output mismatch: it checks a preserved candidate (`0`), a candidate that loses
the mismatch (`1`), and unverifiable baselines (`125`). This is
adapter-contract testing, not a compiler-bug discovery. The manually triggered
[`MoonReduce interoperability` workflow](../.github/workflows/moonreduce-interop.yml)
builds a pinned upstream revision on Ubuntu and exercises both that injected
protocol smoke and the checked-in reproducer for upstream
[moonbitlang/moonbit-docs#1322](https://github.com/moonbitlang/moonbit-docs/issues/1322).

The injected protocol smoke passed in
[workflow run 38941306085](https://github.com/Yingqingxue/moonsmith/actions/runs/38941306085)
on MoonSmith commit `927acd48387ede1d740f47f1ff7aeac364218812`, using
MoonReduce commit `f256f264a2e8853c2e7ec67e3488e61aefaff17d`. It reported
`verified_unchanged`: the one-candidate search accepted no deletions (2,443
bytes before and after), and final replay passed. That run validated the
checker protocol, artifact handling, and replay—not reduction quality.

The follow-up
[workflow run 38965965522](https://github.com/Yingqingxue/moonsmith/actions/runs/38965965522)
on MoonSmith commit `423abdfa9fce0197d6fa468df34b3ce6f20c6b86` exercised the
real externally reported #1322 reproducer with MoonBit
`0.1.20261012` / MoonC `0.10.15+943464bfa`. The native-debug baseline matched
the reported `Machine_of_clam_lower.lower_array_make` ICE signature. MoonReduce
reported `verified_reduction`: 4 accepted candidates over 100 search checks,
275 bytes to 263 bytes (4.36%); there were no unknown results or timeouts, and
its independent final replay passed. Inspecting the original and reduced
artifacts shows that the byte difference is only two blank lines and two
`///|` block separators; every declaration and executable statement remains.
So this result is a verified format-only shrink, not semantic simplification.
The uploaded artifact records this case as originating from upstream issue
#1322, not discovered by MoonSmith. This proves that the adapter and external
checker can preserve and replay this reported failure; it does not show useful
reduction of its program logic, global minimality, or general reducer
effectiveness. The generated-AST reducer remains the primary reducer for
MoonSmith-generated cases; arbitrary-source semantic reduction is still an
unresolved capability boundary.
