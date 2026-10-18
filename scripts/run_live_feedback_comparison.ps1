param(
    [Parameter(Mandatory)][string]$SelectionReport,
    [Parameter(Mandatory)][long]$MoonGrammataSeed,
    [Parameter()][string]$OutputPath = '',
    [Parameter()][string]$LiveVerifierScript = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$selectionPath = (Resolve-Path -LiteralPath $SelectionReport -ErrorAction Stop).Path
$selection = Get-Content -LiteralPath $selectionPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($selection.schemaVersion -ne 1 -or -not $selection.equalBackendExecutionBudget -or
    $selection.harnessChangedDuringRun -or -not $selection.sourceSizeQuartilesMatched) {
    throw 'Selection report must contain complete, harness-stable, size-matched sequential and semantic-guided live-verification arms.'
}
$budget = [int]$selection.executionBudgetCasesPerArm
$targets = @($selection.configuredTargets | ForEach-Object { [string]$_ })
$expectedBackendExecutions = $budget * $targets.Count
if ($budget -le 0 -or $targets.Count -eq 0 -or
    $selection.baseline.cases.Count -ne $budget -or
    $selection.guided.cases.Count -ne $budget -or
    [int]$selection.baseline.metrics.backendExecutions -ne $expectedBackendExecutions -or
    [int]$selection.guided.metrics.backendExecutions -ne $expectedBackendExecutions) {
    throw 'Selection report arms do not meet the shared case and backend-execution budget.'
}
if ($selection.candidatePool.Count -lt $budget -or
    @($selection.candidatePool.seed | Sort-Object -Unique).Count -ne $selection.candidatePool.Count) {
    throw 'Selection report does not provide a unique common candidate-seed pool.'
}
$candidateSeedSet = @{}
foreach ($candidate in $selection.candidatePool) { $candidateSeedSet[[string]$candidate.seed] = $true }
foreach ($armName in @('baseline', 'guided')) {
    $arm = $selection.$armName
    $armSeeds = @($arm.seeds | ForEach-Object { [string]$_ })
    $caseSeeds = @($arm.cases | ForEach-Object { [string]$_.seed })
    if ($armSeeds.Count -ne $budget -or @($armSeeds | Sort-Object -Unique).Count -ne $budget -or
        $caseSeeds.Count -ne $budget -or @($caseSeeds | Sort-Object -Unique).Count -ne $budget -or
        @($armSeeds | Where-Object { -not $candidateSeedSet.ContainsKey($_) }).Count -gt 0 -or
        @($caseSeeds | Where-Object { -not $candidateSeedSet.ContainsKey($_) }).Count -gt 0) {
        throw "Selection report $armName arm must contain $budget unique in-pool selections and verifier records."
    }
}
foreach ($target in $targets) {
    foreach ($armName in @('baseline', 'guided')) {
        $statuses = @($selection.$armName.cases | ForEach-Object { $_.backendStatuses })
        $targetRuns = @($statuses | Where-Object { [string]$_ -like "$target`:*" })
        if ($targetRuns.Count -ne $budget) {
            throw "Selection report $armName arm has $($targetRuns.Count) recorded statuses for target $target, expected $budget."
        }
    }
}

$outputPath = if ($OutputPath) {
    [IO.Path]::GetFullPath($OutputPath)
} else {
    Join-Path $projectRoot '.moonsmith\runs\live-feedback-comparison.json'
}
$outputDirectory = Split-Path -Parent $outputPath
if ($outputDirectory) { New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null }
$livePath = [IO.Path]::Combine(
    $outputDirectory,
    ([IO.Path]::GetFileNameWithoutExtension($outputPath) + '.moongrammata.json')
)
$runner = Join-Path $PSScriptRoot 'run_moongrammata_selection.ps1'
$timer = [System.Diagnostics.Stopwatch]::StartNew()
$runnerArguments = @{
    InputReport = $selectionPath
    ExecutionBudget = $budget
    Seed = $MoonGrammataSeed
    OutputPath = $livePath
    LiveTarget = $true
}
if ($LiveVerifierScript) { $runnerArguments.LiveVerifierScript = $LiveVerifierScript }
$null = & $runner @runnerArguments
$runnerExitCode = $LASTEXITCODE
$timer.Stop()
if ($runnerExitCode -ne 0) {
    throw "Live MoonGrammata target run failed with exit code $runnerExitCode."
}
$live = Get-Content -LiteralPath $livePath -Raw -Encoding utf8 | ConvertFrom-Json
$observations = @($live.moonGrammata.observations)
if ($observations.Count -ne $budget -or
    [int]$live.moonGrammata.liveReferenceChecks -ne $budget -or
    [int]$live.moonGrammata.liveBackendExecutions -ne $expectedBackendExecutions -or
    @($live.moonGrammata.selectedSeeds | Sort-Object -Unique).Count -ne $budget -or
    @($live.moonGrammata.selectedSeeds | Where-Object { -not $candidateSeedSet.ContainsKey([string]$_) }).Count -gt 0) {
    throw 'Live MoonGrammata report did not complete the shared reference-check and backend-execution budgets.'
}
foreach ($target in $targets) {
    $attempts = @($observations.backendRuns | Where-Object {
        $_.target -eq $target -and $_.executionAttempted
    }).Count
    if ($attempts -ne $budget) {
        throw "Live MoonGrammata made $attempts backend attempts for target $target, expected $budget."
    }
}

function Get-FindingCounts {
    param([object[]]$Cases, [string]$Property = 'finding')
    $counts = @{}
    foreach ($case in $Cases) {
        $key = [string]$case.$Property
        if (-not $counts.ContainsKey($key)) { $counts[$key] = 0 }
        $counts[$key]++
    }
    return $counts
}

function Get-BackendStatusCounts {
    param([object[]]$Cases, [string]$CollectionProperty)
    $counts = @{}
    foreach ($case in $Cases) {
        foreach ($run in @($case.$CollectionProperty)) {
            if ($run -is [string]) {
                $parts = $run -split ':', 2
                if ($parts.Count -ne 2) { throw "Malformed backend status: $run" }
                $key = "{0}:{1}" -f $parts[0], $parts[1]
            } else {
                $key = "{0}:{1}:{2}" -f $run.target, $run.status, $run.exitCode
            }
            if (-not $counts.ContainsKey($key)) { $counts[$key] = 0 }
            $counts[$key]++
        }
    }
    return $counts
}

$baselineCases = @($selection.baseline.cases)
$guidedCases = @($selection.guided.cases)
$relativeSelectionPath = [IO.Path]::GetRelativePath($projectRoot, $selectionPath)
$selectionPathForReport = if ($relativeSelectionPath -ne '..' -and
    -not $relativeSelectionPath.StartsWith('..' + [IO.Path]::DirectorySeparatorChar) -and
    -not [IO.Path]::IsPathRooted($relativeSelectionPath)) {
    $relativeSelectionPath
} else {
    $selectionPath
}
$moonGrammataBackendStatuses = Get-BackendStatusCounts -Cases $observations `
    -CollectionProperty 'backendRuns'
$result = [pscustomobject]@{
    schemaVersion = 1
    protocol = 'Common candidate pool, equal per-arm case/callback budget, same backend target matrix, depth, and per-target timeout. Sequential and semantic-guided choose from the frozen pool; MoonGrammata receives synchronous verifier feedback while selecting from that same pool. This is a matched backend-execution-budget pilot, not an equal-wall-clock stopping comparison.'
    candidatePoolReport = $selectionPathForReport
    candidatePoolReportSha256 = (Get-FileHash -LiteralPath $selectionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    candidateCount = $selection.candidateCount
    selectionSeedStart = $selection.seedStart
    moonGrammataCampaignSeed = $MoonGrammataSeed
    executionBudgetCasesPerArm = $budget
    configuredTargets = $targets
    depth = $selection.depth
    timeoutSecondsPerTarget = $selection.timeoutSeconds
    expectedBackendExecutionsPerArm = $expectedBackendExecutions
    commonUniqueCandidateOverlapCount = $selection.overlapSeedCount
    candidatePoolPrescreenDurationMs = $selection.prescreenDurationMs
    sequential = [pscustomobject]@{
        selectedSeeds = @($selection.baseline.seeds)
        distinctReferencePathKinds = $selection.baseline.metrics.distinctReferencePaths
        findings = $selection.baseline.metrics.findings
        backendExecutions = $selection.baseline.metrics.backendExecutions
        verifierWallClockMs = $selection.baseline.durationMs
        backendStatuses = Get-BackendStatusCounts -Cases $baselineCases -CollectionProperty 'backendStatuses'
    }
    semanticGuided = [pscustomobject]@{
        policy = $selection.method
        selectedSeeds = @($selection.guided.seeds)
        distinctReferencePathKinds = $selection.guided.metrics.distinctReferencePaths
        findings = $selection.guided.metrics.findings
        backendExecutions = $selection.guided.metrics.backendExecutions
        verifierWallClockMs = $selection.guided.durationMs
        backendStatuses = Get-BackendStatusCounts -Cases $guidedCases -CollectionProperty 'backendStatuses'
    }
    moonGrammata = [pscustomobject]@{
        selectionMode = $live.moonGrammata.generatorMode
        selectedUniqueSeeds = @($live.moonGrammata.selectedSeeds)
        callbackExecutionOrder = @($live.moonGrammata.targetExecutionOrder)
        callbackCount = $live.moonGrammata.liveEvaluations
        uniqueReferencePathKinds = $live.moonGrammata.distinctReferencePathKinds
        findings = Get-FindingCounts -Cases $observations
        backendStatuses = $moonGrammataBackendStatuses
        backendExecutions = $live.moonGrammata.liveBackendExecutions
        generatorLimitObservations = $live.moonGrammata.liveGeneratorLimitObservations
        generationDurationMs = $live.moonGrammata.liveGenerationDurationMs
        referenceEvaluationDurationMs = $live.moonGrammata.liveReferenceEvaluationDurationMs
        referenceTraceDurationMs = $live.moonGrammata.liveReferenceTraceDurationMs
        backendBuildAndExecutionDurationMs = $live.moonGrammata.liveBackendBuildAndExecutionDurationMs
        verifierResidualDurationMs = $live.moonGrammata.liveVerifierResidualDurationMs
        verifierWallClockMs = $live.moonGrammata.liveVerifierDurationMs
        campaignWallClockMs = $live.moonGrammata.liveCampaignWallClockMs
        observations = $observations
    }
    runnerWallClockMs = $timer.ElapsedMilliseconds
    candidatePoolPreparationIsSharedOverhead = $true
    wallClockThroughputClaimAllowed = $false
    caveat = 'The sequential and semantic-guided arms use a reference-trace prescreened pool, while MoonGrammata consumes verifier feedback online. The pool-prescreen cost is reported separately. Per-arm backend budgets and timeouts match, but total wall-clock stopping budgets do not; raw durations are descriptive and do not establish throughput superiority.'
    toolchainVersion = $selection.toolchainVersion
    moonGrammataVersion = $live.moonGrammataVersion
    moonGrammataRevision = $live.moonGrammataRevision
    verifierKind = $live.moonGrammata.verifierKind
}
$json = $result | ConvertTo-Json -Depth 12
[IO.File]::WriteAllText($outputPath, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
$json
