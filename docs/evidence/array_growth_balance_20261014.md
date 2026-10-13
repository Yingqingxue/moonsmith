# Grown-array index balance (2026-10-14)

The fixed depth-4 corpus (seeds 14990–15989) exposed a generator bias: on
commit `f7ad9e5`, the reference interpreter visited `array-grow-index-0` in
254 cases but `array-grow-index-1` in only 4. Both indices were technically
reachable, so a nonzero-only coverage check would have missed the imbalance.
This is a deterministic seed-selection correlation, not a MoonBit compiler
finding.

Commit `165695d` chooses the grown-array index using a separate child-seed
stream and a modulus not tied to the previous parity decision. A 1,000-seed
unit test now requires at least 20 reference-executed cases for each grown
index. The nightly validator independently reconciles per-case and aggregate
trace counts and requires each index in at least 2% of the fixed corpus.
Its fixture rejects a missing second-index path. The previous report fails
this stronger validator, as intended.

The new [nightly run 38456654935](https://github.com/Yingqingxue/moonsmith/actions/runs/38456654935)
passed on `165695d`. Its downloaded JSON report was revalidated locally:

| Fixed corpus metric | Before (`f7ad9e5`) | After (`165695d`) |
| --- | ---: | ---: |
| Distinct bodies / reference checks | 1,000 / 1,000 | 1,000 / 1,000 |
| Sources containing array growth | 367 | 367 |
| Reference cases visiting grown index 0 | 254 | 144 |
| Reference cases visiting grown index 1 | 4 | 133 |
| Unexpected findings / generator limits | 0 / 0 | 0 / 0 |

Both runs used MoonBit `0.1.20261012 (748b63c 2026-10-12)`, the same seed
window, depth 4, and JS/Wasm/Wasm-GC targets. The generator change altered
184 per-seed source hashes. The after-run recorded 1,000 consistent cases,
three configured backend targets per case, and no harness change. The ordinary
[Linux/Windows CI run 38456643726](https://github.com/Yingqingxue/moonsmith/actions/runs/38456643726)
also passed, including the Windows native job.

These are source and reference-interpreter path counts, **not** instrumented
coverage inside compiler backends. The corpus is fixed and finite; it cannot
establish general correctness or bug-finding probability. Neither this change
nor the historical upstream #1322 case is a newly discovered compiler bug.
