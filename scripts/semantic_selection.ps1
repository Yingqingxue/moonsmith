# Pure selection and measurement helpers shared by the experiment and tests.
# Path names come from the MoonBit reference evaluator, not backend coverage.
function Select-MoonSmithSemanticSeeds {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [Parameter(Mandatory)][ValidateRange(1, 10000)][int]$Budget
    )
    if ($Candidates.Count -lt $Budget) { throw 'Budget exceeds candidate count.' }
    $poolFrequency = @{}
    foreach ($candidate in $Candidates) {
        foreach ($path in @($candidate.paths | Sort-Object -Unique)) {
            if (-not $poolFrequency.ContainsKey($path)) { $poolFrequency[$path] = 0 }
            $poolFrequency[$path]++
        }
    }
    $selectedFrequency = @{}
    $selected = [System.Collections.Generic.List[object]]::new()
    $chosenSeeds = [System.Collections.Generic.HashSet[int]]::new()
    while ($selected.Count -lt $Budget) {
        $best = $null
        $bestScore = [double]::NegativeInfinity
        foreach ($candidate in $Candidates) {
            if ($chosenSeeds.Contains([int]$candidate.seed)) { continue }
            $score = 0.0
            foreach ($path in @($candidate.paths | Sort-Object -Unique)) {
                $seen = if ($selectedFrequency.ContainsKey($path)) { $selectedFrequency[$path] } else { 0 }
                $score += 1.0 / ([double]$poolFrequency[$path] * (1.0 + $seen))
            }
            if ($null -eq $best -or $score -gt $bestScore + 1e-12 -or
                ([math]::Abs($score - $bestScore) -le 1e-12 -and
                 [int]$candidate.seed -lt [int]$best.seed)) {
                $best = $candidate
                $bestScore = $score
            }
        }
        if ($null -eq $best) { throw 'Candidate seeds must be unique.' }
        $selected.Add($best)
        [void]$chosenSeeds.Add([int]$best.seed)
        foreach ($path in @($best.paths | Sort-Object -Unique)) {
            if (-not $selectedFrequency.ContainsKey($path)) { $selectedFrequency[$path] = 0 }
            $selectedFrequency[$path]++
        }
    }
    return $selected.ToArray()
}

function Get-MoonSmithSelectionMetrics {
    param([Parameter(Mandatory)][object[]]$Reports)
    $paths = [System.Collections.Generic.HashSet[string]]::new()
    $bodies = [System.Collections.Generic.HashSet[string]]::new()
    $findings = @{}
    $backendAttempts = 0
    $backendExecutions = 0
    $unavailable = 0
    $sourceLineTotal = 0
    $sourceLineMaximum = 0
    $sourceLineCases = 0
    foreach ($report in $Reports) {
        if (-not $findings.ContainsKey([string]$report.finding)) {
            $findings[[string]$report.finding] = 0
        }
        $findings[[string]$report.finding]++
        if ($report.referenceTrace -and $report.referenceTrace.visited) {
            foreach ($path in $report.referenceTrace.visited) { [void]$paths.Add([string]$path) }
        }
        if ($report.bodySha256) { [void]$bodies.Add([string]$report.bodySha256) }
        if ($null -ne $report.sourceLineCount) {
            $sourceLineCases++
            $sourceLineTotal += [int]$report.sourceLineCount
            $sourceLineMaximum = [math]::Max($sourceLineMaximum, [int]$report.sourceLineCount)
        }
        foreach ($run in @($report.runs)) {
            if ($run.status -eq 'unavailable') { $unavailable++ }
            else { $backendAttempts++ }
            if ($run.executionAttempted) { $backendExecutions++ }
        }
    }
    [pscustomobject]@{
        caseCount = $Reports.Count
        backendBuildAttempts = $backendAttempts
        backendExecutions = $backendExecutions
        unavailableBackends = $unavailable
        distinctReferencePaths = $paths.Count
        uniqueProgramBodies = $bodies.Count
        meanSourceLines = if ($sourceLineCases -gt 0) {
            [math]::Round($sourceLineTotal / $sourceLineCases, 1)
        } else { $null }
        maximumSourceLines = if ($sourceLineCases -gt 0) { $sourceLineMaximum } else { $null }
        findings = $findings
    }
}
