# MoonSmith ecosystem comparison

Research date: 2026-10-16. This is a source-based positioning note, not a
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
| [moonbit-casekit](https://github.com/kaigeliang/moonbit-casekit) | Runs user-authored observation packages across backends, stores stable case observations, and compares them with JSON/Markdown reports. Its README says it does not generate inputs or shrink failures. | CaseKit already owns an external runner and comparison workflow for authored cases, so process invocation is not unique to MoonSmith. MoonSmith's boundary is that it generates a restricted typed AST, computes an expected output with a separate evaluator, and shrinks that generated AST. No CaseKit adapter is implemented. |
| [MoonBit Target Parity](https://github.com/zhangbowen2006/MoonBitTargetParity) | Reusable library for comparing observed backend behavior and optional expected-result contracts. | MoonSmith now uses its public API to classify complete successful backend matrices and includes the independent result in per-seed and batch reports. MoonSmith retains compile/runtime/timeout/environment classification and its failure-preserving reducer, which are outside this adapter's input model. |
| [MoonReduce](https://github.com/Hing7/moonreduce) | Generic source/text or JSON reduction around an external checker, with bounded replay/verification. | An optional checker adapter lets MoonReduce evaluate candidates against a saved MoonSmith finding and its exact reduction key; MoonReduce performs the text reduction, MoonSmith performs backend verification. The adapter contract is covered by injected-finding regressions, and the real pinned MoonReduce Linux CLI path passed with an injected mismatch in [workflow run 38941306085](https://github.com/Yingqingxue/moonsmith/actions/runs/38941306085): `verified_unchanged`, zero deletions, one search candidate, and successful final replay. This validates integration/replay only—not successful reduction quality on a real compiler failure. MoonSmith's own reducer still handles only its generated AST. |
| [MoonGrammata](https://github.com/erzhuzi259/MoonGrammata) | Structured grammar-based fuzzing, tree mutations, differential/metamorphic checking, corpus feedback, and failure reduction. This is the closest overlap in breadth. Its README describes controlled in-process targets and explicitly excludes native process isolation and crash-signal capture. | MoonSmith instead drives compiler/backend executables as separate processes and distinguishes compile, runtime, timeout, and unavailable-toolchain outcomes; it also checks generated programs against its own reference evaluator. This is an operational boundary, not a claim of overall uniqueness or greater bug-finding effectiveness. MoonSmith still overlaps in generation, differential testing, and reduction, and has a much narrower grammar. |

The first engineering response is deliberately narrow: reuse Target Parity's
successful-observation comparator instead of reimplementing it, and carry its
result through per-seed JSON, batch JSON, and offline reports. The adapter is
verified with matching and injected common-mode-wrong-output examples; the
latter is a harness fault, not a compiler bug. This reduces duplicated
comparison code, but does not resolve all overlap—especially with
MoonGrammata—or establish that MoonSmith is more effective. The next distinctive
deliverable is a reproducible, issue-linked probe-and-reduction dossier, now
recorded in [`valtype_reduction_smoke_20261016.md`](evidence/valtype_reduction_smoke_20261016.md): it separates the
exact historical trigger from the generated extension and records the
injected-fault reduction without claiming compiler-bug discovery. This is a
workflow example, not resolution of all overlap—especially with MoonGrammata.
Three disjoint, source-size-matched candidate ranges provide descriptive
results: 24120–24219 yielded 53 versus 52 path kinds (guided versus sequential)
on MoonBit `0.1.20260920`; 24220–24319 yielded 55 versus 51 on
`0.1.20261012`; and the new 24320–24419 range yielded 53 versus 53 on the same
`0.1.20261012` toolchain. Each comparison used equal backend-execution and
quartile budgets and had no unexpected findings. The first range is documented
in the [size-matched result](evidence/semantic_selection_size_match_20261014.md),
the second in the
[original preregistered result](evidence/semantic_selection_replication_20261014.md),
and the third in the
[non-overlapping follow-up](evidence/semantic_selection_hosted_replication2_20261016.md).
The clean-runner rerun of the second range reproduced its selected seeds and
aggregate counts, but is not independent and used a different harness digest
([rerun details](evidence/semantic_selection_hosted_replication_20261016.md)).
Because the first range used another MoonBit version and the two same-version
independent ranges show mixed results, and both ran sequential selection before
guided selection (leaving a possible warm-cache/order effect), there is no
robust evidence that semantic guidance improves compiler coverage or
bug-finding. Keep it optional and do not prioritize it as a claimed
differentiator without stronger, counterbalanced evidence.
Do not present either path traces or the previously reported upstream issue
#1322 as a MoonSmith discovery or backend coverage.

## Sources

- Csmith project README: <https://github.com/csmith-project/csmith>
- YARPGen project README: <https://github.com/intel/yarpgen>
- YARPGen OOPSLA 2020 paper: <https://users.cs.utah.edu/~regehr/yarpgen-oopsla20.pdf>
- C-Reduce project README: <https://github.com/csmith-project/creduce>
- MoonBit QuickCheck repository: <https://github.com/moonbitlang/quickcheck>
- MoonBit QuickCheck package docs: <https://mooncakes.io/docs/moonbitlang/quickcheck>
- MoonBit CaseKit README: <https://github.com/kaigeliang/moonbit-casekit>
- MoonBit Target Parity README: <https://github.com/zhangbowen2006/MoonBitTargetParity>
- MoonReduce README: <https://github.com/Hing7/moonreduce>
- MoonGrammata README: <https://github.com/erzhuzi259/MoonGrammata>
