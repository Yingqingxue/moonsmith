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

Commit `f013ec3` additionally made the nightly gate require both reference
outcomes and reconcile each aggregate to the per-case `referencePathKinds`.
The strict run
[38358007538](https://github.com/Yingqingxue/moonsmith/actions/runs/38358007538)
passed; artifact inspection confirmed 141 cases with `or-rhs-executed` and 162
with `or-rhs-skipped`, matching their aggregate values exactly. Its paired CI
run
[38358006292](https://github.com/Yingqingxue/moonsmith/actions/runs/38358006292)
passed on Linux and Windows.

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

## Observable short-circuit check

Commit `13b57e6` changed generated `Or` source so its RHS runs inside a closure
that increments a captured mutable call counter. The source expects zero calls
when the left side is true and one otherwise, and panics on a violation. This
turns erroneous eager execution into a runtime-visible finding even if the
boolean result itself is unchanged. A unit test checks the emitted guard, and
three local seeds (14990, 14993, and 14995) passed on JS, Wasm, and Wasm-GC;
14993's reference trace covers both OR RHS outcomes.

Remote CI
[38362600738](https://github.com/Yingqingxue/moonsmith/actions/runs/38362600738)
passed on Linux and Windows. The updated nightly
[38362624266](https://github.com/Yingqingxue/moonsmith/actions/runs/38362624266)
again checked 1,000 unique bodies and 3,000 consistent executions: 357 cases
contained 470 OR nodes; 141 cases executed the RHS and 162 skipped it. The
counts matched per-case records, the maximum source had 201 lines, and no
generator-limit finding occurred. A separate paired depth/platform scan
[38362629021](https://github.com/Yingqingxue/moonsmith/actions/runs/38362629021)
passed its Linux/Windows native-release comparison. These results validate the
new generated probe against the sampled toolchain/targets; they are not a claim
of broad backend coverage or an identified compiler defect.

## Conjunction counterpart

The same captured-counter check was added to generated `&&` expressions: the
RHS must execute once when the left side is true and zero times when false.
Local tests passed 86/86 on each of JS, Wasm, and Wasm-GC. Seed 42 at depth 4
contains a generated conjunction and passed reference comparison on all three
targets with output `-23`. This targeted sample does not measure corpus
frequency or native behavior. The schema-9 nightly gate continues to measure
`||` only; no `&&` coverage claim is made. Remote CI validation for this
addition is pending.
