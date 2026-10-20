param(
    [Parameter(Mandatory = $true)]
    [string]$BaselineReport,

    [Parameter(Mandatory = $true)]
    [string]$CandidateReport,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$RequireEquivalent
)

$ErrorActionPreference = 'Stop'

function Read-ToolchainReport {
    param([Parameter(Mandatory = $true)][string]$Path, [string]$Label)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Label report does not exist: $Path"
    }
    $report = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
    if ($report.schemaVersion -ne 11) {
        throw "$Label report must use schema version 11; got '$($report.schemaVersion)'."
    }
    if ($report.count -lt 1 -or $report.cases.Count -ne $report.count) {
        throw "$Label report has an invalid case count."
    }
    if ([string]::IsNullOrWhiteSpace([string]$report.toolchainVersion)) {
        throw "$Label report is missing toolchainVersion."
    }
    if ($report.harnessDigestStart -ne $report.harnessDigestEnd) {
        throw "$Label report harness changed during the run."
    }
    if ($null -eq $report.targets -or $report.targets.Count -lt 1) {
        throw "$Label report has no targets."
    }
    for ($index = 0; $index -lt $report.cases.Count; $index++) {
        $case = $report.cases[$index]
        if ($case.seed -ne ([long]$report.seedStart + $index)) {
            throw "$Label report case $index has a non-contiguous seed '$($case.seed)'."
        }
        if ([string]$case.bodySha256 -notmatch '^[0-9a-f]{64}$') {
            throw "$Label report seed $($case.seed) has an invalid bodySha256."
        }
        if ($report.targets.Count -gt 1 -and
            [string]::IsNullOrWhiteSpace([string]$case.targetParity.status)) {
            throw "$Label report seed $($case.seed) is missing its Target Parity status."
        }
    }
    return $report
}

function Convert-ComparableValue {
    param($Value)
    return ConvertTo-Json -InputObject $Value -Depth 30 -Compress
}

$baseline = Read-ToolchainReport -Path $BaselineReport -Label 'Baseline'
$candidate = Read-ToolchainReport -Path $CandidateReport -Label 'Candidate'
if ($baseline.toolchainVersion -ceq $candidate.toolchainVersion) {
    throw 'Baseline and candidate reports must record different toolchains.'
}
foreach ($field in @('seedStart', 'count', 'depth', 'timeoutSeconds')) {
    if ($baseline.$field -ne $candidate.$field) {
        throw "Reports are not matched: '$field' differs."
    }
}
if ((@($baseline.targets | Sort-Object) -join ',') -cne
    (@($candidate.targets | Sort-Object) -join ',')) {
    throw 'Reports are not matched: target lists differ.'
}
if ($baseline.harnessDigestStart -cne $candidate.harnessDigestStart) {
    throw 'Reports are not matched: harness digests differ.'
}

$bodyHashMismatches = [System.Collections.Generic.List[int]]::new()
$outcomeMismatches = [System.Collections.Generic.List[int]]::new()
$targetParityMismatches = [System.Collections.Generic.List[int]]::new()
for ($index = 0; $index -lt $baseline.cases.Count; $index++) {
    $before = $baseline.cases[$index]
    $after = $candidate.cases[$index]
    if ($before.seed -ne $after.seed) {
        throw "Reports are not matched: seed differs at case index $index."
    }
    if ($before.bodySha256 -cne $after.bodySha256) {
        $bodyHashMismatches.Add([int]$before.seed)
    }

    $beforeParity = Convert-ComparableValue $before.targetParity
    $afterParity = Convert-ComparableValue $after.targetParity
    if ($beforeParity -cne $afterParity) {
        $targetParityMismatches.Add([int]$before.seed)
    }

    $beforeOutcome = ConvertTo-Json -InputObject ([ordered]@{
        finding = $before.finding
        referenceChecked = $before.referenceChecked
        expectedOutput = $before.expectedOutput
        signature = $before.signature
        targetParity = $before.targetParity
    }) -Depth 30 -Compress
    $afterOutcome = ConvertTo-Json -InputObject ([ordered]@{
        finding = $after.finding
        referenceChecked = $after.referenceChecked
        expectedOutput = $after.expectedOutput
        signature = $after.signature
        targetParity = $after.targetParity
    }) -Depth 30 -Compress
    if ($beforeOutcome -cne $afterOutcome) {
        $outcomeMismatches.Add([int]$before.seed)
    }
}

$result = [pscustomobject]@{
    schemaVersion = 1
    baseline = [pscustomobject]@{
        toolchainVersion = $baseline.toolchainVersion
        runId = $baseline.runId
        rawReport = (Resolve-Path -LiteralPath $BaselineReport).Path
        durationMs = $baseline.durationMs
        counts = $baseline.counts
    }
    candidate = [pscustomobject]@{
        toolchainVersion = $candidate.toolchainVersion
        runId = $candidate.runId
        rawReport = (Resolve-Path -LiteralPath $CandidateReport).Path
        durationMs = $candidate.durationMs
        counts = $candidate.counts
    }
    matched = [pscustomobject]@{
        seedStart = $baseline.seedStart
        count = $baseline.count
        depth = $baseline.depth
        targets = @($baseline.targets)
        timeoutSeconds = $baseline.timeoutSeconds
        harnessDigest = $baseline.harnessDigestStart
    }
    bodyHashMismatchSeeds = @($bodyHashMismatches)
    outcomeMismatchSeeds = @($outcomeMismatches)
    targetParityMismatchSeeds = @($targetParityMismatches)
    equivalent = ($bodyHashMismatches.Count -eq 0 -and
        $outcomeMismatches.Count -eq 0)
    timingNote = 'Elapsed times are descriptive only; cache state and run order are not controlled.'
}
$json = ConvertTo-Json -InputObject $result -Depth 30
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $outputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
    }
    Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
}
Write-Output $json

if ($RequireEquivalent -and -not $result.equivalent) {
    exit 1
}
