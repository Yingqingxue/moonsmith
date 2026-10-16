# MoonReduce reduction of upstream-reported issue #1322 (2026-10-16 UTC / 2026-10-17 Asia/Shanghai)

This is a hosted end-to-end validation of MoonSmith's external-checker adapter
with MoonReduce on the checked-in reproducer for
[moonbitlang/moonbit-docs#1322](https://github.com/moonbitlang/moonbit-docs/issues/1322).
The compiler issue predates MoonSmith and was reported upstream; this run did
not discover it.

## Reproduction setup

- MoonSmith commit: `423abdfa9fce0197d6fa468df34b3ce6f20c6b86`
- Workflow: [MoonReduce interoperability run 38965965522](https://github.com/Yingqingxue/moonsmith/actions/runs/38965965522)
- MoonReduce source revision: `f256f264a2e8853c2e7ec67e3488e61aefaff17d`
- MoonBit CLI: `0.1.20261012`; MoonC: `0.10.15+943464bfa`
- Backend tested: Linux native debug (`x86_64-unknown-linux-gnu`, `-O0`)
- Fixture: `regressions/issue_1322_native_valtype_enum_array/repro.mbt`
- Baseline classification: `compile-failure`; diagnostic signature includes
  `Machine_of_clam_lower.lower_array_make` and
  `uninitialized non-null GC ref arrays are not lowered`.

The baseline report's source hash is
`ed158d3d5b3dd3888e088e5065b563e65169ad1ca226b27e1a2ca7a3343f5e32`.
MoonSmith created the current-run baseline report and the adapter replayed each
candidate against that exact finding and reduction key; the workflow does not
rely on a potentially stale corpus report.

## Reduction outcome

| Metric | Result |
| --- | ---: |
| MoonReduce status | `verified_reduction` |
| Original / reduced source bytes | 275 / 263 |
| Byte reduction | 4.36% |
| Accepted candidates | 4 |
| Search checks | 100 |
| Baseline / final replay checks | 3 / 3 |
| Unknown results / timeouts | 0 / 0 |
| Independent final replay | passed |
| Stop reason | `strategy_exhausted` |

The outcome establishes that this specific upstream-reported native-debug
failure survived the accepted line deletions and final replay under the saved
MoonSmith finding contract. Inspecting `reduced.txt` against `original.txt`
shows that the 12-byte difference consists only of two blank lines and two
`///|` block separators; all declarations and executable statements remain.
Thus this is a verified **format-only** shrink, not semantic simplification of
the triggering program. `strategy_exhausted` means the configured line-deletion
search ended; it does not prove global minimality. One format-only result is
insufficient to infer general reducer quality, useful reduction rates, or
comparative effectiveness. MoonSmith should present this as an adapter and
case-study result, never as a newly discovered compiler bug or successful
semantic minimization.

The exact final candidate (SHA-256
`ea0af858459ef3bdc94aa1c98069647eac95ea2bb20e0a88d55c293a1962ce71`) was:

```moonbit
enum Kind {
  Ref(String)
}
#valtype
struct Entry {
  id : Int
  kind : Kind
}
fn main {
  let values : Array[Entry] = []
  values.push({ id: 0, kind: Kind::Ref("x") })
  println(values[0].id)
  match values[0].kind {
    Kind::Ref(value) => println(value)
  }
}
```

The complete machine-readable outputs are in the workflow artifact
`moonreduce-interop-report`, including the baseline JSON, reducer report,
checks, original and reduced text, and MoonReduce summary.
