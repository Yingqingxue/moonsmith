# CaseKit comparator interoperability (2026-10-17)

This records a narrow interoperability test, not a claim that MoonSmith and
CaseKit have disjoint scopes or that either finds more compiler defects.

- MoonSmith commit: `424bcfa9a85fc062ab60054a9960ae29bb8e49bd`
- Hosted CI run: [39015643110](https://github.com/Yingqingxue/moonsmith/actions/runs/39015643110)
- CaseKit comparator revision: `cd1a4a12347b781706a25964a428a4a2fdf21996`
- Artifact: `casekit-interop-report`
- Data contract: one captured stdout value from each MoonSmith JS/Wasm run,
  serialized as a CaseKit v1 transcript and passed to CaseKit's native
  comparator.

| Case | CaseKit result | MoonSmith result | Interpretation |
|---|---|---|---|
| Seed 42, depth 4, ordinary JS/Wasm output | match | `consistent` | The transcript adapter preserves an ordinary matching observation. |
| Injected wasm-only output difference | mismatch | `output-mismatch` | Both comparators expose a backend-specific discrepancy. This is a deliberately injected test fault. |
| Same injected wrong output on JS and Wasm | match | `reference-mismatch` | Pairwise agreement is insufficient for a common-mode error; MoonSmith's independent evaluator catches this injected test fault. |

The job built and invoked the pinned CaseKit CLI and preserved all nine JSON
transcripts/reports. It reused only the comparator and transcript format; it
did not execute CaseKit observation packages. The injected faults are harness
tests, not compiler bugs or bug-finding-effectiveness measurements.
