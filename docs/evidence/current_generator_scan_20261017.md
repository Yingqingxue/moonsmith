# Current generator scan and Windows cross-check (2026-10-17)

This is a new bounded scan of MoonSmith's current generator, not a compiler-bug
discovery claim.

- Workflow: [MoonSmith CI run 39014342692](https://github.com/Yingqingxue/moonsmith/actions/runs/39014342692)
- Commit: `5df8b03af00bdb484df829f5460f938039f9b1ea`
- Toolchain: `moon 0.1.20261012 (748b63c 2026-10-12)`
- Linux targets: JS, Wasm, Wasm-GC; Windows target: native-release.
- Cohort: seeds 16450–16679, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

| Check | Result |
|---|---:|
| Distinct generated program bodies | 230 / 230 |
| Matching source hashes between Linux and Windows | 230 / 230 |
| Matching reference-expected outputs | 230 / 230 |
| Linux backend executions | 690 |
| Windows native-release executions | 230 |
| Cases consistent on both platforms | 230 / 230 |
| Unexpected findings | 0 |

The scan and report-comparison jobs completed successfully. This is evidence
only for this finite seed cohort, grammar, toolchain, and backend set; it does
not establish compiler correctness or that MoonSmith will find a new defect.
The raw Linux and Windows batch JSON plus the cross-platform summary are
preserved as the workflow's `moonsmith-current-generator-seed-scan`,
`moonsmith-windows-current-generator-crosscheck`, and
`moonsmith-cross-platform-seed-comparison` artifacts.
