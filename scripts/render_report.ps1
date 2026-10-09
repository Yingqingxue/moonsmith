param(
    [Parameter(Mandatory)]
    [string]$CasePath,

    [string]$ReductionPath = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolved = (Resolve-Path -LiteralPath $CasePath -ErrorAction Stop).Path
$caseDirectory = if (Test-Path -LiteralPath $resolved -PathType Container) {
    $resolved
} else {
    Split-Path -Parent $resolved
}
$jsonPath = Join-Path $caseDirectory 'report.json'
$sourcePath = Join-Path $caseDirectory 'source.mbt'
foreach ($required in @($jsonPath, $sourcePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Saved finding is missing $required"
    }
}

$finding = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
if (-not $finding.caseId -or $finding.finding -eq 'consistent') {
    throw 'The saved report does not describe a non-consistent finding.'
}
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($finding.sourceSha256 -and $finding.sourceSha256 -ne $sourceHash) {
    throw 'The saved source no longer matches the hash in report.json.'
}
$source = Get-Content -LiteralPath $sourcePath -Raw -Encoding utf8

$reduction = $null
$minimalSource = $null
if ($ReductionPath) {
    $resolvedReduction = (Resolve-Path -LiteralPath $ReductionPath -ErrorAction Stop).Path
    $reductionDirectory = if (Test-Path -LiteralPath $resolvedReduction -PathType Container) {
        $resolvedReduction
    } else {
        Split-Path -Parent $resolvedReduction
    }
    $reductionJsonPath = Join-Path $reductionDirectory 'reduction.json'
    $reductionOriginalPath = Join-Path $reductionDirectory 'original.mbt'
    $minimalPath = Join-Path $reductionDirectory 'minimal.mbt'
    foreach ($required in @($reductionJsonPath, $reductionOriginalPath, $minimalPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Reduction record is missing $required"
        }
    }
    $reduction = Get-Content -LiteralPath $reductionJsonPath -Raw | ConvertFrom-Json
    if ($reduction.caseId -ne $finding.caseId -or
        $reduction.originalSignature -ne $finding.signature) {
        throw 'Reduction record does not match the selected finding.'
    }
    $reductionOriginalHash = (Get-FileHash -LiteralPath $reductionOriginalPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($reductionOriginalHash -ne $sourceHash) {
        throw 'Reduction source differs from the saved canonical finding source.'
    }
    $minimalSource = Get-Content -LiteralPath $minimalPath -Raw -Encoding utf8
}

$outputPath = Join-Path $caseDirectory 'report.md'
if ((Test-Path -LiteralPath $outputPath) -and -not $Force) {
    throw "Report already exists: $outputPath. Pass -Force to replace it."
}

$lines = [System.Collections.Generic.List[string]]::new()
function Add-Line([string]$Value = '') {
    $lines.Add($Value)
}
function Add-Fence([string]$Content, [string]$Language = '') {
    $maxTicks = 2
    foreach ($match in [regex]::Matches($Content, '`+')) {
        if ($match.Length -gt $maxTicks) { $maxTicks = $match.Length }
    }
    $fence = '`' * ($maxTicks + 1)
    Add-Line ($fence + $Language)
    Add-Line ($Content.TrimEnd("`r", "`n"))
    Add-Line $fence
}

$evidenceStatus = if ($finding.injection) {
    'HARNESS-INJECTED DEMONSTRATION — not a MoonBit compiler defect.'
} elseif ($finding.finding -eq 'environment-failure') {
    'Environment failure — not evidence of a compiler defect.'
} else {
    'Unconfirmed candidate — manually reproduce and rule out allowed behavior before filing an issue.'
}
$toolchainVersion = if ($finding.toolchainVersion) {
    [string]$finding.toolchainVersion
} else {
    'not recorded in the original report'
}
$hostOS = if ($finding.hostOS) { [string]$finding.hostOS } else { 'not recorded' }
$targetList = @($finding.runs | Select-Object -ExpandProperty target) -join ', '

Add-Line "# MoonSmith case $($finding.caseId)"
Add-Line
Add-Line "> **Evidence status:** $evidenceStatus"
Add-Line
Add-Line '## Summary'
Add-Line
Add-Line "- Finding: ``$($finding.finding)``"
Add-Line "- Seed / depth: ``$($finding.seed)`` / ``$($finding.depth)``"
Add-Line "- Targets: $targetList"
Add-Line "- MoonBit: $toolchainVersion"
Add-Line "- Host OS: $hostOS"
Add-Line "- Per-process timeout: $($finding.timeoutSeconds) s"
Add-Line "- Source SHA-256: ``$sourceHash``"
Add-Line "- Reference checked: $([bool]$finding.referenceChecked)"
Add-Line
Add-Line '## Backend results'
Add-Line
Add-Line '| Target | Backend / mode | Status | Exit code | Duration (ms) |'
Add-Line '|---|---|---|---:|---:|'
foreach ($run in $finding.runs) {
    $backendMode = if ($run.backend -and $run.buildMode) {
        "$($run.backend) / $($run.buildMode)"
    } else {
        'not recorded'
    }
    Add-Line "| $($run.target) | $backendMode | $($run.status) | $($run.exitCode) | $($run.durationMs) |"
}
Add-Line
if ($finding.referenceChecked) {
    Add-Line '## Reference output'
    Add-Line
    Add-Fence ([string]$finding.expectedOutput) 'text'
    Add-Line "Exact JSON string: ``$([string]$finding.expectedOutput | ConvertTo-Json -Compress)``"
    Add-Line
}
Add-Line '## Backend output and diagnostics'
Add-Line
foreach ($run in $finding.runs) {
    Add-Line "### $($run.target)"
    Add-Line
    Add-Line 'Stdout:'
    Add-Fence ([string]$run.output) 'text'
    Add-Line "Exact JSON string: ``$([string]$run.output | ConvertTo-Json -Compress)``"
    Add-Line
    Add-Line 'Stderr / diagnostic:'
    Add-Fence ([string]$run.error) 'text'
    Add-Line
}
Add-Line '## Original source'
Add-Line
Add-Fence $source 'moonbit'
Add-Line
if ($null -ne $reduction) {
    Add-Line '## AST reduction'
    Add-Line
    Add-Line "- Complexity: $($reduction.originalComplexity) → $($reduction.finalComplexity)"
    Add-Line "- Source bytes: $($reduction.originalBytes) → $($reduction.finalBytes)"
    Add-Line "- Accepted steps / attempts: $($reduction.acceptedSteps) / $($reduction.attempts)"
    Add-Line "- Attempt budget hit: $([bool]$reduction.attemptBudgetHit)"
    Add-Line
    Add-Line '### Reduced source'
    Add-Line
    Add-Fence $minimalSource 'moonbit'
    Add-Line
}
Add-Line '## Reproduce'
Add-Line
Add-Line 'From the MoonSmith project root, with the saved case directory present:'
Add-Line
$relativeCase = [System.IO.Path]::GetRelativePath($projectRoot, $caseDirectory)
$caseArgument = if ($relativeCase.StartsWith('..')) { $caseDirectory } else { $relativeCase }
$caseArgument = $caseArgument.Replace("'", "''")
Add-Fence "pwsh -File scripts/moonsmith.ps1 replay -CasePath '$caseArgument'" 'powershell'
Add-Line
Add-Line 'A replay compares the finding kind and reduction key. The same result may still require human investigation; cross-backend agreement alone does not prove semantic correctness.'

Set-Content -LiteralPath $outputPath -Value ($lines -join "`n") -Encoding utf8
[pscustomobject]@{
    caseId = $finding.caseId
    reportPath = $outputPath
    evidenceStatus = $evidenceStatus
    includesReduction = $null -ne $reduction
    sourceSha256 = $sourceHash
} | ConvertTo-Json -Depth 3
