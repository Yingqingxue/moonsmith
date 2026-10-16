# MoonSmith ecosystem comparison

Research date: 2026-10-09. This is a source-based positioning note, not a
claim that MoonSmith is better, unique, or already effective at finding real
compiler defects. The comparisons below use the projects' own repositories,
documentation, and (for YARPGen) its research paper.

## What the neighboring tools do

| Project | Main job and evidence | Boundary relative to MoonSmith |
|---|---|---|
| [Csmith](https://github.com/csmith-project/csmith) | Generates runnable C programs intended for compiler differential testing. Its README emphasizes avoiding undefined behavior, reporting generation statistics, and compiling the same generated input with different compilers to compare outputs. | It is an established C-focused random program generator. MoonSmith targets a MoonBit expression subset and compares MoonBit compiler backends; the languages and execution targets differ, so the useful comparison is methodological rather than feature parity. |
| [YARPGen](https://github.com/intel/yarpgen) and its [OOPSLA paper](https://users.cs.utah.edu/~regehr/yarpgen-oopsla20.pdf) | Generates well-defined runnable C/C++ programs (the repository also describes early DPC++ work). It uses generation policies to bias programs toward optimizer-relevant code, compares compilers and optimization options, and records mismatches. The paper explicitly discusses generator saturation as a coverage-bias problem. | This is the closest methodological comparison for compiler-focused generation. MoonSmith currently has a much smaller typed MoonBit grammar and no verified optimization-targeting policies. Its current claim should be “MoonBit-specific cross-backend workflow,” not “more effective fuzzer.” |
| [C-Reduce](https://github.com/csmith-project/creduce) | Takes an existing program plus an interestingness property (for example, a compiler failure) and repeatedly reduces it while preserving that property. The project is explicitly C/C++ oriented, though its README notes that it can sometimes reduce other languages too. | C-Reduce is a reducer rather than a program generator or compiler oracle. MoonSmith's reducer works on its own generated AST and verifies candidates by replaying a finding; it does not yet reduce arbitrary MoonBit source. C-Reduce's non-C support is not evidence of reliable MoonBit support. |
| [MoonBit QuickCheck](https://github.com/moonbitlang/quickcheck) and its [Mooncakes package documentation](https://mooncakes.io/docs/moonbitlang/quickcheck) | A MoonBit property-based testing library: users define properties and generators; `Arbitrary`, `Shrink`, and `Debug` support test input generation and shrinking. Its documentation describes applying it to MoonBit core and finding core-library bugs. | It is the closest ecosystem neighbor in language, but the normal unit is a generated property input, not a standalone program compared across compiler backends. It could still complement MoonSmith—for example, to test the reference evaluator or harness invariants. Do not describe it as incapable of compiler testing; the narrower claim is that backend differential orchestration is not its documented primary workflow. |

## MoonSmith: implemented versus unproven

The following are implemented and locally/CI verified as of this note:

- A deterministic, typed MoonBit AST generator for a deliberately restricted
  subset, including integer/boolean expressions, matches, arrays, records,
  payload enums, captured local functions, and bounded accumulator loops.
- A MoonBit reference interpreter and output comparison against `js`, `wasm`,
  and `wasm-gc` runs.
- Classification, seed-based replay, and AST shrinking of generated cases.
- A 100-seed depth-4 scan with 100 distinct program bodies and 300 successful
  backend executions. This validates the current pipeline on that corpus; it
  does not demonstrate that a real compiler defect was found.

These comparisons support a cautious positioning: MoonSmith combines a
MoonBit-specific generator, a separate reference-evaluation path, several
MoonBit compilation targets, and a generated-AST reduction workflow in one
small tool. This is a description of the current design, not a verified claim
that no other tool can do the same.

Not yet established: full MoonBit language coverage; arbitrary-source
reduction; optimizer-directed generation; backend runtime branch coverage;
reproducible compiler-bug discovery; comparative throughput or bug-finding
effectiveness; or uniqueness relative to all MoonBit tooling. The current
100-seed scan found no real defect.

## Lessons and next experiments

1. **Avoid generator saturation.** YARPGen's paper explains that a generator
   can stop finding issues because its own biases prevent it from reaching
   important compiler behavior. Track construct and reference-path
   distributions, but do not call interpreter traces backend coverage. Add
   grammar policies tied to identifiable MoonBit compiler behaviors rather
   than only increasing the seed count.
2. **Measure against a known corpus.** Two public historical cases are now
   tracked in [`docs/regressions.md`](regressions.md): a coverage ICE and a
   Wasm `#valtype`/`raise` validation failure. Both pass on the current
   toolchain; the second's trigger pattern now has a dedicated generator node.
   This checks the case and the narrow generation path, not broad
   `#valtype`/exception coverage or MoonSmith's ability to find new bugs.
   Expand only with verified, redistributable cases and test each through the
   full generate/reference/differential/reducer path.
3. **Keep the oracle honest.** The reference interpreter catches a common
   wrong result when it disagrees, but it shares the MoonBit toolchain and
   semantics assumptions. Continue using cross-backend comparison as a second
   signal; neither path alone proves correctness.
4. **Treat arbitrary-source shrinking as a separate milestone.** C-Reduce's
   model starts from an existing interesting program and predicate. MoonSmith
   currently reduces only its own AST. Supporting arbitrary MoonBit source
   would require a parser/AST integration or a robust syntax-preserving
   transformation strategy plus a user-defined, signature-preserving
   interestingness check; it is not a small switch to turn on.
5. **Research is not pre-review.** This comparison closes the initial desk
   research gap only. It does not replace an external review of MoonSmith's
   scope or prove competition readiness.

## October competition overlap review (2026-10-16)

The first-review feedback named four MoonBit projects and said MoonSmith's
cross-backend comparison/reduction purpose overlapped with them, while the
proposal did not state an extension relationship. That is a concrete scope
problem; adding more generator syntax by itself would make the proposal broader,
not clearer. The following is a source-based response to that feedback, not a
claim about judging outcomes or relative quality:

| Project | Publicly described overlap | MoonSmith's defensible relationship |
|---|---|---|
| [moonbit-casekit](https://github.com/kaigeliang/moonbit-casekit) | Stores stable case observations and compares backend results; documents JSON/Markdown reports. Its README says it does not generate inputs or shrink failures. | Treat it as the reusable capture/comparison layer for user-authored cases. MoonSmith should focus its own value on deterministic generation, the reference evaluator, and shrinking generated MoonBit ASTs. A direct adapter is not implemented yet. |
| [MoonBit Target Parity](https://github.com/zhangbowen2006/MoonBitTargetParity) | Reusable library for comparing observed backend behavior and optional expected-result contracts. | MoonSmith now uses its public API to classify complete successful backend matrices and includes the independent result in per-seed and batch reports. MoonSmith retains compile/runtime/timeout/environment classification and its failure-preserving reducer, which are outside this adapter's input model. |
| [MoonReduce](https://github.com/Hing7/moonreduce) | Generic source/text or JSON reduction around an external checker, with bounded replay/verification. | MoonReduce is the more general choice for arbitrary existing files. MoonSmith currently reduces only its own typed generated AST and replays the same differential finding. Do not claim arbitrary-source reduction. A bridge remains a possible future option, not current functionality. |
| [MoonGrammata](https://github.com/erzhuzi259/MoonGrammata) | Structured grammar-based fuzzing, tree mutations, differential/metamorphic checking, and failure reduction. This is the closest overlap in breadth. | MoonSmith should not claim to be a novel general-purpose MoonBit fuzzer. Its narrower contribution is a reproducible compiler-backend regression workflow built around its own small typed grammar, independent reference evaluation, targeted historical regression seeds, and shrinking that preserves a backend finding. This distinction is a design position, not evidence of superior effectiveness or uniqueness. |

The immediate engineering response is intentionally limited: reuse Target Parity
instead of independently duplicating the successful-run observation comparison,
and make the evidence visible in `verify_seed` JSON. It does not resolve all
overlap—especially with MoonGrammata—or by itself establish that this project is
an extension rather than a parallel tool. Before claiming that relationship in
a submission, the project should add one end-to-end example that starts from a
documented compiler regression, runs the local generated probe through the
shared parity API, and demonstrates MoonSmith's AST shrinker preserving the
same finding. The previously rejected upstream issue #1322 must remain clearly
labelled as a reported upstream case, not a defect discovered by MoonSmith.

## Sources

- Csmith project README: <https://github.com/csmith-project/csmith>
- YARPGen project README: <https://github.com/intel/yarpgen>
- YARPGen OOPSLA 2020 paper: <https://users.cs.utah.edu/~regehr/yarpgen-oopsla20.pdf>
- C-Reduce project README: <https://github.com/csmith-project/creduce>
- MoonBit QuickCheck repository: <https://github.com/moonbitlang/quickcheck>
- MoonBit QuickCheck package docs: <https://mooncakes.io/docs/moonbitlang/quickcheck>
