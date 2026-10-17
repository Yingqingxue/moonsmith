# MoonReduce text reduction study on upstream-reported #2228 (2026-10-17)

This is a bounded interoperability measurement of the externally reported
[Moon issue #2228](https://github.com/moonbitlang/moon/issues/2228), not a
MoonSmith compiler-bug discovery.

- MoonSmith commit: `5df8b03af00bdb484df88fe45a0db7a8bdc523a`
- MoonReduce interoperability run:
  [39014185307](https://github.com/Yingqingxue/moonsmith/actions/runs/39014185307)
- MoonReduce source revision: `f256f264a2e8853c2e7ec67e3488e61aefaff17d`
- MoonBit toolchain: `moon 0.1.20261012 (748b63c 2026-10-12)`
- Runner conditions: Ubuntu 22.04, 8 MiB process stack, core dumps disabled.
- Baseline signature required before and after reduction: native runtime exit
  139 with empty captured stdout, and JavaScript `RangeError`.
- The checker additionally requires the pre-crash
  `println("before-deep-recursion")` source line, because that behavior is not
  included in MoonSmith's normalized reduction key.

| Metric | Result |
|---|---:|
| MoonReduce status | `verified_reduction` |
| Input / output bytes | 385 / 379 |
| Accepted candidates / search checks | 1 / 40 |
| Removed non-layout source lines | 0 |
| Change class | `layout-only` |
| Trigger and pre-crash print retained | yes |
| Independent final replay | passed |

The six-byte reduction removes only layout. Every nonblank, non-`///|` source
line is identical. Thus this real-case run verifies baseline checking, symptom
preservation, and replay, but **does not demonstrate semantic source
simplification or effective reduction of this actual issue**. MoonReduce's
current line-deletion strategy cannot change the recursive depth literal. A
separate, narrowly scoped MoonSmith integer-parameter experiment is being added
to measure that one source transformation against the same failure signature;
it must not be described as MoonReduce functionality, general AST reduction,
or a MoonSmith discovery.

The complete run artifact contains baseline reports, original and reduced
source, reduction report, check log, and the `RequiredSourceFragment` argument.
The status name `verified_reduction` alone does not imply that executable
program content changed.
