param(
    [Parameter(Mandatory)][string]$ReportPath
)

$ErrorActionPreference = 'Stop'
$reportFullPath = (Resolve-Path -LiteralPath $ReportPath -ErrorAction Stop).Path
$report = Get-Content -LiteralPath $reportFullPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
if ($report.schemaVersion -ne 1) { throw "Unsupported campaign report schema: $($report.schemaVersion)" }
if ($report.harnessChangedDuringRun) { throw 'Campaign harness changed while the run was active.' }

function Get-Sha256([string]$Path) {
    (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}
function Resolve-RecordedPath([string]$Path) {
    if ([IO.Path]::IsPathRooted($Path)) { return [IO.Path]::GetFullPath($Path) }
    return [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $reportFullPath) $Path))
}
function Assert-Equal([object]$Actual, [object]$Expected, [string]$Label) {
    if ($Actual -ne $Expected) { throw "$Label mismatch: recorded '$Expected', recomputed '$Actual'." }
}

$selectionPath = Resolve-RecordedPath ([string]$report.selectionConfigurationPath)
if (-not (Test-Path -LiteralPath $selectionPath -PathType Leaf)) { throw "Missing selection configuration: $selectionPath" }
Assert-Equal (Get-Sha256 $selectionPath) ([string]$report.selectionConfigurationSha256).ToLowerInvariant() 'Selection configuration SHA-256'

$indexedReports = @{}
foreach ($entry in @($report.rawCaseReports)) {
    $path = Resolve-RecordedPath ([string]$entry.path)
    $key = $path.ToLowerInvariant()
    if ($indexedReports.ContainsKey($key)) { throw "Duplicate raw report path in index: $path" }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing raw case report: $path" }
    $actualSha = Get-Sha256 $path
    Assert-Equal $actualSha ([string]$entry.sha256).ToLowerInvariant() "Raw report SHA-256 ($path)"
    $indexedReports[$key] = $actualSha
}

$arms = @(
    @{ name='sequential'; state=$report.arms.sequential },
    @{ name='semanticGuided'; state=$report.arms.semanticGuided },
    @{ name='moonGrammata'; state=$report.arms.moonGrammata }
)
$expectedIndexed = @{}
$armAudit = @()
foreach ($arm in $arms) {
    $state = $arm.state
    $cases = @($state.cases)
    Assert-Equal $cases.Count ([int]$state.attempts) "$($arm.name) attempt count"
    $completed = @($cases | Where-Object { $_.completed }).Count
    Assert-Equal $completed ([int]$state.completedCases) "$($arm.name) completed-case count"

    $statusCounts = @{}
    $backendCount = 0
    $workCount = 0
    $pathKinds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($case in $cases) {
        $status = [string]$case.status
        if (-not $statusCounts.ContainsKey($status)) { $statusCounts[$status] = 0 }
        $statusCounts[$status]++
        Assert-Equal ([bool]$case.timedOut) ([bool]$case.censored) "$($arm.name) attempt $($case.attempt) timeout/censor flags"
        if ($case.completed) {
            $backendCount += [int]$case.backendCheckCount
            $workCount += [int]$case.candidateOrCallbackCount
            foreach ($pathKind in @($case.referencePathKinds)) { [void]$pathKinds.Add([string]$pathKind) }
            if (-not $case.reportPath -or -not $case.reportSha256) { throw "$($arm.name) completed attempt $($case.attempt) lacks a raw report reference." }
            $path = Resolve-RecordedPath ([string]$case.reportPath)
            $key = $path.ToLowerInvariant()
            Assert-Equal ([string]$case.reportSha256).ToLowerInvariant() $indexedReports[$key] "$($arm.name) indexed report SHA ($path)"
            $expectedIndexed[$key] = $indexedReports[$key]
        } elseif ($case.censored -and -not $case.timedOut) {
            throw "$($arm.name) attempt $($case.attempt) is marked censored but not timed out."
        }
    }

    $statusCountsVerified = $null -ne $state.attemptStatusCounts
    if ($statusCountsVerified) {
        Assert-Equal (@($statusCounts.Values | Measure-Object -Sum).Sum) (@($state.attemptStatusCounts.Values | Measure-Object -Sum).Sum) "$($arm.name) status-count total"
        foreach ($status in $statusCounts.Keys) {
            if (-not $state.attemptStatusCounts.ContainsKey($status)) { throw "$($arm.name) status '$status' is absent from the aggregate." }
            Assert-Equal ([int]$statusCounts[$status]) ([int]$state.attemptStatusCounts[$status]) "$($arm.name) status '$status'"
        }
    }
    Assert-Equal $backendCount ([int]$state.backendCheckCount) "$($arm.name) backend-check count"
    Assert-Equal $workCount ([int]$state.candidateOrCallbackCount) "$($arm.name) candidate/callback count"
    Assert-Equal $pathKinds.Count ([int]$state.distinctReferencePathKinds) "$($arm.name) distinct reference-path count"

    $armAudit += [ordered]@{
        arm=$arm.name; attempts=$cases.Count; completed=$completed; backendChecks=$backendCount
        candidateOrCallbacks=$workCount; distinctReferencePathKinds=$pathKinds.Count
        attemptStatusCounts=$statusCounts; aggregateStatusCountsVerified=$statusCountsVerified
    }
}

if ($expectedIndexed.Count -ne $indexedReports.Count) { throw "Raw-report index has $($indexedReports.Count) items but $($expectedIndexed.Count) completed attempts reference reports." }
$budgets = @($arms | ForEach-Object { [long]$_.state.wallClockBudgetMs } | Select-Object -Unique)
if ($budgets.Count -ne 1 -or -not $report.equalWallClockBudgetConfigured) { throw 'Campaign does not declare one equal wall-clock budget across arms.' }
$withinOneSecond = -not $report.resumedAfterParentInterruption -and
    (@($arms | ForEach-Object { [Math]::Abs([long]$_.state.activeWallClockMs - [long]$_.state.wallClockBudgetMs) -le 1000 } | Where-Object { -not $_ }).Count -eq 0) -and
    (@($arms | Where-Object { [int]$_.state.attempts -ge [int]$report.configuration.maximumAttemptsPerArm -and -not $_.state.timedOut }).Count -eq 0)
Assert-Equal $withinOneSecond ([bool]$report.wallClockUsageWithinOneSecondOfBudget) 'Realized equal-budget flag'

[ordered]@{
    audit='passed'; claimScope='artifact-and-summary-integrity-only'; reportSha256=(Get-Sha256 $reportFullPath)
    selectionConfigurationSha256=(Get-Sha256 $selectionPath); rawCaseReportsVerified=$indexedReports.Count
    equalConfiguredBudgetMs=$budgets[0]; realizedUsageWithinOneSecond=$withinOneSecond
    arms=$armAudit
} | ConvertTo-Json -Depth 8
