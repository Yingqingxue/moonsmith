# Equal-wall-clock online-feedback comparison protocol

Status: harness prototype and mocked-process tests are implemented. A corrected
real smoke run against the unchanged saved selection configuration completed on
2026-10-19. It verifies that the campaign can produce and preserve online
feedback artifacts under a matched per-arm wall-clock budget. The sample is
only three completed cases per arm and establishes neither effectiveness nor
throughput superiority.

## Why add this protocol

Earlier campaigns fixed the number of selected cases and backend checks, but
the sequential and semantic-guided arms also preflighted a proposal batch while
MoonGrammata evaluated one generated seed per synchronous Target callback.
Equal selected-case counts therefore did not mean equal total work or elapsed
time. The existing replication evidence must not be retroactively described as
an equal-cost comparison.

## Runner

`scripts/run_live_feedback_wallclock_campaign.ps1` launches one complete case
at a time for each arm and rotates the first arm on each scheduler round. The
caller sets one identical `WallClockBudgetSecondsPerArm`. The charged arm time
is measured around the child process, so it includes PowerShell startup, the
control candidate generation/reference preflight and verifier, or the
MoonGrammata campaign/Target callback, respectively. It also includes the
child's report serialization. Selection-configuration generation happens
before the timed campaign; scheduler parsing/checkpoint overhead is reported
separately and is not charged to an individual arm.

The controls generate and preflight `ProposalBatchSize` candidates for each
selected case; MoonGrammata performs one generated-seed callback for each case.
This preserves each arm's intended policy, but equal wall-clock time is not
equal candidate count, equal verifier-call count, or equal internal search
work. The runner records completed cases, attempts, backend statuses, findings,
and per-arm elapsed time. Proposal diversity is secondary; genuine backend
mismatches, crashes, and known-regression triggers are the primary outcomes.
Because these arms use different selection objectives and disjoint seed
streams, the run is exploratory and not a paired causal estimate.

## Budget exhaustion and recovery

The parent process kills the active child process tree when the per-arm budget
expires. A cut-off attempt is recorded as censored and is not counted as a
completed case or retried. A partial raw report is not accepted as a completed
observation. Each completed one-case report is kept separately with its SHA-256
digest; the campaign checkpoint is atomically replaced after each scheduler
transition and records the active worker PID/start time.

`-Resume` requires identical configuration and harness inputs. It preserves
completed cases. If an interrupted in-flight worker left a complete report
within its remaining budget, the report can be recovered; if its runtime cannot
be determined safely, the remaining budget for that arm is conservatively
consumed and the attempt is censored. Such a resumed run can remain useful for
artifact recovery, but `wallClockUsageWithinOneSecondOfBudget` and the
interpretation field must be checked before claiming matched realized usage.

`MaximumAttemptsPerArm` is only a runaway guard. If any arm hits this cap before
using its budget, realized usage is not considered matched. The summary reports
both configured equal budgets and realized per-arm durations, and never
enables a throughput-superiority claim.

## Corrected real smoke run

The local test harness uses a test-only mock worker to check round rotation,
equal configured limits, process timeout/censoring, preserved case reports,
checkpoint writing, interruption recovery, semantic state carry-over, and
accurate aggregate candidate/callback/backend-check counts. The real run below
separately exercises generation, reference tracing, and the JS/Wasm/Wasm-GC
verification matrix.

The campaign used saved selection configuration SHA-256
`aa6b213ec6fd5bda0c6a4f28d3e3dffcec4cc41ef1945a16aff6e436f2d8e07a`, targets
JS/Wasm/Wasm-GC, depth 1, and 15 seconds per target. Each arm received a
30-second active-worker budget; controls evaluated proposal batches of two.
Candidate, proposal-order, MoonGrammata-generated-seed, campaign, and scheduler
order seed streams were disjoint. The run was on working-tree changes based on
`b4f26d0e50398b5fb47af0d0891c74a0856d3bea`; it is a local smoke, not a clean
CI result. Harness start/end digests matched:
`51114334a873756e9f289816dae758fb48a64f600896963ef2dbaa54f345b558`.

The top-level result file is
`.moonsmith/runs/live_feedback_wallclock_verified_final_20261019.json` (SHA-256
`d18fdf8f237f357247227c4aa5bd28de515df117681bbb46a99daa55c447b1ff`). The
configuration copy and every completed case report were persisted with hashes
in that result. Scheduler wall time was 90,601 ms, of which 296 ms was
checkpoint/scheduling overhead not charged to any arm. Arm worker times were
30,095 / 30,094 / 30,116 ms, all within one second of the configured 30,000
ms. Each arm completed three cases and its fourth attempt was stopped and
censored; it was not counted as an observation or retried. Each completed case
reported `consistent`, with JS, Wasm, and Wasm-GC succeeding, for nine
consistent cases and 27 successful backend executions total. No mismatch or
crash was observed in this tiny sample.

| Arm | Completed / attempts | Candidate or callback count | Backend checks | Distinct reference-path kinds |
| --- | ---: | ---: | ---: | ---: |
| Sequential | 3 / 4 (one censored) | 6 proposals | 9 | 11 |
| Semantic-guided | 3 / 4 (one censored) | 6 proposals | 9 | 11 |
| MoonGrammata | 3 / 4 (one censored) | 3 live callbacks | 9 | 9 |

Earlier corrected smoke report hashes (superseded; not the final run). All
completed cases reported `consistent`, each with `js:succeeded:0`,
`wasm:succeeded:0`, and `wasm-gc:succeeded:0`:

| Arm | Attempt 1 SHA-256 | Attempt 2 SHA-256 | Attempt 3 SHA-256 | Attempt 4 |
| --- | --- | --- | --- |
| Sequential | `4bd7b78a9c6a0548f4f2f30fe16b5c9ea88a0d5941a06f3433fbdab884f5bb02` | `922614580d85738c2c0d0c72af9276d1edc4c929cf78d44cec0f383818689d3f` | `57a792a8d3daffca0723783b93f694d522f1079793f9943a3a9284a62ccd645e` | Censored; no complete report |
| Semantic-guided | `4d99e84ada8912213ce545615787ed8b0e53e8342fe2eaffd7c84913f4b633db` | `1818d3241ec1a4eb045469de7339173723498d03646ef56ebf3f4479c6aa527f` | `49d3381f31d26ec6eb326f4732c3c82924270e8aba88e95a0de81fc36909d360` | Censored; no complete report |
| MoonGrammata | `6e11b8bd658fe4f2cb7b0daf2212d4533b5b6d39aa7ecbb741dfd268352bae19` | `4b86368aeb3e47102c759459d38410186f4596482fe3569ae88337236d4831b8` | Censored at budget; no complete report |

Final verified smoke report hashes (all nine completed cases reported
`consistent`; each has successful JS, Wasm, and Wasm-GC checks):

| Arm | Attempt 1 SHA-256 | Attempt 2 SHA-256 | Attempt 3 SHA-256 | Attempt 4 |
| --- | --- | --- | --- | --- |
| Sequential | `4bd7b78a9c6a0548f4f2f30fe16b5c9ea88a0d5941a06f3433fbdab884f5bb02` | `922614580d85738c2c0d0c72af9276d1edc4c929cf78d44cec0f383818689d3f` | `57a792a8d3daffca0723783b93f694d522f1079793f9943a3a9284a62ccd645e` | Censored; no complete report |
| Semantic-guided | `4d99e84ada8912213ce545615787ed8b0e53e8342fe2eaffd7c84913f4b633db` | `1818d3241ec1a4eb045469de7339173723498d03646ef56ebf3f4479c6aa527f` | `49d3381f31d26ec6eb326f4732c3c82924270e8aba88e95a0de81fc36909d360` | Censored; no complete report |
| MoonGrammata | `9db998e3133aca688501a26bd3a5aaad16c7d3821ae3284f6c032d0b5f55f9d0` | `eba3fdc395b3cbb5b8695607683a6d18ddad83712fe77de5476cabe9eb275d85` | `214fd74ee939f7bab66651ab49618d125aa66c8d7c74827a302df34f4b0141ff` | Censored; no complete report |

The second semantic-guided case received the first case's selected path kinds
(`bool-literal`, `not`), and the third received the accumulated first-two-case
set before making its selection. This confirms that feedback state crossed
isolated child processes. MoonGrammata was pinned to version
0.1.1, revision `d9cf3512b636fd45e941f30010d3fceb7cc2e4fc`; its synchronous
Target callback generated and verified each seed online, rather than consuming
a precomputed candidate result. This smoke only establishes that the live
callback and budgeted harness execute and preserve evidence; three
callbacks per arm cannot meaningfully compare discovery effectiveness or path
diversity.

### Depth-4 equal-wall-clock exploratory run

After the prototype passed hosted CI, a new depth-4 selection report was made
with two prescreen candidates, one selected case per control arm, the JS/Wasm/
Wasm-GC matrix, and a 30-second per-target timeout. The live campaign did not
reuse those candidate seeds: it used disjoint control proposal windows
(`10,000,000` and `11,000,000`), MoonGrammata seed range `12,000,000`–
`12,000,999`, separate proposal-order seeds (`13,000,000` and `14,000,000`),
campaign seed `15,000,000`, and scheduler-order seed `16,000,000`. Each arm
received a 300-second active-worker budget; control proposal batches were four.

The selection configuration SHA-256 is
`e1642b0b29d51ff439c7225a770814f4ff6a3ea7356994a99e8d7bb15bcbae14`. The
campaign JSON was retained locally at
`.moonsmith/runs/live_feedback_wallclock_depth4_5min_20261019.json`, SHA-256
`c568c823341a8890cfe9009cfdc09c622905890bca7b9b56db9c57d90b4b02c8`.
Its harness start/end digest was unchanged at
`51114334a873756e9f289816dae758fb48a64f600896963ef2dbaa54f345b558`.
Scheduler wall time was 902,834 ms, with 2,402 ms of unallocated scheduler /
checkpoint overhead. All per-arm active times were within one second of 300
seconds:

| Arm | Completed / attempts | Proposal or callback count | Backend checks | Unique reference path kinds | Findings |
| --- | ---: | ---: | ---: | ---: | --- |
| Sequential | 20 / 21 (1 censored) | 80 proposals | 60 | 53 | 20 consistent |
| Semantic-guided | 20 / 21 (1 censored) | 80 proposals | 60 | 53 | 20 consistent |
| MoonGrammata | 29 / 30 (1 censored) | 29 live callbacks | 87 | 53 | 29 consistent |

Every completed case reported successful JS, Wasm, and Wasm-GC execution; no
mismatch or crash was observed in the 69 completed cases. This is a small
local exploratory sample, not an effectiveness result. The equal time budget
does not equalize the amount or type of candidate work: controls preflighted
four proposals per selected case, whereas MoonGrammata performed one live
callback per generated seed. The common 53-kind union also saturates the
current reference-path vocabulary and cannot distinguish the arms here.
Preserved raw case reports and their hashes are indexed in the top-level JSON.
This run is not a clean-tree hosted experiment: the selection and campaign
were run locally from `ed1ca68` while the status document was being updated.

### Depth-6 equal-wall-clock exploratory run

A follow-up used the same JS/Wasm/Wasm-GC matrix and 30-second timeout, raising
generator depth to 6 and active-worker allowance to 600 seconds per arm. Fresh,
disjoint seed ranges were used: selection candidates from `17,000,000`, control
proposal windows from `18,000,000` and `19,000,000`, MoonGrammata seeds
`20,000,000`–`20,000,999`, proposal-order seeds `21,000,000` and `22,000,000`,
campaign seed `23,000,000`, and scheduler seed `24,000,000`. The campaign JSON
is retained locally at
`.moonsmith/runs/live_feedback_wallclock_depth6_10min_20261019.json`, SHA-256
`2b54869a3c947423b8315adeca0064968f01adf202103269e4f71307fdbf6dec`; the
selection configuration SHA-256 is
`fe3bd651b89cf383f3fc49f3a90e9a6526c0e8a7b4c8500c156a61f9db5cf279`. The
harness digest stayed at
`51114334a873756e9f289816dae758fb48a64f600896963ef2dbaa54f345b558`. All 139
indexed raw reports and the selection configuration independently matched
their recorded SHA-256 values.

| Arm | Completed / attempts | Proposal or callback count | Backend checks | Unique reference path kinds | Findings |
| --- | ---: | ---: | ---: | ---: | --- |
| Sequential | 40 / 41 (1 censored) | 160 proposals | 120 | 56 | 40 consistent |
| Semantic-guided | 41 / 42 (1 censored) | 164 proposals | 123 | 55 | 41 consistent |
| MoonGrammata | 58 / 59 (1 censored) | 58 live callbacks | 174 | 55 | 58 consistent |

Per-arm active times were 600,114 / 600,109 / 600,109 ms, within the
one-second tolerance. Scheduler time was 1,807,287 ms, with 6,955 ms of
unallocated scheduling/checkpoint overhead. All 417 backend executions
succeeded on JS, Wasm, and Wasm-GC; no mismatch or crash was observed in this
sample. Coverage changed as cases accrued (an early two-kind MoonGrammata lead
disappeared, then sequential surpassed it), ending at 56/55/55. This shows why
early snapshots cannot establish a stable advantage. Depth-4 and depth-6 path
unions differ only by reference paths observed in the added sample; neither is
a compiler bug. The selection report was created from `584e4f6` with the
untracked application draft as the only dirty item. The campaign digest stayed
stable. These are local exploratory runs, not clean-tree CI or powered
effectiveness comparisons.

### Depth-8 equal-wall-clock exploratory run

The next local run kept the same three backends and 30-second target timeout,
with generator depth 8 and 600 seconds of active-worker time per arm. Seed
streams were fresh and disjoint: selection `25,000,000`, sequential proposals
`26,000,000`, semantic-guided proposals `27,000,000`, MoonGrammata
`28,000,000`–`28,000,999`, control-order seeds `29,000,000` and `30,000,000`,
campaign seed `31,000,000`, and scheduler seed `32,000,000`. The report was
retained locally at
`.moonsmith/runs/live_feedback_wallclock_depth8_10min_20261019.json`, SHA-256
`1e1b22105c5b730f51e5d62de5b0998120609f8aa095cd3d0aadefc30e0ac249`; selection
configuration SHA-256:
`5a7dd49065bd82d123bb7c061cc9088e14765864668f7bdb9fc9fdd56b0e2718`. The
harness digest remained `51114334a873756e9f289816dae758fb48a64f600896963ef2dbaa54f345b558`.
All 137 raw reports and the selection configuration matched their indexed
hashes.

| Arm | Completed / attempts | Proposal or callback count | Backend checks | Unique reference path kinds | Findings |
| --- | ---: | ---: | ---: | ---: | --- |
| Sequential | 40 / 41 (1 censored) | 160 proposals | 120 | 55 | 40 consistent |
| Semantic-guided | 40 / 40 | 160 proposals | 120 | 56 | 40 consistent |
| MoonGrammata | 57 / 58 (1 censored) | 57 live callbacks | 171 | 55 | 57 consistent |

Active times were 600,092 / 600,049 / 600,130 ms, within 130 ms of each other;
scheduler time was 1,808,295 ms with 8,024 ms of unallocated scheduling /
checkpoint overhead. All 411 backend executions succeeded on JS, Wasm, and
Wasm-GC. No mismatch or crash was observed. The descriptive path-kind union
was 55/56/55, so the single extra semantic-guided kind in this sample is not
evidence of a repeatable effectiveness difference. This was a local run from
`e92ba82`; the only worktree dirt was the preserved, untracked application
draft. As with the previous runs, it is exploratory and not a powered
effectiveness comparison.

### Depth-10 equal-wall-clock exploratory run

The next run kept the JS/Wasm/Wasm-GC matrix, a 30-second timeout per target,
and 600 seconds of active wall-clock time per arm, at generator depth 10. Fresh
seed streams were used: selection starts at `33,000,000`, sequential proposals
at `34,000,000`, semantic-guided proposals at `35,000,000`, MoonGrammata at
`36,000,000`–`36,000,999`, control proposal-order seeds `37,000,000` and
`38,000,000`, campaign seed `39,000,000`, and scheduler-order seed
`40,000,000`. The selection configuration SHA-256 is
`befdd522ab8cfbd9a17d2116ff3ff52f596e382d318c718393a1d73190deea83`. The
campaign JSON is retained locally at
`.moonsmith/runs/live_feedback_wallclock_depth10_10min_20261019.json`,
SHA-256 `d1ba660c3217f6f9a55690bf77ccf52a314b3266ecc83ba4bc0a8e1bc3875187`.
All 138 indexed raw-case reports and the selection configuration independently
matched their recorded SHA-256 values. The harness digest remained unchanged at
`51114334a873756e9f289816dae758fb48a64f600896963ef2dbaa54f345b558`.

| Arm | Completed / attempts | Proposals or live callbacks | Backend checks | Unique reference path kinds | Outcome / accounting |
| --- | ---: | ---: | ---: | ---: | --- |
| Sequential | 40 / 41 (1 censored) | 160 proposals | 120 | 56 | 40 consistent |
| Semantic-guided | 39 / 43 (3 no-valid-preflight windows, 1 censored) | 156 proposals | 117 | 56 | 39 consistent |
| MoonGrammata | 59 / 60 (1 censored) | 59 live callbacks | 141 | 56 | 47 consistent, 12 generator-limit |

Each arm used 600,108 / 600,098 / 600,110 ms, respectively; all are within
one second of the configured budget. Scheduler time was 1,807,002 ms with
6,686 ms of scheduler/checkpoint overhead not charged to an arm. There were 144
interleaved attempts in the checkpoint. The three semantic-guided
`no-valid-preflight` windows raised the selector's explicit “Proposal window
has no candidate with a completed reference preflight” condition; these are
selection/preflight failures, not backend executions or compiler mismatches.
Each consumed time and remains counted in attempts, but did not create an
indexed case report. One remaining attempt per arm was censored at the budget.
Post-run audit found that this depth-10 JSON's historical `censored` boolean
also marked those three fully observed, nonzero-exit selector windows as
censored because the old expression classified every missing successful report
that way. The stderr/status still identifies their actual cause; the old field
must not be used to infer that they were time-censored. The harness now sets
`censored` only when the scheduler kills a task at the budget, emits
`no-valid-preflight-candidate-window` as a separate status, and aggregates
per-attempt status counts. A mock regression exercises this exact failure and
checks that the attempt is not marked censored. This correction changes future
report bookkeeping, not the selection or backend behavior in this completed
run; its preserved raw JSON and hash remain untouched.

Twelve of the 59 MoonGrammata callbacks generated sources above MoonSmith's
16,300-line safety bound (16,522–31,794 lines); they were reported as
`generator-limit` before reference evaluation or backend compilation. This is
an intentional bounded-input exclusion, not a compiler result or newly found
issue. The remaining 47 MoonGrammata cases, 40 sequential cases, and 39
semantic-guided cases made 378 total JS/Wasm/Wasm-GC backend checks, all
successful with matching reference output. No backend mismatch or crash was
observed among checked executions. Each arm's path-kind set was the same 56
kinds, so path-count differences do not separate them at this depth. The
attempt and callback counts are not equivalent units of candidate work, and
the 12 pre-backend exclusions further limit throughput comparisons. This is
local exploratory evidence only, not an effectiveness result. The selection
configuration came from `e92ba82`; the worktree was dirty solely because the
untracked application draft was preserved. Raw reports remain local and
ignored; only this indexed summary and hashes are committed.

### Depth-10 short replication after accounting correction

After fixing the historical censor-flag accounting, a fresh depth-10 run used
the same JS/Wasm/Wasm-GC targets and 30-second per-target timeout, with 300
seconds of active time per arm. Its seed streams were disjoint from the prior
run: selection `43,000,000`, sequential `44,000,000`, semantic-guided
`45,000,000`, MoonGrammata `46,000,000`–`46,000,999`, control-order seeds
`47,000,000` and `48,000,000`, campaign `49,000,000`, and scheduler
`50,000,000`. Selection configuration SHA-256:
`180b5c3da2ec8c1f99bcf87f4c8e47ac26fc643a60d2dec7c324524eddfdf707`. The
local campaign report
`.moonsmith/runs/live_feedback_wallclock_depth10_rep2_5min_20261019.json` has
SHA-256 `8cd26f5570370200a58789e479b2f5671c7225cda63bf5b1bdfaf34ac2e10af8`.
All 70 indexed raw reports and the selection configuration matched their
recorded hashes. The new harness digest was stable at
`67e24bfc29c638ac8f6956f6c9080e77d316cd69a08748991cad1e8b07a0cc20`.

| Arm | Completed / attempts | Proposals or callbacks | Backend checks | Unique path kinds | Outcomes |
| --- | ---: | ---: | ---: | ---: | --- |
| Sequential | 20 / 21 (1 censored) | 80 proposals | 60 | 56 | 20 consistent |
| Semantic-guided | 19 / 20 (1 censored) | 76 proposals | 57 | 56 | 19 consistent |
| MoonGrammata | 31 / 32 (1 censored) | 31 live callbacks | 69 | 55 | 23 consistent, 8 generator-limit |

Active times were 300,101 / 300,163 / 300,100 ms (within 163 ms); scheduler
time was 902,901 ms with 2,537 ms of uncharged checkpoint/scheduling overhead.
All 186 backend checks succeeded and matched the reference; no mismatch or
crash was observed. Eight MoonGrammata callbacks exceeded the 16,300-line
source bound and therefore did not compile. There were no
`no-valid-preflight-candidate-window` outcomes in this replicate, unlike the
three such semantic-guided attempts in the longer depth-10 run. This supports
only that the selector outcome can vary across independent proposal windows,
not a rate estimate. The 56/56/55 path-kind sets again nearly saturated the
same reference vocabulary and are not evidence of an advantage. The old
depth-10 summary remains immutable; this replicate exercises the corrected
`censored` and per-attempt status bookkeeping. It is still a short local
exploratory sample, not an effectiveness comparison.

An earlier corrected smoke report (before this final run) exposed a
summary-accounting defect: raw reports contained the right counts but the
per-arm aggregate fields serialized as zero. The explicit aggregation fix is
covered by the mock regression. The results above are from the rerun after that
fix, and the table's counts were cross-checked against each preserved case
report.

### Offline artifact and aggregate audit

`scripts/audit_live_feedback_wallclock_report.ps1 -ReportPath <summary.json>`
is a read-only integrity check for a completed wall-clock report. It verifies
the saved selection-configuration hash, every indexed raw-case report hash,
the one-to-one mapping from completed attempts to indexed reports, and the
per-arm attempt/completion/work/backend/path aggregates. It also recomputes
whether equal active-time usage was actually realized, including attempt-cap
and interrupted-run exclusions. Its output explicitly limits its scope to
artifact/summary integrity: it does not rerun MoonBit, replay target compilers,
or establish that a fuzzer is effective.

The corrected 5-minute depth-10 replication and the 30-second final smoke
report both pass this audit (70 and 9 raw case reports, respectively). The
earlier 10-minute report is intentionally rejected: its historically incorrect
`censored` flags on non-timeout proposal-window failures violate the recorded
attempt semantics. That legacy report remains immutable and is described with
the correction in the preceding section; the auditor does not silently repair
it. Regression tests also prove that editing an aggregate count, falsifying a
timeout/censor flag, or mutating an indexed raw report makes the audit fail.

### Early smoke runs: excluded after discovering a state-reset defect

The initial JS-only run used a 30-second budget per arm and completed 3, 3, and
4 cases (all `consistent` on JS) at 30,350 / 30,106 / 30,071 ms. The following
three-backend run used 60 seconds per arm and completed 6 / 5 / 6 cases, all
consistent on JS, Wasm, and Wasm-GC. Both confirmed process budgeting and
report persistence, but review found the isolated control process reset the
semantic-guided arm's `seenPathKinds` between cases. The arm was therefore not
the intended across-round feedback policy. These runs are diagnostic only,
excluded from any arm comparison, and must not be cited as effectiveness or
path-diversity evidence. The runner was amended to checkpoint and pass the
selected-path state into each one-case control invocation; a mock regression
test now asserts that the second semantic-guided case receives the first case's
paths. The corrected smoke run is described above.

Example parameters for a future local run (choose fresh, disjoint seed ranges
and a new output filename):

```powershell
./scripts/run_live_feedback_wallclock_campaign.ps1 `
  -SelectionReport .moonsmith/runs/selection-current.json `
  -SequentialSeedStart 1000000 -SemanticGuidedSeedStart 2000000 `
  -MoonGrammataSeedMinimum 3000000 -MoonGrammataSeedMaximum 3001000 `
  -WallClockBudgetSecondsPerArm 900 -ProposalBatchSize 4 `
  -MaximumAttemptsPerArm 1000 `
  -SequentialProposalOrderSeed 4000000 -SemanticProposalOrderSeed 4001000 `
  -MoonGrammataCampaignSeed 5000000 -RoundRobinOrderSeed 6000000 `
  -OutputPath .moonsmith/runs/live-feedback-wallclock-20261019.json
```

Before scaling up, use the validated protocol and require inspection/replay of
all raw reports. Reject a run as an effectiveness comparison if the harness
changes mid-run, configured or realized per-arm usage is unmatched, or raw
artifacts cannot be replayed.
