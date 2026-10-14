# Reference-path-guided selection: bounded A/B evidence (2026-10-14)

The new policy prescreens a contiguous candidate pool with MoonSmith's
reference evaluator, then greedily selects seeds by inverse pool frequency of
reference path kinds, discounting paths already selected. The control arm takes
the first seeds in the same pool. Each arm uses the same depth, three backends
(`js`, `wasm`, `wasm-gc`), and ten selected programs. These are interpreter
paths, **not** branch coverage inside any compiler backend.

| Candidate seeds | Arm order | Prescreen | Sequential paths | Guided paths | Backend runtime launches, each arm | Findings |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| 24000–24039 | sequential first | 18.3 s | 51 | 53 | 30 | 10/10 consistent in each |
| 24040–24079 | guided first | 18.7 s | 51 | 53 | 30 | 10/10 consistent in each |
| 24080–24119 | sequential first | 19.2 s | 41 | 53 | 30 | 10/10 consistent in each |

The candidate pool contained 53 distinct reference path kinds in each cohort;
the guided ten-case selection represented all 53. The arms overlapped by 0,
3, and 1 seed respectively. The raw local reports are
`.moonsmith/runs/selection_24000_40_10_d4.json`,
`selection_24040_40_10_d4.json`, and
`selection_24080_40_10_d4.json` (ignored by Git). The final run recorded an
unchanged harness SHA-256 digest throughout; its checkout was dirty because
this implementation had not yet been committed. The first two runs preceded
the digest guard and are therefore development evidence, not independently
attested immutable-run artifacts.

Prescreening is not free. In the final cohort, arm execution took 61.9 s
(sequential) versus 62.7 s (guided); the guided workflow additionally spent
19.2 s prescreening. Guided cases averaged 143.4 source lines versus 91.9 for
sequential cases, so larger generated programs plausibly contribute to the
higher path count. This experiment measured neither compiler-internal
coverage nor defect-finding probability. It does not establish that guidance
is more efficient or finds more real bugs. Arm order was alternated once, but
three small contiguous cohorts on one local toolchain remain susceptible to
generator-periodicity, build-cache, and sample-selection effects.

Reproduce the last cohort with:

```powershell
pwsh -File scripts/compare_semantic_selection.ps1 -SeedStart 24080 `
  -CandidateCount 40 -ExecutionBudget 10 -Depth 4 `
  -Targets @('js','wasm','wasm-gc')
```

The next decision should depend on a larger preregistered, nonoverlapping
sample with source-size-aware comparisons and compiler-coverage or unique
failure outcomes. Do not market the current path-diversity gain as a bug find.
