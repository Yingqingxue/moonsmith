param(
    [Parameter()][ValidateRange(17, 10000)][int]$ExecutionBudget = 18,
    [Parameter()][long]$Seed = 20261018
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $PSScriptRoot 'run_moongrammata_selection.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('moongrammata-live-target-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $mockVerifier = Join-Path $testRoot 'mock-verifier.ps1'
    $mockSource = @'
param(
    [int]$Seed,
    [int]$Depth,
    [string[]]$Targets,
    [int]$TimeoutSeconds,
    [switch]$NoPersist
)
$diverges = $Seed % 2 -eq 0
$generatorLimit = $Seed % 7 -eq 0
$runs = [System.Collections.Generic.List[object]]::new()
if (-not $generatorLimit) {
    foreach ($target in $Targets) {
        $failed = $diverges -and $target -eq 'wasm-gc'
        $runs.Add([pscustomobject]@{
            target = $target
            status = if ($failed) { 'runtime-failed' } else { 'succeeded' }
            exitCode = if ($failed) { 1 } else { 0 }
            durationMs = 10
            executionAttempted = $true
        })
    }
}
$report = [pscustomobject]@{
    seed = $Seed
    referenceChecked = -not $generatorLimit
    sourceLineCount = 40 + ($Seed % 60)
    generationDurationMs = 5
    referenceEvaluationDurationMs = if ($generatorLimit) { 0 } else { 7 }
    referenceTraceDurationMs = if ($generatorLimit) { 0 } else { 3 }
    finding = if ($generatorLimit) { 'generator-limit' } elseif ($diverges) { 'output-mismatch' } else { 'consistent' }
    referenceTrace = if ($generatorLimit) { $null } else { [pscustomobject]@{ visited = @("live-only-seed-$Seed") } }
    runs = $runs.ToArray()
}
$report | ConvertTo-Json -Depth 5 -Compress
if ($diverges) { exit 1 }
'@
    [IO.File]::WriteAllText($mockVerifier, $mockSource, [Text.UTF8Encoding]::new($false))
    $candidatePool = foreach ($candidateSeed in 20000..20099) {
        [pscustomobject]@{
            seed = $candidateSeed
            sizeQuartile = [int](($candidateSeed - 20000) % 4)
            paths = @("cached-path-$($candidateSeed % 5)")
        }
    }
    $candidateBySeed = @{}
    foreach ($candidate in $candidatePool) { $candidateBySeed[[string]$candidate.seed] = $candidate }
    $baselineSeeds = @(20000..20019)
    $guidedSeeds = @(20040..20059)
    $baselineCases = foreach ($caseSeed in $baselineSeeds) {
        [pscustomobject]@{ seed = $caseSeed; referencePathKinds = @($candidateBySeed[[string]$caseSeed].paths) }
    }
    $guidedCases = foreach ($caseSeed in $guidedSeeds) {
        [pscustomobject]@{ seed = $caseSeed; referencePathKinds = @($candidateBySeed[[string]$caseSeed].paths) }
    }
    $digestParts = foreach ($relativePath in @(
        'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt',
        'cmd/main/main.mbt', 'scripts/verify_seed.ps1',
        'scripts/semantic_selection.ps1', 'scripts/compare_semantic_selection.ps1'
    )) {
        $path = Join-Path $projectRoot $relativePath
        "${relativePath}:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
    }
    $digestBytes = [Text.Encoding]::UTF8.GetBytes(($digestParts -join "`n"))
    $harnessDigest = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($digestBytes)).ToLowerInvariant()
    $inputPath = Join-Path $testRoot 'pool-report.json'
    $fixture = [pscustomobject]@{
        schemaVersion = 1
        candidatePool = @($candidatePool)
        configuredTargets = @('js', 'wasm', 'wasm-gc')
        depth = 2
        timeoutSeconds = 2
        harnessChangedDuringRun = $false
        harnessDigestEnd = $harnessDigest
        equalBackendExecutionBudget = $true
        sourceSizeQuartilesMatched = $true
        baseline = [pscustomobject]@{
            cases = @($baselineCases)
            metrics = [pscustomobject]@{ distinctReferencePaths = 5 }
        }
        guided = [pscustomobject]@{
            cases = @($guidedCases)
            metrics = [pscustomobject]@{ distinctReferencePaths = 5 }
        }
        prescreenDurationMs = 0
        executionBudgetCasesPerArm = 20
        expectedBackendExecutionsPerArm = 60
    }
    [IO.File]::WriteAllText($inputPath, ($fixture | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $outputPath = Join-Path $testRoot 'live-result.json'
    $staticOutputPath = Join-Path $testRoot 'static-result.json'
    $generatedOutputPath = Join-Path $testRoot 'generated-live-result.json'
    $null = & $runner -InputReport $inputPath -ExecutionBudget $ExecutionBudget `
        -Seed $Seed -OutputPath $staticOutputPath
    if ($LASTEXITCODE -ne 0) { throw 'MoonGrammata cached-feedback control failed.' }
    $null = & $runner -InputReport $inputPath -ExecutionBudget $ExecutionBudget `
        -Seed $Seed -OutputPath $outputPath -LiveTarget -LiveVerifierScript $mockVerifier
    if ($LASTEXITCODE -ne 0) { throw 'MoonGrammata live-target runner failed.' }
    $null = & $runner -InputReport $inputPath -ExecutionBudget $ExecutionBudget `
        -Seed $Seed -OutputPath $generatedOutputPath -LiveGeneratedSeeds `
        -GeneratedSeedMinimum 100000 -GeneratedSeedMaximum 1000000 -LiveVerifierScript $mockVerifier
    if ($LASTEXITCODE -ne 0) { throw 'MoonGrammata live-generated-seed runner failed.' }
    $result = Get-Content -LiteralPath $outputPath -Raw -Encoding utf8 | ConvertFrom-Json
    $generatedResult = Get-Content -LiteralPath $generatedOutputPath -Raw -Encoding utf8 | ConvertFrom-Json
    $staticResult = Get-Content -LiteralPath $staticOutputPath -Raw -Encoding utf8 | ConvertFrom-Json
    $pool = Get-Content -LiteralPath $inputPath -Raw -Encoding utf8 | ConvertFrom-Json
    $poolPaths = @($pool.candidatePool | ForEach-Object { $_.paths } | Sort-Object -Unique)
    if ($result.moonGrammata.feedbackSource -notlike 'synchronous per-Target callback:*' -or
        $result.moonGrammata.verifierKind -ne 'test-double' -or
        [int]$result.moonGrammata.completedExecutions -ne $ExecutionBudget -or
        [int]$result.moonGrammata.liveEvaluations -ne $ExecutionBudget -or
        [int]$result.moonGrammata.liveFailures -ne 0 -or
        [int]$result.moonGrammata.uniqueCandidatesObserved -gt $ExecutionBudget) {
        throw "The campaign did not synchronously evaluate each target callback with the verifier (source=$($result.moonGrammata.feedbackSource), kind=$($result.moonGrammata.verifierKind), completed=$($result.moonGrammata.completedExecutions), calls=$($result.moonGrammata.liveEvaluations), failures=$($result.moonGrammata.liveFailures), error=$($result.moonGrammata.liveLastError))."
    }
    if ($null -ne $result.moonSmith.commonUniqueCandidateBudget -or
        $null -ne $result.moonSmith.moonGrammataPathKindsAtCommonUniqueBudget) {
        throw 'Live online results were incorrectly exposed as comparable to the cached-feedback arms.'
    }
    $livePaths = @($result.moonGrammata.liveReferencePathKinds)
    if ($result.moonGrammata.distinctReferencePathKinds -le 0 -or
        @($result.moonGrammata.selectedSeeds).Count -eq 0 -or
        $result.interpretation -notlike 'Online-feedback wiring prototype:*' -or
        $result.interpretation -notlike '*fixed seed pool*' -or
        $result.interpretation -notlike '*does not establish a fair end-to-end effectiveness*') {
        throw 'Live feedback did not produce measured path data or preserve scope caveats.'
    }
    if (@($result.moonGrammata.sourceSizeQuartileCounts.PSObject.Properties).Count -eq 0 -or
        @($poolPaths).Count -eq 0) {
        throw 'The live feedback result lost the pool and selection accounting context.'
    }
    if ($livePaths.Count -le 0 -or
        @($result.moonGrammata.liveFindings) -notcontains 'consistent' -or
        @($result.moonGrammata.liveFindings) -notcontains 'output-mismatch' -or
        @($result.moonGrammata.liveFindings) -notcontains 'generator-limit' -or
        [int]$result.moonGrammata.liveGeneratorLimitObservations -ne
            @($result.moonGrammata.targetExecutionOrder | Where-Object { $_ % 7 -eq 0 }).Count -or
        [int]$result.moonGrammata.liveReferenceChecks -ne
            ($ExecutionBudget - [int]$result.moonGrammata.liveGeneratorLimitObservations) -or
        [int]$result.moonGrammata.liveBackendExecutions -ne
            ($ExecutionBudget - [int]$result.moonGrammata.liveGeneratorLimitObservations) * 3 -or
        @($result.moonGrammata.liveBackendOutcomes) -notcontains 'wasm-gc:runtime-failed:1' -or
        @($result.moonGrammata.liveBackendOutcomes | Where-Object { $_ -notlike 'wasm-gc:runtime-failed:1' -and $_ -notlike '*:succeeded:0' }).Count -gt 0 -or
        @($livePaths | Where-Object { $_ -notlike 'live-only-seed-*' }).Count -gt 0 -or
        @($livePaths | Where-Object { $_ -in $poolPaths }).Count -gt 0) {
        throw 'Target feedback did not come from the runtime verifier response instead of cached pool features.'
    }
    $staticOrder = @($staticResult.moonGrammata.targetExecutionOrder)
    $liveOrder = @($result.moonGrammata.targetExecutionOrder)
    if ($staticOrder.Count -ne $ExecutionBudget -or $liveOrder.Count -ne $ExecutionBudget -or
        (@($staticOrder | Select-Object -First 16) -join ',') -ne
            (@($liveOrder | Select-Object -First 16) -join ',')) {
        throw 'Cached and live campaigns did not use the same deterministic initial sequence.'
    }
    if (($staticOrder | Select-Object -Last ($ExecutionBudget - 16) | Join-String -Separator ',') -eq
        ($liveOrder | Select-Object -Last ($ExecutionBudget - 16) | Join-String -Separator ',')) {
        throw 'Runtime target feedback did not alter post-initial corpus scheduling in the deterministic test.'
    }
    $staleInputPath = Join-Path $testRoot 'stale-pool.json'
    $staleOutputPath = Join-Path $testRoot 'stale-live.json'
    $staleFixture = Get-Content -LiteralPath $inputPath -Raw -Encoding utf8 | ConvertFrom-Json
    $staleFixture.harnessDigestEnd = 'deliberately-stale-test-digest'
    [IO.File]::WriteAllText($staleInputPath, ($staleFixture | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    $staleRejected = $false
    try {
        $null = & $runner -InputReport $staleInputPath -ExecutionBudget $ExecutionBudget `
            -Seed $Seed -OutputPath $staleOutputPath -LiveTarget
        if ($LASTEXITCODE -ne 0) { throw 'Stale live-target test runner failed unexpectedly.' }
    }
    catch {
        if ($_.Exception.Message -notmatch 'unchanged candidate-generation, reference, and verifier harness') {
            throw
        }
        $staleRejected = $true
    }
    if (-not $staleRejected -or (Test-Path -LiteralPath $staleOutputPath)) {
        throw 'Live target mode did not reject stale generated-pool metadata before writing a result.'
    }
    $generatedOrder = @($generatedResult.moonGrammata.targetExecutionOrder)
    $generatedObservations = @($generatedResult.moonGrammata.observations)
    if ($generatedResult.moonGrammata.generatorMode -ne 'integer-seed-range' -or
        $generatedResult.moonGrammataApi -notlike 'GrammarBuilder::integer*' -or
        $generatedResult.moonGrammata.poolSize -ne 0 -or
        $null -ne $generatedResult.moonGrammata.selectedSeeds -and
            @($generatedResult.moonGrammata.selectedSeeds | Where-Object { $_ -lt 100000 -or $_ -gt 1000000 }).Count -gt 0 -or
        $generatedOrder.Count -ne $ExecutionBudget -or
        $generatedObservations.Count -ne $ExecutionBudget -or
        (@($generatedObservations.seed) -join ',') -ne ($generatedOrder -join ',') -or
        @($generatedOrder | Where-Object { $_ -lt 100000 -or $_ -gt 1000000 }).Count -gt 0 -or
        [int]$generatedResult.moonGrammata.liveEvaluations -ne $ExecutionBudget -or
        [int]$generatedResult.moonGrammata.liveFailures -ne 0 -or
        [int]$generatedResult.moonGrammata.liveGeneratorLimitObservations -ne
            @($generatedOrder | Where-Object { $_ % 7 -eq 0 }).Count -or
        [int]$generatedResult.moonGrammata.liveReferenceChecks -ne
            ($ExecutionBudget - [int]$generatedResult.moonGrammata.liveGeneratorLimitObservations) -or
        [int]$generatedResult.moonGrammata.liveBackendExecutions -ne
            ($ExecutionBudget - [int]$generatedResult.moonGrammata.liveGeneratorLimitObservations) * 3 -or
        @($generatedResult.moonGrammata.liveSourceSizeBuckets).Count -eq 0 -or
        $null -ne $generatedResult.moonSmith.commonUniqueCandidateBudget -or
        $generatedResult.interpretation -notlike 'Live integer-seed grammar prototype:*') {
        throw 'Integer grammar mode did not generate in-range inputs, return live feedback, or suppress invalid comparisons.'
    }
    foreach ($observation in $generatedObservations) {
        if ($observation.seed -lt 100000 -or $observation.seed -gt 1000000) {
            throw 'A per-callback observation contains a seed outside the configured range.'
        }
        if ($observation.finding -eq 'generator-limit' -and
            ($observation.referenceStatus -ne 'not-checked' -or
             $observation.referenceEvaluationDurationMs -ne 0 -or
             $observation.referenceTraceDurationMs -ne 0 -or
             @($observation.backendRuns).Count -ne 0)) {
            throw 'A generator-limit observation was misreported as an executed verifier case.'
        }
        if ($observation.finding -ne 'generator-limit' -and
            ($observation.referenceStatus -ne 'checked' -or
             $observation.generationDurationMs -ne 5 -or
             $observation.referenceEvaluationDurationMs -ne 7 -or
             $observation.referenceTraceDurationMs -ne 3 -or
             @($observation.backendRuns).Count -ne 3)) {
            throw 'A completed observation is missing its reference or backend results.'
        }
    }
    if ($generatedResult.moonGrammata.liveGenerationDurationMs -ne 5 * $ExecutionBudget -or
        $generatedResult.moonGrammata.liveReferenceEvaluationDurationMs -ne 7 *
            [int]$generatedResult.moonGrammata.liveReferenceChecks -or
        $generatedResult.moonGrammata.liveReferenceTraceDurationMs -ne 3 *
            [int]$generatedResult.moonGrammata.liveReferenceChecks -or
        $generatedResult.moonGrammata.liveBackendBuildAndExecutionDurationMs -ne
            30 * [int]$generatedResult.moonGrammata.liveReferenceChecks -or
        $generatedResult.moonGrammata.liveVerifierResidualDurationMs -lt 0 -or
        $generatedResult.moonGrammata.liveCampaignWallClockMs -lt
            $generatedResult.moonGrammata.liveVerifierDurationMs) {
        throw 'Online campaign phase timings are incomplete or do not reconcile with callback totals.'
    }
    if (@($generatedOrder | Where-Object { $_ -in $pool.candidatePool.seed }).Count -gt 0) {
        throw 'Integer grammar mode unexpectedly reused an identifier from the cached candidate pool.'
    }
    [pscustomobject]@{
        passed = $true
        executionBudget = $ExecutionBudget
        synchronousLiveCallbackCount = [int]$result.moonGrammata.liveEvaluations
        postInitialScheduleChanged = $true
        mockVerifierUsed = $true
        stalePoolRejected = $staleRejected
        generatedSeedModePassed = $true
        generatedSeedRange = '100000..1000000'
        generatedLimitObservations = [int]$generatedResult.moonGrammata.liveGeneratorLimitObservations
        onlinePathFeatureCount = $livePaths.Count
        liveDurationRecorded = ([long]$result.moonGrammata.liveVerifierDurationMs -ge 0)
        fixedPoolCaveatRetained = $true
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
