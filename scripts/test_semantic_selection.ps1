$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'semantic_selection.ps1')

$candidates = @(
    [pscustomobject]@{ seed = 8; paths = @('common', 'common') },
    [pscustomobject]@{ seed = 9; paths = @('common', 'rare-a') },
    [pscustomobject]@{ seed = 10; paths = @('common', 'rare-b') },
    [pscustomobject]@{ seed = 11; paths = @('common') }
)
$first = @(Select-MoonSmithSemanticSeeds -Candidates $candidates -Budget 2)
$second = @(Select-MoonSmithSemanticSeeds -Candidates $candidates -Budget 2)
if ((@($first | ForEach-Object seed) -join ',') -ne '9,10') {
    throw 'Selection must prefer distinct rare paths, break ties by seed, and deduplicate paths.'
}
if ((@($first | ForEach-Object seed) -join ',') -ne
    (@($second | ForEach-Object seed) -join ',')) {
    throw 'Semantic selection is not deterministic.'
}
$caught = $false
try { $null = Select-MoonSmithSemanticSeeds -Candidates $candidates -Budget 5 }
catch { $caught = $true }
if (-not $caught) { throw 'Budget larger than candidate pool must be rejected.' }

$syntheticMetrics = Get-MoonSmithSelectionMetrics -Reports @(
    [pscustomobject]@{
        finding = 'compile-failure'
        bodySha256 = 'a'
        referenceTrace = [pscustomobject]@{ visited = @('if-then', 'if-then') }
        runs = @([pscustomobject]@{ status = 'compile-failed'; executionAttempted = $false })
    },
    [pscustomobject]@{
        finding = 'consistent'
        bodySha256 = 'b'
        referenceTrace = [pscustomobject]@{ visited = @('if-else') }
        runs = @([pscustomobject]@{ status = 'succeeded'; executionAttempted = $true })
    }
)
if ($syntheticMetrics.backendBuildAttempts -ne 2 -or
    $syntheticMetrics.backendExecutions -ne 1 -or
    $syntheticMetrics.distinctReferencePaths -ne 2) {
    throw 'A compile failure must not be counted as a backend execution.'
}

$report = & (Join-Path $PSScriptRoot 'compare_semantic_selection.ps1') `
    -SeedStart 0 -CandidateCount 4 -ExecutionBudget 2 -Depth 2 `
    -Targets @('js') -TimeoutSeconds 30 |
    ConvertFrom-Json
if (-not $report.equalBackendExecutionBudget -or
    $report.baseline.metrics.backendExecutions -ne 2 -or
    $report.guided.metrics.backendExecutions -ne 2) {
    throw 'Smoke comparison did not execute the same backend budget on both arms.'
}
if ($report.guided.seeds.Count -ne 2 -or
    @($report.guided.seeds | Select-Object -Unique).Count -ne 2 -or
    $report.candidatePool.Count -ne 4) {
    throw 'Smoke comparison lost candidate or selected seed identity.'
}
if ($report.referenceTraceSource -notlike '*not backend runtime coverage*') {
    throw 'Reference paths must not be presented as backend instrumentation.'
}
'Semantic selection unit and integration checks passed.'
