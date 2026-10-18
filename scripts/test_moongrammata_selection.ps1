param(
    [Parameter(Mandatory)][string]$InputReport,
    [Parameter()][ValidateRange(1, 10000)][int]$ExecutionBudget = 20,
    [Parameter()][long]$Seed = 20261018,
    [Parameter()][string]$LiveVerificationPath = ''
)

$ErrorActionPreference = 'Stop'
$runner = Join-Path $PSScriptRoot 'run_moongrammata_selection.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('moongrammata-selection-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $outputs = @()
    foreach ($ordinal in 1..2) {
        $outputPath = Join-Path $testRoot "run-$ordinal.json"
        $raw = & $runner -InputReport $InputReport -ExecutionBudget $ExecutionBudget `
            -Seed $Seed -OutputPath $outputPath
        if ($LASTEXITCODE -ne 0) { throw "MoonGrammata runner failed on repetition $ordinal." }
        $outputs += Get-Content -LiteralPath $outputPath -Raw -Encoding utf8 | ConvertFrom-Json
    }
    $first = $outputs[0]
    $second = $outputs[1]
    if ($first.moonGrammata.completedExecutions -ne $ExecutionBudget -or
        $first.moonGrammata.requestedExecutions -ne $ExecutionBudget) {
        throw 'MoonGrammata did not perform exactly the configured number of target evaluations.'
    }
    if ($first.poolCandidateCount -ne $first.moonGrammata.poolSize -or
        $first.moonGrammata.uniqueCandidatesObserved -gt $ExecutionBudget) {
        throw 'Candidate-pool or distinct-candidate accounting is inconsistent.'
    }
    $poolSeeds = @((Get-Content -LiteralPath $InputReport -Raw -Encoding utf8 | ConvertFrom-Json).candidatePool |
        ForEach-Object { [int]$_.seed })
    foreach ($seedValue in $first.moonGrammata.selectedSeeds) {
        if ($seedValue -notin $poolSeeds) { throw "MoonGrammata selected out-of-pool seed $seedValue." }
    }
    if ($first.moonGrammata.distinctReferencePathKinds -gt $first.poolReferencePathKinds) {
        throw 'Observed path kinds exceed the frozen pool path universe.'
    }
    $commonBudget = ($first.moonSmith.commonUniqueCandidateCountsByQuartile.PSObject.Properties |
        ForEach-Object { [int]$_.Value } | Measure-Object -Sum).Sum
    if ($commonBudget -ne $first.moonSmith.commonUniqueCandidateBudget) {
        throw 'Common candidate budget does not match its size-quartile counts.'
    }
    foreach ($quartile in $first.moonSmith.commonUniqueCandidateCountsByQuartile.PSObject.Properties.Name) {
        $expected = [int]$first.moonSmith.commonUniqueCandidateCountsByQuartile.$quartile
        if ([int]$first.moonSmith.baselineMatchedQuartileCounts.$quartile -ne $expected -or
            [int]$first.moonSmith.semanticGuidedMatchedQuartileCounts.$quartile -ne $expected -or
            [int]$first.moonSmith.moonGrammataMatchedQuartileCounts.$quartile -ne $expected) {
            throw "Common-budget comparison is not size-stratum matched for quartile $quartile."
        }
    }
    if (($first.moonGrammata.selectedSeeds -join ',') -ne
        ($second.moonGrammata.selectedSeeds -join ',') -or
        $first.moonGrammata.distinctReferencePathKinds -ne $second.moonGrammata.distinctReferencePathKinds -or
        $first.moonGrammata.uniqueCandidatesObserved -ne $second.moonGrammata.uniqueCandidatesObserved) {
        throw 'Identical campaign seed and candidate pool did not reproduce identical selection metrics.'
    }
    $livePassed = $false
    if ($LiveVerificationPath) {
        $live = Get-Content -LiteralPath $LiveVerificationPath -Raw -Encoding utf8 | ConvertFrom-Json
        $poolReport = Get-Content -LiteralPath $InputReport -Raw -Encoding utf8 | ConvertFrom-Json
        $arms = @($live.liveVerification.sequential, $live.liveVerification.semanticGuided,
            $live.liveVerification.moonGrammata)
        $targetBudget = [int]$live.liveVerification.targetBudgetPerArm
        $selectedCaseBudget = [int]$live.liveVerification.selectedCaseBudget
        if ($live.liveVerification.protocol -notmatch 'blind execution' -or
            $selectedCaseBudget -le 0 -or
            $targetBudget -ne $selectedCaseBudget * @($live.liveVerification.targets).Count -or
            ($poolReport.sourceSizeQuartilesMatched -and
                -not $live.liveVerification.sourceSizeQuartilesMatched)) {
            throw 'Live-verification protocol or per-arm target budget is inconsistent.'
        }
        $poolMap = @{}
        foreach ($candidate in @($poolReport.candidatePool)) {
            $poolMap[[string]$candidate.seed] = $candidate
        }
        foreach ($arm in $arms) {
            if ([int]$arm.caseCount -ne $selectedCaseBudget -or
                @($arm.cases).Count -ne $selectedCaseBudget -or
                [int]$arm.backendExecutions -ne $targetBudget -or
                @($arm.cases.seed | Sort-Object -Unique).Count -ne $selectedCaseBudget) {
                throw "Live-verification arm '$($arm.name)' did not complete the matched unique-candidate budget."
            }
            $findingTotal = ($arm.findings.PSObject.Properties | ForEach-Object { [int]$_.Value } |
                Measure-Object -Sum).Sum
            if ($findingTotal -ne $selectedCaseBudget) {
                throw "Live-verification arm '$($arm.name)' has inconsistent finding counts."
            }
            foreach ($case in $arm.cases) {
                if (-not $poolMap.ContainsKey([string]$case.seed) -or
                    @($case.backendRuns).Count -ne @($live.liveVerification.targets).Count -or
                    @($case.referencePathKinds).Count -eq 0) {
                    throw "Live-verification case '$($case.seed)' is outside the pool or incomplete."
                }
                $expectedTargets = @($live.liveVerification.targets | Sort-Object)
                $actualTargets = @($case.backendRuns.target | Sort-Object)
                if (($expectedTargets -join ',') -ne ($actualTargets -join ',')) {
                    throw "Live-verification case '$($case.seed)' did not run the configured target set."
                }
            }
            foreach ($quartile in $live.liveVerification.sizeQuartileCounts.PSObject.Properties.Name) {
                $expectedCount = [int]$live.liveVerification.sizeQuartileCounts.$quartile
                if ($expectedCount -le 0) { continue }
                $actualCount = @($arm.cases | Where-Object {
                    [string]$poolMap[[string]$_.seed].sizeQuartile -eq [string]$quartile
                }).Count
                if ($actualCount -ne $expectedCount) {
                    throw "Live-verification arm '$($arm.name)' does not match quartile $quartile."
                }
            }
        }
        $livePassed = $true

        $staleInputPath = Join-Path $testRoot 'stale-pool.json'
        $staleOutputPath = Join-Path $testRoot 'stale-live.json'
        $stalePool = $poolReport | ConvertTo-Json -Depth 8 | ConvertFrom-Json
        $stalePool.harnessDigestEnd = 'deliberately-stale-test-digest'
        [IO.File]::WriteAllText(
            $staleInputPath,
            ($stalePool | ConvertTo-Json -Depth 8),
            [Text.UTF8Encoding]::new($false)
        )
        $staleRejected = $false
        try {
            $null = & $runner -InputReport $staleInputPath -ExecutionBudget $ExecutionBudget `
                -Seed $Seed -OutputPath $staleOutputPath -LiveVerifySelectedArms
            if ($LASTEXITCODE -ne 0) { throw 'Stale-pool test runner failed unexpectedly.' }
        }
        catch {
            if ($_.Exception.Message -notmatch 'unchanged candidate-generation, reference, and verifier harness') {
                throw
            }
            $staleRejected = $true
        }
        if (-not $staleRejected -or (Test-Path -LiteralPath $staleOutputPath)) {
            throw 'Live verification did not reject stale candidate-pool metadata before writing a report.'
        }
    }
    [pscustomobject]@{
        passed = $true
        repetitions = 2
        campaignEvaluationsPerRun = [int]$first.moonGrammata.completedExecutions
        uniqueCandidatesPerRun = [int]$first.moonGrammata.uniqueCandidatesObserved
        pathKindsPerRun = [int]$first.moonGrammata.distinctReferencePathKinds
        candidatePoolSize = [int]$first.poolCandidateCount
        deterministic = $true
        liveVerificationValidated = $livePassed
        liveCaseBudgetPerArm = if ($livePassed) { $selectedCaseBudget } else { 0 }
        liveBackendExecutionsPerArm = if ($livePassed) { $targetBudget } else { 0 }
        stalePoolRejected = $livePassed
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
