param(
    [Parameter(Mandatory)][string]$InputReport,
    [Parameter()][ValidateRange(1, 10000)][int]$ExecutionBudget = 20,
    [Parameter()][long]$Seed = 20261018
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
    [pscustomobject]@{
        passed = $true
        repetitions = 2
        campaignEvaluationsPerRun = [int]$first.moonGrammata.completedExecutions
        uniqueCandidatesPerRun = [int]$first.moonGrammata.uniqueCandidatesObserved
        pathKindsPerRun = [int]$first.moonGrammata.distinctReferencePathKinds
        candidatePoolSize = [int]$first.poolCandidateCount
        deterministic = $true
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
