$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$comparison = Join-Path $PSScriptRoot 'run_live_feedback_comparison.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('moonsmith-live-comparison-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $budget = 3
    $targets = @('js', 'wasm', 'wasm-gc')
    $pool = foreach ($seed in 30000..30007) {
        [pscustomobject]@{
            seed = $seed
            sizeQuartile = [int](($seed - 30000) % 4)
            paths = @("cached-$($seed % 4)")
        }
    }
    $baselineCases = foreach ($seed in 30000..30002) {
        [pscustomobject]@{ seed = $seed; backendStatuses = @('js:succeeded', 'wasm:succeeded', 'wasm-gc:succeeded') }
    }
    $guidedCases = foreach ($seed in 30003..30005) {
        [pscustomobject]@{ seed = $seed; backendStatuses = @('js:succeeded', 'wasm:succeeded', 'wasm-gc:succeeded') }
    }
    $selection = [pscustomobject]@{
        schemaVersion = 1
        equalBackendExecutionBudget = $true
        harnessChangedDuringRun = $false
        sourceSizeQuartilesMatched = $true
        executionBudgetCasesPerArm = $budget
        candidateCount = 8
        seedStart = 30000
        configuredTargets = $targets
        depth = 2
        timeoutSeconds = 2
        toolchainVersion = 'test-toolchain'
        method = 'test size-matched policy'
        prescreenDurationMs = 10
        overlapSeedCount = 0
        candidatePool = @($pool)
        baseline = [pscustomobject]@{
            seeds = @(30000, 30001, 30002)
            durationMs = 30
            metrics = [pscustomobject]@{ distinctReferencePaths = 3; findings = @{ consistent = 3 }; backendExecutions = 9 }
            cases = @($baselineCases)
        }
        guided = [pscustomobject]@{
            seeds = @(30003, 30004, 30005)
            durationMs = 31
            metrics = [pscustomobject]@{ distinctReferencePaths = 4; findings = @{ consistent = 3 }; backendExecutions = 9 }
            cases = @($guidedCases)
        }
    }
    $selectionPath = Join-Path $testRoot 'selection.json'
    [IO.File]::WriteAllText($selectionPath, ($selection | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))

    $verifierPath = Join-Path $testRoot 'verifier.ps1'
    $verifier = @'
param([int]$Seed,[int]$Depth,[string[]]$Targets,[int]$TimeoutSeconds,[switch]$NoPersist)
$runs = foreach ($target in $Targets) {
    [pscustomobject]@{ target=$target; status='succeeded'; exitCode=0; durationMs=2; executionAttempted=$true }
}
[pscustomobject]@{
    seed=$Seed; referenceChecked=$true; sourceLineCount=40
    generationDurationMs=1; referenceEvaluationDurationMs=2; referenceTraceDurationMs=3
    finding='consistent'; referenceTrace=[pscustomobject]@{ visited=@("live-$Seed") }
    runs=@($runs)
} | ConvertTo-Json -Depth 5 -Compress
'@
    [IO.File]::WriteAllText($verifierPath, $verifier, [Text.UTF8Encoding]::new($false))

    $outputPath = Join-Path $testRoot 'comparison.json'
    $null = & $comparison -SelectionReport $selectionPath -MoonGrammataSeed 12345 `
        -OutputPath $outputPath -LiveVerifierScript $verifierPath
    if ($LASTEXITCODE -ne 0) { throw 'Comparison wrapper failed for the valid matched-budget fixture.' }
    $result = Get-Content -LiteralPath $outputPath -Raw -Encoding utf8 | ConvertFrom-Json
    foreach ($arm in @($result.sequential, $result.semanticGuided, $result.moonGrammata)) {
        if ([int]$arm.backendExecutions -ne 9) { throw 'A comparison arm did not preserve the exact backend execution budget.' }
    }
    if ($result.verifierKind -ne 'test-double' -or
        [int]$result.moonGrammata.callbackCount -ne $budget -or
        [int]$result.moonGrammata.uniqueReferencePathKinds -le 0 -or
        $result.moonGrammata.backendStatuses.'js:succeeded:0' -ne $budget -or
        $result.wallClockThroughputClaimAllowed -ne $false -or
        $result.caveat -notlike '*do not establish throughput superiority*') {
        throw 'The comparison report lost online observations, backend outcomes, or the wall-clock caveat.'
    }
    $rejectedBudget = $false
    $badSelection = $selection | ConvertTo-Json -Depth 8 | ConvertFrom-Json
    $badSelection.guided.metrics.backendExecutions = 8
    $badPath = Join-Path $testRoot 'bad-selection.json'
    [IO.File]::WriteAllText($badPath, ($badSelection | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    try {
        $null = & $comparison -SelectionReport $badPath -MoonGrammataSeed 12345 `
            -OutputPath (Join-Path $testRoot 'bad-result.json') -LiveVerifierScript $verifierPath
        if ($LASTEXITCODE -ne 0) { throw 'The invalid-budget wrapper invocation failed outside its expected guard.' }
    } catch {
        if ($_.Exception.Message -notlike '*shared case and backend-execution budget*') { throw }
        $rejectedBudget = $true
    }
    if (-not $rejectedBudget -or (Test-Path -LiteralPath (Join-Path $testRoot 'bad-result.json'))) {
        throw 'The wrapper did not reject an arm with a mismatched backend execution budget before running it.'
    }
    [pscustomobject]@{
        passed = $true
        arms = 3
        casesPerArm = $budget
        backendExecutionsPerArm = 9
        liveVerifierDoubleIdentified = $true
        mismatchedBudgetRejected = $true
        throughputClaimDisabled = $true
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
