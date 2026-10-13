# Disjunction corpus check (2026-10-13)

The disjunction (`||`) generator and schema-9 coverage gate were checked in
[GitHub Actions run 38352609842](https://github.com/Yingqingxue/moonsmith/actions/runs/38352609842)
on commit `c27ca2fca229849000ee149be8b888b855f606f3`. The ordinary Linux and
Windows native CI jobs also passed in
[run 38352593110](https://github.com/Yingqingxue/moonsmith/actions/runs/38352593110).
The nightly used MoonBit `0.1.20261012 (748b63c 2026-10-12)` and seeds
14990–15989 at depth 4.

## Results

- All 1,000 generated program bodies were distinct and reference-checked, then
  executed on JS, Wasm, and Wasm-GC (3,000 backend executions). All were
  consistent; there were no unexpected findings, generator limits, harness
  errors, compile failures, runtime failures, timeouts, or output mismatches.
- Schema 9 recorded 15 source cases containing `||`; recomputing the total from
  all 1,000 per-case records also yielded 15, as required by the nightly gate.
- The reference evaluator visited an `or` expression in 8 cases: the right-hand
  side executed in 5 and was skipped by short-circuiting in 3. These are
  reference-interpreter traces, not backend runtime instrumentation.
- The same corpus recorded 402 source cases with the `#valtype`/raise probe,
  234 with direct raise/enum-array composition, and 199 reference traces that
  visited both probe kinds. Those observations likewise do not establish
  compiler-backend branch coverage or a MoonBit compiler defect.
- The report used seeds 14990–15989 at depth 4, completed in 584,381 ms, and
  retained an unchanged harness digest. The uploaded artifact contains both
JSON and standalone HTML reports; the HTML is 231,615 bytes, includes the
`casesWithOr` metric, and has no `<script>` or `<img>` tags (1,086 table rows).

This is fixed-corpus evidence for the current generator revision, not a proof
of language-wide correctness or a defect-finding-rate estimate. In particular,
the fact that the corpus found no mismatch does not establish that all
generated `||` cases behave identically on all MoonBit backends.

## Sampling adjustment

The initial schema-9 corpus above showed that a nonzero-only gate was too weak:
only 15 of 1,000 sources contained `||`. Commit `2a96c432d52e74daea829245e2ece4f548bc20b0`
kept the existing branch selection and changed only the `And`/`Or` choice from
an even split to a 1:2 split favoring `Or`. Its CI passed on Linux and Windows
native in
[run 38354537501](https://github.com/Yingqingxue/moonsmith/actions/runs/38354537501),
and the same-toolchain nightly passed in
[run 38354538754](https://github.com/Yingqingxue/moonsmith/actions/runs/38354538754).
On the same seeds and depth, this produced 357 source cases with `||` and 470
`Or` nodes, versus 15 source cases and 15 nodes before the change. Reference
traces visited an `Or` in 280 cases, with right-hand-side execution in 141 and
short-circuit skipping in 162 (the latter path counts may overlap). All 1,000
bodies remained unique and reference-checked; all 3,000 JS/Wasm/Wasm-GC results
were consistent with no unexpected findings. The existing valtype source,
composition, and combined-trace counts remained 402, 234, and 204 respectively.

This is a distribution change, not evidence that `Or` is universally more
valuable than `And`. The test suite now checks a minimum of 200 `Or`-containing
sources in this fixed 1,000-seed window. Commit `f7de731` strengthened the
nightly summary validator to require at least 20% of the configured corpus
instead of mere nonzero coverage. The stricter validator passed on the same
1,000-seed report in
[run 38355758690](https://github.com/Yingqingxue/moonsmith/actions/runs/38355758690),
and Linux/Windows CI passed in
[run 38355748814](https://github.com/Yingqingxue/moonsmith/actions/runs/38355748814).
The preserved JSON was downloaded and independently checked: the aggregate and
per-case totals both remain 357, above the 200-case floor, with 1,000 unique
bodies, 1,000 reference checks, and zero unexpected findings.

## Additional depth and platform sample

The expanded current-generator workflow
[38356796437](https://github.com/Yingqingxue/moonsmith/actions/runs/38356796437)
passed on commit `f7de731e0f7a2b03000b187893e46043115e2d24` using the same
MoonBit toolchain. It scanned the non-overlapping seeds 15990–16219:

- Depth 4: 100 programs; `||` appeared in 38 sources (55 nodes).
- Depth 6: 100 programs; `||` appeared in 79 sources (219 nodes).
- Depth 8: 30 programs; `||` appeared in all 30 sources (328 nodes).

All 230 distinct bodies passed reference checking and JS/Wasm/Wasm-GC, totaling
690 consistent Linux executions. The matching Windows native-release scan
added 230 consistent executions. The comparison artifact confirms matching
source hashes and expected outputs for all 230 seeds (920 total executions),
with no unexpected findings or harness changes. Native debug is intentionally
not included because the known upstream #1322 signature is handled by its
dedicated regression rather than treated as an ordinary differential mismatch.
