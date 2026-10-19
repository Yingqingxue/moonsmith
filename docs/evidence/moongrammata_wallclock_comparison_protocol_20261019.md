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

An earlier corrected smoke report (before this final run) exposed a
summary-accounting defect: raw reports contained the right counts but the
per-arm aggregate fields serialized as zero. The explicit aggregation fix is
covered by the mock regression. The results above are from the rerun after that
fix, and the table's counts were cross-checked against each preserved case
report.

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
