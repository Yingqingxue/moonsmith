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
$report = [pscustomobject]@{
    seed = $Seed
    referenceChecked = $true
    finding = if ($diverges) { 'output-mismatch' } else { 'consistent' }
    referenceTrace = [pscustomobject]@{ visited = @("live-only-seed-$Seed") }
    runs = @($Targets | ForEach-Object {
        $failed = $diverges -and $_ -eq 'wasm-gc'
        [pscustomobject]@{
            target = $_
            status = if ($failed) { 'runtime-failed' } else { 'succeeded' }
            exitCode = if ($failed) { 1 } else { 0 }
        }
    })
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
    $null = & $runner -InputReport $inputPath -ExecutionBudget $ExecutionBudget `
        -Seed $Seed -OutputPath $staticOutputPath
    if ($LASTEXITCODE -ne 0) { throw 'MoonGrammata cached-feedback control failed.' }
    $null = & $runner -InputReport $inputPath -ExecutionBudget $ExecutionBudget `
        -Seed $Seed -OutputPath $outputPath -LiveTarget -LiveVerifierScript $mockVerifier
    if ($LASTEXITCODE -ne 0) { throw 'MoonGrammata live-target runner failed.' }
    $result = Get-Content -LiteralPath $outputPath -Raw -Encoding utf8 | ConvertFrom-Json
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
    [pscustomobject]@{
        passed = $true
        executionBudget = $ExecutionBudget
        synchronousLiveCallbackCount = [int]$result.moonGrammata.liveEvaluations
        postInitialScheduleChanged = $true
        mockVerifierUsed = $true
        stalePoolRejected = $staleRejected
        onlinePathFeatureCount = $livePaths.Count
        liveDurationRecorded = ([long]$result.moonGrammata.liveVerifierDurationMs -ge 0)
        fixedPoolCaveatRetained = $true
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
