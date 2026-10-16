# Rerun of registered semantic-selection cohort — 2026-10-16

This reruns the already-observed 2026-10-14 preregistered range; it is a
reproducibility check, **not an independent cohort**. The original fixed design
is in
[`semantic_selection_replication_preregistration_20261014.md`](semantic_selection_replication_preregistration_20261014.md),
and the original results are in
[`semantic_selection_replication_20261014.md`](semantic_selection_replication_20261014.md).
The rerun used a clean GitHub runner in [workflow run 38873580951](https://github.com/Yingqingxue/moonsmith/actions/runs/38873580951).
Its artifact was downloaded locally to the ignored
`.moonsmith/runs/hosted_38873580951/selection_24220_100_20_d4_size_matched.json`.

It repeated candidate seeds 24220–24319 at depth 4 using `js`, `wasm`, and
`wasm-gc`, with 20 programs per arm. The artifact reports MoonBit
`0.1.20261012 (748b63c 2026-10-12)`, clean commit
`a1ef743c0fa41489438f21b13c9c356de40d8e36`, matching start/end harness
digests, and no harness changes during the run.

| Arm | Selected programs | Backend executions | Distinct reference paths | Unique bodies | Mean source lines | Arm time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Sequential | 20 | 60 | 51 | 20 | 98.6 | 11.6 s |
| Size-matched semantic-guided | 20 | 60 | 55 | 20 | 100.8 | 11.4 s |

Both arms were consistent in all 20 cases, with no unexpected findings or
unavailable backends. The source-size quartile counts matched exactly
(`9, 6, 4, 1` in quartiles 0–3). The selected arms shared four seeds. The
100-candidate reference-evaluator prescreen took 11.7 s, so the additional
selection cost was about 11.7 s for this run; the backend execution budget was
equal, but the end-to-end workflow was not cost-free. The guided arm visited
four more reference-interpreter path kinds in this cohort.

The original run used the same MoonBit version and reported the same arm
metrics and selected seed lists. Its harness digest was
`b7678deef41a252c2f596108ca7531a4f98e09a641b1eae7c8eb9cbe050819ea`, versus
`d3cb99b2cda53cdf00be503da7a576e8f3360f0f302025d2c419b3d790b9a193` in this
rerun. Thus the repeat is encouraging for this fixed range but not an
independent test, and its changed harness digest prevents claiming bit-for-bit
identical experimental setup.

Reference-interpreter paths are not compiler-internal coverage; these data do
not establish improved bug-finding probability or a MoonSmith-discovered
compiler bug. Compare this rerun with the disjoint
[`second cohort`](semantic_selection_hosted_replication2_20261016.md), whose
guided and sequential path counts were equal.
