# MoonSmith parameter reduction on upstream-reported #2228 (2026-10-17)

This is a source-specific MoonSmith experiment on an already public issue, not
a MoonReduce result and not a MoonSmith compiler-bug discovery.

- MoonSmith commit: `a4946da56ac3c03e9c5c5a9cea2963b29c8cfeb9`
- Hosted MoonReduce interoperability workflow:
  [run 39017854306](https://github.com/Yingqingxue/moonsmith/actions/runs/39017854306)
- Upstream issue: [moonbitlang/moon#2228](https://github.com/moonbitlang/moon/issues/2228)
- Toolchain: `moon 0.1.20261012 (748b63c 2026-10-12)` on Ubuntu 22.04, 8 MiB
  stack, core dumps disabled.

The first two runs had shown that MoonReduce's line-deletion strategy retained
the issue signature but changed only layout (385 to 379 bytes). This separate
MoonSmith search modified only the recursion-depth integer and re-ran both the
native and JavaScript targets for each candidate.

| Check | Result |
|---|---:|
| Original depth | `1,000,000` |
| Reduced depth | `523,682` |
| Adjacent lower, non-reproducing depth | `523,681` |
| Search checks | 20 |
| Independent final replays | 3 / 3 passed |
| Source size | 385 to 382 bytes |
| Other source changes | none; only the depth argument changed |
| Preserved paired signature | native exit 139 with empty captured stdout; JS stack `RangeError` |

`523,682` is minimal only within the tested interval under the stated monotone
threshold assumption that increasing recursive depth does not remove this
stack-overflow signature on this pinned runner/toolchain. This is a semantic
parameter reduction for one actual reproducer, not a general MoonBit AST/source
reducer or a result produced by MoonReduce. The pinned first-version MoonReduce
README explicitly excludes numeric/string simplification and source-AST
reduction; see [the interoperability scope note](../moonreduce_interop.md).

The search needed correction after a 500,000-depth candidate returned native
success (printing the depth) while JS still failed. A mistaken expectation of
`0` had classified that known partial outcome as unknown. The corrected
classifier distinguishes the exact paired signature, recognized partial
outcomes, and genuinely unknown outcomes; a mock regression covers these
branches. The actual hosted result above is from the corrected search.

## Composed MoonReduce → MoonSmith run (2026-10-18)

The interoperability workflow now continues the independently verified
MoonReduce artifact with the separate MoonSmith integer-parameter search. This
tests whether the combined workflow can make a real source-level change while
preserving the same observed issue signature; it does not transfer credit for
that change to MoonReduce.

- Hosted run: [39100323165](https://github.com/Yingqingxue/moonsmith/actions/runs/39100323165)
- Pinned MoonReduce stage: 385 → 379 bytes, one accepted deletion, 40 checks;
  zero non-layout lines changed (`layout-only`).
- MoonSmith stage input: MoonReduce's verified `reduced.txt`; only the recursion
  depth argument was changed by the parameter pass.
- Parameter: 1,000,000 → 533,712; last observed non-reproducing value 523,711.
- The parameter search used 20 checks; the selected value passed three
  independent replays, followed by an additional replay of the composed source.
- Final source: 376 bytes (9 bytes smaller than the original); the final replay
  retained native exit 139 with empty redirected stdout and the JS stack
  `RangeError`.
- `minimalWithinMonotoneSearchInterval` is false for this run. A near-threshold
  candidate did not pass all independent replays, so the reducer moved upward
  by a fixed stability step and selected a stable value instead of claiming
  that the first observed boundary was minimal. The bound is runner/toolchain
  specific and does not prove a global minimum.

This is a narrow, composed text-plus-integer reduction for the already public
upstream #2228 reproducer. The semantic parameter change is produced by
MoonSmith, not MoonReduce; neither stage establishes that MoonSmith discovered
the issue or that either tool supports general arbitrary-source AST
minimization.
