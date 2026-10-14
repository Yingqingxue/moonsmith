# Pure selection and measurement helpers shared by the experiment and tests.
# Path names come from the MoonBit reference evaluator, not backend coverage.
function Select-MoonSmithSemanticSeeds {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [Parameter(Mandatory)][ValidateRange(1, 10000)][int]$Budget,
        [Parameter()][hashtable]$SizeQuotas = $null
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
    $selectedBySize = @{}
    $selected = [System.Collections.Generic.List[object]]::new()
    $chosenSeeds = [System.Collections.Generic.HashSet[int]]::new()
    while ($selected.Count -lt $Budget) {
        $best = $null
        $bestScore = [double]::NegativeInfinity
        foreach ($candidate in $Candidates) {
            if ($chosenSeeds.Contains([int]$candidate.seed)) { continue }
            if ($null -ne $SizeQuotas) {
                $quartile = [string]$candidate.sizeQuartile
                $selectedInQuartile = if ($selectedBySize.ContainsKey($quartile)) {
                    $selectedBySize[$quartile]
                } else { 0 }
                if (-not $SizeQuotas.ContainsKey($quartile) -or
                    $selectedInQuartile -ge $SizeQuotas[$quartile]) { continue }
            }
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
        if ($null -ne $SizeQuotas) {
            $quartile = [string]$best.sizeQuartile
            if (-not $selectedBySize.ContainsKey($quartile)) { $selectedBySize[$quartile] = 0 }
            $selectedBySize[$quartile]++
        }
        foreach ($path in @($best.paths | Sort-Object -Unique)) {
            if (-not $selectedFrequency.ContainsKey($path)) { $selectedFrequency[$path] = 0 }
            $selectedFrequency[$path]++
        }
    }
    return $selected.ToArray()
}

function Set-MoonSmithSourceSizeQuartiles {
    param([Parameter(Mandatory)][object[]]$Candidates)
    if (@($Candidates | Where-Object { $null -eq $_.sourceLineCount }).Count -gt 0) {
        throw 'Every candidate needs a sourceLineCount before size matching.'
    }
    $ordered = @($Candidates | Sort-Object sourceLineCount, seed)
    for ($index = 0; $index -lt $ordered.Count; $index++) {
        $quartile = [math]::Min(3, [math]::Floor(4 * $index / $ordered.Count))
        $ordered[$index] | Add-Member -NotePropertyName sizeQuartile `
            -NotePropertyValue ([string]$quartile) -Force
    }
}

function Get-MoonSmithSizeQuotas {
    param([Parameter(Mandatory)][object[]]$Candidates)
    $quotas = @{}
    foreach ($candidate in $Candidates) {
        $quartile = [string]$candidate.sizeQuartile
        if (-not $quotas.ContainsKey($quartile)) { $quotas[$quartile] = 0 }
        $quotas[$quartile]++
    }
    return $quotas
}

function Get-MoonSmithSeedSizeCounts {
    param(
        [Parameter(Mandatory)][int[]]$Seeds,
        [Parameter(Mandatory)][object[]]$Candidates
    )
    $counts = @{}
    foreach ($candidate in $Candidates) {
        if ($Seeds -contains [int]$candidate.seed) {
            $quartile = [string]$candidate.sizeQuartile
            if (-not $counts.ContainsKey($quartile)) { $counts[$quartile] = 0 }
            $counts[$quartile]++
        }
    }
    return $counts
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
