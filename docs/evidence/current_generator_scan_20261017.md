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

## Independent follow-up cohort

A second, non-overlapping range was run on the same toolchain and workflow:

- Workflow: [MoonSmith CI run 39016632668](https://github.com/Yingqingxue/moonsmith/actions/runs/39016632668)
- Commit: `424bcfa9a85fc062ab60054a9960ae29bb8e49bd`
- Cohort: seeds 16680–16909, again split into depth 4 (100), depth 6 (100),
  and depth 8 (30).

The Windows native-release cross-check and report-comparison jobs passed. The
summary records 230/230 distinct source bodies within this cohort, identical
Linux/Windows source hashes and reference-expected outputs, 690 Linux
JS/Wasm/Wasm-GC executions, 230 Windows native-release executions, 230/230
cross-platform-consistent cases, and zero unexpected findings. These 1,840
backend executions across both cohorts still yielded no new compiler issue;
they provide bounded negative evidence, not proof that none exists.

## Third independent follow-up cohort

A third non-overlapping range was dispatched with Linux and Windows jobs
enabled:

- Workflow: [MoonSmith CI run 39046264932](https://github.com/Yingqingxue/moonsmith/actions/runs/39046264932)
- Commit: `a4946da56ac3c03e9c5c5a9cea2963b29c8cfeb9`
- Cohort: seeds 16910–17139, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

The workflow, extended Linux scan, Windows native-release cross-check, and
cross-platform report comparison all passed. The summary records 230/230
distinct generated bodies, matching source hashes and expected outputs,
690 Linux JS/Wasm/Wasm-GC executions, 230 Windows native-release executions,
230/230 cross-platform-consistent cases, and zero unexpected findings. The
three independent cohorts now cover seeds 16450–17139 without overlap: 690
programs, 2,070 Linux backend executions, and 690 Windows executions. No new
compiler issue was found in these bounded samples; this remains negative
evidence limited to the sampled generator, seeds, toolchain, and targets.

## Fourth independent follow-up cohort

A fourth non-overlapping range was dispatched with Linux and Windows jobs
enabled:

- Workflow: [MoonSmith CI run 39047215894](https://github.com/Yingqingxue/moonsmith/actions/runs/39047215894)
- Commit: `a4946da56ac3c03e9c5c5a9cea2963b29c8cfeb9`
- Cohort: seeds 17140–17369, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs, including extended Linux scan, Windows native-release
cross-check, and cross-platform report comparison, succeeded. Results again
show 230/230 distinct bodies, matching source hashes and expected outputs,
690 Linux JS/Wasm/Wasm-GC executions, 230 Windows native-release executions,
230/230 cross-platform-consistent cases, and zero unexpected findings. Across
the four independent cohorts the range is 16450–17369 with no gaps or overlap:
920 programs, 2,760 Linux backend executions, and 920 Windows executions.
No new compiler issue was found in these bounded samples.

## Fifth independent follow-up cohort

A fifth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39048540857](https://github.com/Yingqingxue/moonsmith/actions/runs/39048540857)
- Commit: `a4946da56ac3c03e9c5c5a9cea2963b29c8cfeb9`
- Cohort: seeds 17370–17599, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs succeeded. The comparison artifact reports 230/230 distinct
program bodies, matching source hashes and expected outputs, 690 Linux
JS/Wasm/Wasm-GC executions, 230 Windows native-release executions, and zero
unexpected findings. The artifact comparison was also rerun locally with
`compare_batch_reports.ps1` and reproduced the 230-seed result. Across the five
independent cohorts, seeds 16450–17599 are covered without gaps or overlap:
1,150 programs, 3,450 Linux backend executions, and 1,150 Windows executions.
No new compiler issue was found in these samples.

## Sixth independent follow-up cohort

A sixth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39050678795](https://github.com/Yingqingxue/moonsmith/actions/runs/39050678795)
- Commit: `39f17a7678bd95545ad540514758ed618b56d86a`
- Cohort: seeds 17600–17829, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs succeeded, including the cross-platform report comparison.
The comparison artifact records 230/230 distinct program bodies, matching
source hashes and expected outputs, 690 Linux JS/Wasm/Wasm-GC executions, 230
Windows native-release executions, 230/230 cross-platform-consistent cases,
and zero unexpected findings. Across the six independent cohorts, seeds
16450–17829 are covered without gaps or overlap: 1,380 programs, 4,140 Linux
backend executions, and 1,380 Windows native-release executions. No new
compiler issue was found in these finite samples; this is bounded negative
evidence, not evidence that no undiscovered compiler issue exists.

## Seventh independent follow-up cohort

A seventh non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39052046898](https://github.com/Yingqingxue/moonsmith/actions/runs/39052046898)
- Commit: `3e3fc7be7abc3a424855ab4a7060d252707cc46b`
- Cohort: seeds 17830–18059, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs succeeded, including the cross-platform report comparison.
It records 230/230 distinct program bodies, matching source hashes and
expected outputs, 690 Linux JS/Wasm/Wasm-GC executions, 230 Windows
native-release executions, 230/230 cross-platform-consistent cases, and zero
unexpected findings. Across seven independent cohorts, seeds 16450–18059 are
covered without gaps or overlap: 1,610 programs, 4,830 Linux backend
executions, and 1,610 Windows native-release executions. No new compiler issue
was found in these finite samples; this remains bounded negative evidence.

## Eighth independent follow-up cohort

An eighth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39052818761](https://github.com/Yingqingxue/moonsmith/actions/runs/39052818761)
- Commit: `a273df4d7b662f4154741662894dcabcb2c5425f`
- Cohort: seeds 18060–18289, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs succeeded, including the cross-platform report comparison.
The comparison artifact records 230/230 distinct program bodies, matching
source hashes and expected outputs, 690 Linux JS/Wasm/Wasm-GC executions, 230
Windows native-release executions, 230/230 cross-platform-consistent cases,
and zero unexpected findings. Across eight independent cohorts, seeds
16450–18289 are covered without gaps or overlap: 1,840 programs, 5,520 Linux
backend executions, and 1,840 Windows native-release executions. No new
compiler issue was found in these finite samples; this remains bounded
negative evidence.

## Ninth independent follow-up cohort

A ninth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39054292378](https://github.com/Yingqingxue/moonsmith/actions/runs/39054292378)
- Commit: `8e62c37c2b8022f8cf181c34846b11bb366eaa98`
- Cohort: seeds 18290–18519, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs succeeded, including the cross-platform report comparison.
The comparison artifact records 230/230 distinct program bodies, matching
source hashes and expected outputs, 690 Linux JS/Wasm/Wasm-GC executions, 230
Windows native-release executions, 230/230 cross-platform-consistent cases,
and zero unexpected findings. Across nine independent cohorts, seeds
16450–18519 are covered without gaps or overlap: 2,070 programs, 6,210 Linux
backend executions, and 2,070 Windows native-release executions. No new
compiler issue was found in these finite samples; this remains bounded
negative evidence.

## Tenth independent follow-up cohort

A tenth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39055709523](https://github.com/Yingqingxue/moonsmith/actions/runs/39055709523)
- Commit: `abc2533afac58bf4d5d9ebcf8425cdcac16d46da`
- Cohort: seeds 18520–18749, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

The extended scan, Windows cross-check, and report-comparison jobs succeeded.
The comparison artifact records 230/230 distinct program bodies, matching
source hashes and expected outputs, 690 Linux JS/Wasm/Wasm-GC executions, 230
Windows native-release executions, 230/230 cross-platform-consistent cases,
and zero unexpected findings. Across ten independent cohorts, seeds
16450–18749 are covered without gaps or overlap: 2,300 programs, 6,900 Linux
backend executions, and 2,300 Windows native-release executions. No new
compiler issue was found in these finite samples; this remains bounded
negative evidence.

## Eleventh independent follow-up cohort

An eleventh non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39056455646](https://github.com/Yingqingxue/moonsmith/actions/runs/39056455646)
- Commit: `8facec9b996dfc363e19660251a6d00d4435fc03`
- Cohort: seeds 18750–18979, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All scan, cross-check, and report-comparison jobs succeeded. The comparison
artifact records 230/230 distinct program bodies, matching source hashes and
expected outputs, 690 Linux JS/Wasm/Wasm-GC executions, 230 Windows
native-release executions, 230/230 cross-platform-consistent cases, and zero
unexpected findings. Across eleven independent cohorts, seeds 16450–18979 are
covered without gaps or overlap: 2,530 programs, 7,590 Linux backend
executions, and 2,530 Windows native-release executions. No new compiler issue
was found in these finite samples; this remains bounded negative evidence.

## Twelfth independent follow-up cohort

A twelfth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39057197544](https://github.com/Yingqingxue/moonsmith/actions/runs/39057197544)
- Commit: `71e7882fa0fc8988ad271468084ed5f5e4271f86`
- Cohort: seeds 18980–19209, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

The extended scan, Windows cross-check, and report-comparison jobs succeeded.
The comparison artifact records 230/230 distinct program bodies, matching
source hashes and expected outputs, 690 Linux JS/Wasm/Wasm-GC executions, 230
Windows native-release executions, 230/230 cross-platform-consistent cases,
and zero unexpected findings. Across twelve independent cohorts, seeds
16450–19209 are covered without gaps or overlap: 2,760 programs, 8,280 Linux
backend executions, and 2,760 Windows native-release executions. No new
compiler issue was found in these finite samples; this remains bounded
negative evidence.

## Thirteenth independent follow-up cohort

A thirteenth non-overlapping range was run with Linux and Windows jobs enabled:

- Workflow: [MoonSmith CI run 39057929527](https://github.com/Yingqingxue/moonsmith/actions/runs/39057929527)
- Commit: `cf4af3794a73d2ba8d94fdc02f2c014fc3644bcb`
- Cohort: seeds 19210–19439, split into depth 4 (100), depth 6 (100), and
  depth 8 (30).

All workflow jobs succeeded. The comparison artifact records 230/230 distinct
program bodies, matching source hashes and expected outputs, 690 Linux
JS/Wasm/Wasm-GC executions, 230 Windows native-release executions, 230/230
cross-platform-consistent cases, and zero unexpected findings. Across
thirteen independent cohorts, seeds 16450–19439 are covered without gaps or
overlap: 2,990 programs, 8,970 Linux backend executions, and 2,990 Windows
native-release executions. No new compiler issue was found in these finite
samples; this remains bounded negative evidence.

## Focused depth-10 cross-platform cohort

A separate five-seed cohort sampled deeper generated programs on Linux and
Windows:

- Workflow: [MoonSmith CI run 39059031700](https://github.com/Yingqingxue/moonsmith/actions/runs/39059031700)
- Commit: `cda13fb0a2ca28c4c1aa7a85066b8ff442460f05`
- Cohort: seeds 19445–19449, all at depth 10.

The extended Linux scan, Windows cross-check, and report comparison jobs
passed. The comparison artifact records five distinct bodies, matching source
hashes and expected outputs, 15 Linux JS/Wasm/Wasm-GC executions, and five
Windows native-release executions; all five cases were consistent across
platforms, with zero unexpected findings. This small exploratory cohort
broadens the sampled generation depth but is not a completeness claim.

## Follow-up: depth-10 size-guard accounting

A second five-seed depth-10 cohort checked reporting for generated sources above
the scanner's 16,300-line safety bound:

- Workflow: [MoonSmith CI run 39063712489](https://github.com/Yingqingxue/moonsmith/actions/runs/39063712489)
- Commit: `afd9cd980946917ef7d6ff9dae315fb2b4becc73`
- Cohort: seeds 19450–19454, all at depth 10.

All workflow jobs, including Linux scan, Windows native cross-check, report
comparison, and regular verification, passed. The comparison artifact records
five distinct bodies and matching source hashes. Two seeds were within the
size bound and produced matching reference outputs on both platforms (six
Linux JS/Wasm/Wasm-GC executions and two Windows native-release executions).
The other three exceeded the source-size bound and were classified as
`generator-limit` on both platforms; they were not compiled or counted as
backend executions. There were zero unexpected findings. This follow-up
validates consistent exclusion/reporting behavior; it does not establish
compiler behavior for the excluded programs or a new compiler issue.

The preceding attempt (run 39060757697) treated these size-guard cases as
workflow failures under the older result-accounting rule. Review of its paired
artifacts found no backend divergence; the corrected rule preserves the legacy
`unexpectedCount` field while separately reporting unexpected findings. The
successful follow-up confirms the reporting correction on the same seed range.

## Third focused depth-10 cohort

A further adjacent cohort checked seeds 19455–19459 at depth 10:

- Workflow: [MoonSmith CI run 39065818510](https://github.com/Yingqingxue/moonsmith/actions/runs/39065818510)
- Commit: `18aa86afbc3e4e45bbb0bd8612bdce3d0ed9a371`
- Cohort: seeds 19455–19459, all at depth 10.

Linux scan, Windows native cross-check, comparison, and regular CI succeeded.
All five generated bodies had matching source hashes. One source was within the
size bound and matched reference outputs across three Linux backends and
Windows native-release (four executions total); the other four exceeded the
bound and were consistently classified as `generator-limit` without compiler
execution. There were zero unexpected findings. Together, the three focused
depth-10 cohorts (seeds 19445–19459) contain 15 samples, of which eight were
compiled on both platforms and seven were excluded by the size guard. This is
limited exploratory coverage, not evidence about the excluded programs and not
a compiler-bug discovery.

## Fourth focused depth-10 cohort

The next adjacent cohort covered seeds 19460–19464 at depth 10:

- Workflow: [MoonSmith CI run 39070044826](https://github.com/Yingqingxue/moonsmith/actions/runs/39070044826)
- Commit: `50d2dde2adf48ac818eae9e36b222037518df0bc`
- Cohort: seeds 19460–19464, all at depth 10.

Linux scan, Windows native cross-check, report comparison, and regular CI all
passed. The five program bodies had matching source hashes. Two in-bound
programs matched expected outputs on six Linux JS/Wasm/Wasm-GC executions and
two Windows native-release executions. Three programs exceeded the 16,300-line
source limit and were classified as `generator-limit` on both platforms without
compiler execution. There were zero unexpected findings. Across the four
focused depth-10 cohorts (seeds 19445–19464), 20 distinct bodies are recorded;
ten were compiled on both platforms and ten were excluded by the size guard.
This is finite exploratory evidence only, not a result about excluded inputs.

## Fifth focused depth-10 cohort

The next adjacent cohort covered seeds 19465–19469, all at depth 10:

- Workflow: [MoonSmith CI run 39074195992](https://github.com/Yingqingxue/moonsmith/actions/runs/39074195992)
- Commit: `2669ac4411f081cb2d04a2c3aa74e1e21ca09baf`
- Cohort: seeds 19465–19469, all at depth 10.

Linux scan, Windows native cross-check, report comparison, and regular
verification passed. All five generated bodies were within the 16,300-line
source bound (maximum 15,885 lines), with matching source hashes and expected
outputs: 15 Linux JS/Wasm/Wasm-GC executions and five Windows native-release
executions. All five cases were cross-platform consistent; no unexpected
findings were recorded. Across the five focused depth-10 cohorts (seeds
19445–19469), 25 distinct bodies are recorded: 15 were compiled on both
platforms and ten were excluded by the size guard. This remains finite
exploratory evidence; it is not evidence about excluded inputs or proof that
the compiler has no bugs.

## Sixth focused depth-10 cohort

Seeds 19470–19474 were scanned at depth 10 with both cross-platform jobs
enabled:

- Workflow: [MoonSmith CI run 39075602996](https://github.com/Yingqingxue/moonsmith/actions/runs/39075602996)
- Commit: `92ec943e83bb3cde4f37a10d97ef228fd53a286b`
- Cohort: seeds 19470–19474, all at depth 10.

All workflow jobs passed, including Linux scan, Windows native cross-check,
report comparison, CaseKit interoperability, and regular verification. Four
programs were within the 16,300-line source bound and matched expected outputs
on 12 Linux JS/Wasm/Wasm-GC executions and four Windows native-release
executions. Seed 19472 generated an 18,066-line source and was classified as
`generator-limit` by both platform reports; it was not compiled, so this is not
a compiler result for that input. The legacy `unexpectedCount` is one because
it includes this non-finding exclusion; `unexpectedFindingCount` is zero. All
five bodies had matching source hashes, and all four executable cases were
cross-platform consistent. Across the six focused depth-10 cohorts (seeds
19445–19474), 30 distinct bodies are recorded: 19 compiled on both platforms
and 11 excluded by the size guard. This is bounded exploratory evidence, not a
claim about excluded cases or proof of absence of compiler bugs.

## Seventh focused depth-10 cohort

The adjacent range 19475–19479 was scanned on Linux and Windows at depth 10:

- Workflow: [MoonSmith CI run 39076902142](https://github.com/Yingqingxue/moonsmith/actions/runs/39076902142)
- Commit: `12ca034f36a2f5ab2fa010ef6f27e89dca87c319`
- Cohort: seeds 19475–19479, all at depth 10.

The scan, cross-platform comparison, CaseKit interop, regular verification,
and Windows-native job all passed. Four cases matched reference outputs on 12
Linux JS/Wasm/Wasm-GC executions and four Windows native-release executions.
Seed 19479 exceeded the 16,300-line bound (20,589 lines), was classified as
`generator-limit` by both platforms, and was not compiled. As in the previous
cohort, legacy `unexpectedCount` is one for this exclusion while
`unexpectedFindingCount` is zero. All five body hashes matched, with no
unexpected finding among executed cases. Across the seven focused depth-10
cohorts (seeds 19445–19479), there are 35 distinct bodies: 23 executed on both
platforms and 12 excluded by the size guard. The excluded programs remain
untested; this is bounded exploratory coverage, not a no-bugs claim.

## Eighth focused depth-10 cohort

Seeds 19480–19484 were scanned at depth 10 on Linux and Windows:

- Workflow: [MoonSmith CI run 39078199671](https://github.com/Yingqingxue/moonsmith/actions/runs/39078199671)
- Commit: `b8590bf38d7fb025f7514610248d59f5212b31e0`
- Cohort: seeds 19480–19484, all at depth 10.

All workflow jobs passed, including regular verification, CaseKit interop,
Linux scan, Windows native cross-check, and report comparison. Four generated
programs matched the reference on 12 Linux JS/Wasm/Wasm-GC executions and four
Windows native-release executions. Seed 19481 exceeded the 16,300-line limit
(20,678 lines); both reports classify it as `generator-limit`, not as a
compiled result. Thus legacy `unexpectedCount` is one while
`unexpectedFindingCount` is zero. All five source hashes matched, and there
were no unexpected findings among executed cases. Across the eight focused
depth-10 cohorts (seeds 19445–19484), 40 bodies are recorded: 27 were compiled
on both platforms and 13 were excluded by the size guard. These exclusions
remain untested; this finite sample is not evidence that no compiler bugs
exist.

## Ninth focused depth-10 cohort

The next adjacent seeds, 19485–19489, were checked at depth 10:

- Workflow: [MoonSmith CI run 39078967715](https://github.com/Yingqingxue/moonsmith/actions/runs/39078967715)
- Commit: `b8590bf38d7fb025f7514610248d59f5212b31e0`
- Cohort: seeds 19485–19489, all at depth 10.

All workflow jobs passed. Every generated source was below the 16,300-line
limit (maximum 14,821 lines). Five matching source hashes and expected outputs
were observed across 15 Linux JS/Wasm/Wasm-GC executions and five Windows
native-release executions; all cases were cross-platform consistent, with
zero unexpected findings. Cumulatively, the nine focused depth-10 cohorts
(seeds 19445–19489) contain 45 bodies: 32 were compiled on both platforms,
while 13 were excluded by the source-size guard and remain untested. This
finite sample provides no completeness guarantee and is not a claim that the
compiler has no bugs.

## Tenth focused depth-10 cohort

Seeds 19490–19494 were checked at depth 10 on Linux and Windows:

- Workflow: [MoonSmith CI run 39079606376](https://github.com/Yingqingxue/moonsmith/actions/runs/39079606376)
- Commit: `dd74b1ef057d28577cb930be711c60aa571c1c45`
- Cohort: seeds 19490–19494, all at depth 10.

All workflow jobs passed, including regular verification and CaseKit
interoperability. Three generated programs matched reference outputs on nine
Linux JS/Wasm/Wasm-GC executions and three Windows native-release executions.
Seeds 19490 and 19494 exceeded the 16,300-line bound (22,562 and 22,450
lines); both platform reports consistently classified them as
`generator-limit`, without compiling them. Therefore legacy `unexpectedCount`
is two while `unexpectedFindingCount` is zero. All five body hashes matched,
and the three executed cases were cross-platform consistent. Across ten
focused depth-10 cohorts (seeds 19445–19494), 50 bodies are recorded: 35 were
compiled on both platforms and 15 were excluded by the size guard. Those 15
programs remain untested; no compiler issue was found in the executed sample.

## Eleventh focused depth-10 cohort

Seeds 19495–19499 were scanned at depth 10 across Linux and Windows:

- Workflow: [MoonSmith CI run 39080189649](https://github.com/Yingqingxue/moonsmith/actions/runs/39080189649)
- Commit: `ab417988866ac4ee0515cbcbc733c66741e9fbe4`
- Cohort: seeds 19495–19499, all at depth 10.

All workflow jobs passed. Four cases matched the reference on 12 Linux
JS/Wasm/Wasm-GC executions and four Windows native-release executions. Seed
19498 exceeded the 16,300-line bound (28,512 lines), was consistently
classified as `generator-limit`, and was not compiled. Thus legacy
`unexpectedCount` is one for the exclusion, while `unexpectedFindingCount` is
zero. All five source hashes matched; the four executable cases were
cross-platform consistent. Across the eleven focused depth-10 cohorts (seeds
19445–19499), 55 bodies are recorded: 39 were compiled on both platforms and
16 were excluded by the source-size guard. Excluded inputs remain untested;
this bounded exploration found no issue among the executed cases.

## Twelfth focused depth-10 cohort

Seeds 19500–19504 were scanned at depth 10 with Linux and Windows native
cross-checks:

- Workflow: [MoonSmith CI run 39080798051](https://github.com/Yingqingxue/moonsmith/actions/runs/39080798051)
- Commit: `6ee1d63d6750ec55d334c2ee47a4eba7ee1eb252`
- Cohort: seeds 19500–19504, all at depth 10.

All workflow jobs passed, including CaseKit interoperability, regular
verification, Windows native testing, and cross-platform report comparison.
All five sources were within the 16,300-line bound (maximum 15,281 lines).
They matched the reference outputs on 15 Linux JS/Wasm/Wasm-GC executions and
five Windows native-release executions; all five cases were consistent and
there were zero unexpected findings. Cumulatively, the twelve focused
depth-10 cohorts (seeds 19445–19504) contain 60 bodies: 44 were compiled on
both platforms and 16 were excluded by the size guard. No issue was found in
this executed sample; this does not establish behavior for excluded inputs or
prove absence of compiler bugs.

## Thirteenth focused depth-10 cohort

Seeds 19505–19509 were scanned at depth 10 on Linux and Windows:

- Workflow: [MoonSmith CI run 39081453016](https://github.com/Yingqingxue/moonsmith/actions/runs/39081453016)
- Commit: `6ee1d63d6750ec55d334c2ee47a4eba7ee1eb252`
- Cohort: seeds 19505–19509, all at depth 10.

All workflow jobs passed. Four cases matched reference outputs on 12 Linux
JS/Wasm/Wasm-GC executions and four Windows native-release executions. Seed
19507 exceeded the 16,300-line bound (17,972 lines), was classified as
`generator-limit` in both reports, and was not compiled. Legacy
`unexpectedCount` is one for that exclusion; `unexpectedFindingCount` is
zero. All five source hashes matched, and all four executable cases were
consistent across platforms. Across the thirteen focused depth-10 cohorts
(seeds 19445–19509), 65 bodies are recorded: 48 were compiled on both
platforms and 17 were excluded by the size guard. Excluded cases remain
untested; no issue was found in this bounded executed sample.

## Fourteenth focused depth-10 cohort

Seeds 19510–19514 were scanned at depth 10 on Linux and Windows:

- Workflow: [MoonSmith CI run 39082181846](https://github.com/Yingqingxue/moonsmith/actions/runs/39082181846)
- Commit: `6ee1d63d6750ec55d334c2ee47a4eba7ee1eb252`
- Cohort: seeds 19510–19514, all at depth 10.

All workflow jobs passed, including CaseKit interoperability, regular
verification, Windows native testing, and cross-platform report comparison.
Four cases matched reference outputs on 12 Linux JS/Wasm/Wasm-GC executions
and four Windows native-release executions. Seed 19511 exceeded the
16,300-line source-size bound (21,145 lines), was classified as
`generator-limit` in both reports, and was not compiled. Thus the legacy
`unexpectedCount` is one for that exclusion, while
`unexpectedFindingCount` is zero. All five source hashes matched, and the
four executable cases were consistent across platforms. Across the fourteen
focused depth-10 cohorts (seeds 19445–19514), 70 bodies are recorded: 52 were
compiled on both platforms and 18 were excluded by the size guard. Excluded
inputs remain untested; no issue was found in this bounded executed sample.

## Fifteenth focused depth-10 cohort

Seeds 19515–19519 were scanned at depth 10 on Linux and Windows:

- Workflow: [MoonSmith CI run 39083833393](https://github.com/Yingqingxue/moonsmith/actions/runs/39083833393)
- Commit: `11b35957809866a5f19f8b01ddaf56c1b1fa1b3d`
- Cohort: seeds 19515–19519, all at depth 10.

All workflow jobs passed, including CaseKit interoperability, regular
verification, Windows native testing, and cross-platform report comparison.
Only one case was within the 16,300-line source-size bound and matched its
reference output on three Linux JS/Wasm/Wasm-GC executions and one Windows
native-release execution. The other four sources measured 17,189, 18,273,
23,044, and 21,785 lines; they exceeded the bound, were classified as
`generator-limit`, and were not compiled. Thus legacy `unexpectedCount` is
four for exclusions, while `unexpectedFindingCount` is zero. All five source
hashes matched. Across the fifteen focused depth-10 cohorts (seeds
19445–19519), 75 bodies are recorded: 53 were compiled on both platforms and
22 were excluded by the size guard. The high exclusion rate in this cohort
limits its compiler coverage; excluded inputs remain untested. No issue was
found in the single executed case.
