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
