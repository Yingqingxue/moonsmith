param(
    [Parameter(Mandatory)][string]$InputReport,
    [Parameter()][ValidateRange(1, 10000)][int]$ExecutionBudget = 20,
    [Parameter()][long]$Seed = 20261018,
    [Parameter()][string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$inputPath = (Resolve-Path -LiteralPath $InputReport -ErrorAction Stop).Path
$report = Get-Content -LiteralPath $inputPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($report.schemaVersion -ne 1 -or $report.candidatePool.Count -lt $ExecutionBudget) {
    throw 'Input must be a schemaVersion 1 MoonSmith selection report with enough candidates.'
}
if ($report.harnessChangedDuringRun -or -not $report.equalBackendExecutionBudget) {
    throw 'Refusing an incomplete or internally invalid MoonSmith candidate-pool report.'
}

$pathNames = @($report.candidatePool | ForEach-Object { $_.paths } | Sort-Object -Unique)
if ($pathNames.Count -eq 0) { throw 'Candidate pool has no reference-path features.' }
$pathIds = @{}
for ($i = 0; $i -lt $pathNames.Count; $i++) { $pathIds[[string]$pathNames[$i]] = $i }
$specifications = foreach ($candidate in $report.candidatePool) {
    $ids = @($candidate.paths | ForEach-Object { $pathIds[[string]$_] })
    $idText = if ($ids.Count -gt 0) { $ids -join ',' } else { '-' }
    "{0}:{1}:{2}" -f $candidate.seed, [int]$candidate.sizeQuartile, $idText
}
$template = Join-Path $projectRoot 'benchmarks\moongrammata_selection'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('moongrammata-selection-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $template 'moon.mod') -Destination $tempRoot
    $commandPackage = Join-Path $tempRoot 'cmd\main'
    New-Item -ItemType Directory -Path $commandPackage -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $template 'cmd\main\moon.pkg') -Destination $commandPackage
    Copy-Item -LiteralPath (Join-Path $template 'cmd\main\main.mbt') -Destination $commandPackage
    $moon = (Get-Command moon -ErrorAction Stop).Source
    $args = @('run', '--target', 'js', 'cmd/main', '--', [string]$ExecutionBudget, [string]$Seed,
        ($pathNames -join ',')) + @($specifications)
    Push-Location $tempRoot
    try { $raw = & $moon @args 2>&1 }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw "MoonGrammata benchmark failed: $($raw -join [Environment]::NewLine)" }
    $text = $raw -join [Environment]::NewLine
    if (-not $text.Contains('MOONSMITH_FIXED_POOL_V1')) {
        throw "MoonGrammata benchmark did not emit its result marker: $text"
    }
    $summary = @{}
    foreach ($line in $text -split '\r?\n') {
        if ($line -match '^([a-z_]+)=(.*)$') { $summary[$Matches[1]] = $Matches[2] }
    }
    if ([int]$summary.completed -ne $ExecutionBudget -or
        [int]$summary.candidate_pool -ne $report.candidatePool.Count) {
        throw 'MoonGrammata campaign did not honor the fixed pool and execution budget.'
    }
    $selectedSeeds = @($summary.observed_seeds -split ',' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
    $candidateMap = @{}
    foreach ($candidate in $report.candidatePool) { $candidateMap[[string]$candidate.seed] = $candidate }
    $selectedPaths = [System.Collections.Generic.HashSet[string]]::new()
    $selectedQuartiles = @{}
    foreach ($selectedSeed in $selectedSeeds) {
        if (-not $candidateMap.ContainsKey([string]$selectedSeed)) {
            throw "MoonGrammata generated an ID outside the fixed candidate pool: $selectedSeed"
        }
        $candidate = $candidateMap[[string]$selectedSeed]
        foreach ($path in $candidate.paths) { [void]$selectedPaths.Add([string]$path) }
        $quartile = [string]$candidate.sizeQuartile
        if (-not $selectedQuartiles.ContainsKey($quartile)) { $selectedQuartiles[$quartile] = 0 }
        $selectedQuartiles[$quartile]++
    }
    $candidateBody = [pscustomobject]@{
        name = 'Unstratified MoonGrammata campaign on MoonSmith fixed pool'
        poolSize = $report.candidatePool.Count
        seed = $Seed
        requestedExecutions = [int]$summary.requested
        completedExecutions = [int]$summary.completed
        uniqueCandidatesObserved = [int]$summary.unique_observed
        selectedSeeds = $selectedSeeds
        distinctReferencePathKinds = $selectedPaths.Count
        sourceSizeQuartileCounts = $selectedQuartiles
        uniqueFeedbackFeatures = [int]$summary.unique_features
        uniqueFeedbackSignatures = [int]$summary.unique_signatures
        mutationFailures = [int]$summary.mutation_failures
        corpusEntries = [int]$summary.corpus_entries
    }
    function Measure-PathKindsBySizeProfile {
        param([object[]]$Cases, [hashtable]$CountsByQuartile, [hashtable]$CandidatesBySeed)
        $set = [System.Collections.Generic.HashSet[string]]::new()
        $measuredCounts = @{}
        foreach ($quartile in $CountsByQuartile.Keys) {
            $count = [int]$CountsByQuartile[$quartile]
            $inQuartile = @($Cases | Where-Object {
                [string]$CandidatesBySeed[[string]$_.seed].sizeQuartile -eq [string]$quartile
            } | Select-Object -First $count)
            $measuredCounts[[string]$quartile] = $inQuartile.Count
            foreach ($case in $inQuartile) {
                foreach ($path in $case.referencePathKinds) { [void]$set.Add([string]$path) }
            }
        }
        return [pscustomobject]@{ distinctPathKinds = $set.Count; quartileCounts = $measuredCounts }
    }
    $baselineQuartileCounts = @{}
    foreach ($case in $report.baseline.cases) {
        $quartile = [string]$candidateMap[[string]$case.seed].sizeQuartile
        if (-not $baselineQuartileCounts.ContainsKey($quartile)) { $baselineQuartileCounts[$quartile] = 0 }
        $baselineQuartileCounts[$quartile]++
    }
    $moonGrammataCases = foreach ($selectedSeed in $selectedSeeds) {
        [pscustomobject]@{
            seed = $selectedSeed
            referencePathKinds = @($candidateMap[[string]$selectedSeed].paths)
        }
    }
    $commonQuotas = @{}
    foreach ($quartile in $baselineQuartileCounts.Keys) {
        $gCount = [int]$selectedQuartiles[[string]$quartile]
        $bCount = @($report.baseline.cases | Where-Object {
            [string]$candidateMap[[string]$_.seed].sizeQuartile -eq [string]$quartile
        }).Count
        $sCount = @($report.guided.cases | Where-Object {
            [string]$candidateMap[[string]$_.seed].sizeQuartile -eq [string]$quartile
        }).Count
        $commonQuotas[[string]$quartile] = [Math]::Min($gCount, [Math]::Min($bCount, $sCount))
    }
    $commonUniqueBudget = ($commonQuotas.Values | Measure-Object -Sum).Sum
    $moonGrammataComparable = Measure-PathKindsBySizeProfile -Cases $moonGrammataCases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $moonSmithBaselineComparable = Measure-PathKindsBySizeProfile -Cases $report.baseline.cases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $moonSmithGuidedComparable = Measure-PathKindsBySizeProfile -Cases $report.guided.cases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $result = [pscustomobject]@{
        schemaVersion = 1
        poolSource = (Resolve-Path -Relative $inputPath)
        poolCandidateCount = $report.candidatePool.Count
        poolReferencePathKinds = $pathNames.Count
        moonGrammata = $candidateBody
        moonSmith = [pscustomobject]@{
            baselineSelectedSeeds = @($report.baseline.cases | ForEach-Object { [int]$_.seed })
            baselineDistinctReferencePathKinds = [int]$report.baseline.metrics.distinctReferencePaths
            semanticGuidedSelectedSeeds = @($report.guided.cases | ForEach-Object { [int]$_.seed })
            semanticGuidedDistinctReferencePathKinds = [int]$report.guided.metrics.distinctReferencePaths
            prescreenDurationMs = [int]$report.prescreenDurationMs
            selectedExecutionBudget = [int]$report.executionBudgetCasesPerArm
            backendExecutionsPerArm = [int]$report.expectedBackendExecutionsPerArm
            sizeQuartilesMatched = [bool]$report.sourceSizeQuartilesMatched
            commonUniqueCandidateBudget = $commonUniqueBudget
            commonUniqueCandidateCountsByQuartile = $commonQuotas
            baselinePathKindsAtCommonUniqueBudget = $moonSmithBaselineComparable.distinctPathKinds
            semanticGuidedPathKindsAtCommonUniqueBudget = $moonSmithGuidedComparable.distinctPathKinds
            moonGrammataPathKindsAtCommonUniqueBudget = $moonGrammataComparable.distinctPathKinds
            baselineMatchedQuartileCounts = $moonSmithBaselineComparable.quartileCounts
            semanticGuidedMatchedQuartileCounts = $moonSmithGuidedComparable.quartileCounts
            moonGrammataMatchedQuartileCounts = $moonGrammataComparable.quartileCounts
        }
        interpretation = 'Exploratory fixed-pool selection comparison only. The MoonGrammata campaign uses cached MoonSmith reference-path features and does not execute compilers or the live reference evaluator. Path coverage is also reported on an intersection subset with identical source-size quartile counts; duplicate campaign evaluations mean this subset may be smaller than the requested execution budget. This is not an end-to-end fuzzer effectiveness comparison.'
        moonGrammataRevision = 'd9cf3512b636fd45e941f30010d3fceb7cc2e4fc'
        moonGrammataVersion = '0.1.1'
        moonGrammataApi = 'GrammarBuilder::dictionary + CampaignConfig + run_campaign; isolated benchmark dependency'
    }
    $json = $result | ConvertTo-Json -Depth 8
    if ($OutputPath) {
        $destination = [IO.Path]::GetFullPath($OutputPath)
        $destinationDirectory = Split-Path -Parent $destination
        if ($destinationDirectory) { New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null }
        [IO.File]::WriteAllText($destination, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    }
    $json
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
