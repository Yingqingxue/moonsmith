[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$BaselineReportPath,

    [Parameter(Mandatory, Position = 0)]
    [string]$CandidateSourcePath
)

$ErrorActionPreference = 'Stop'
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'

function Return-CheckerResult {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(0, 1, 125)]
        [int]$ExitCode,

        [Parameter(Mandatory)]
        [object]$Result
    )

    [Console]::Out.WriteLine(($Result | ConvertTo-Json -Depth 8 -Compress))
    exit $ExitCode
}

try {
    $resolvedBaseline = (Resolve-Path -LiteralPath $BaselineReportPath -ErrorAction Stop).Path
    $reportPath = if (Test-Path -LiteralPath $resolvedBaseline -PathType Container) {
        Join-Path $resolvedBaseline 'report.json'
    } else {
        $resolvedBaseline
    }
    if (-not (Test-Path -LiteralPath $reportPath -PathType Leaf)) {
        throw "Baseline report does not exist: $reportPath"
    }
    $baselineDirectory = Split-Path -Parent $reportPath
    $baselineSourcePath = Join-Path $baselineDirectory 'source.mbt'
    if (-not (Test-Path -LiteralPath $baselineSourcePath -PathType Leaf)) {
        throw "Baseline source does not exist: $baselineSourcePath"
    }

    $baseline = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($baseline.finding -eq 'consistent' -or
        [string]::IsNullOrWhiteSpace([string]$baseline.reductionKey)) {
        throw 'Baseline report must record a non-consistent finding and reductionKey.'
    }

    $hashProperty = $baseline.PSObject.Properties['sourceSha256']
    if ($null -eq $hashProperty -or [string]$hashProperty.Value -notmatch '^[0-9a-fA-F]{64}$') {
        throw 'Baseline report must contain a valid sourceSha256 to pin the original source.'
    }
    $baselineSourceSha256 = (Get-FileHash -LiteralPath $baselineSourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($baselineSourceSha256 -ne ([string]$hashProperty.Value).ToLowerInvariant()) {
        throw 'Baseline source does not match the SHA-256 recorded in its report.'
    }

    $candidatePath = (Resolve-Path -LiteralPath $CandidateSourcePath -ErrorAction Stop).Path
    if (-not (Test-Path -LiteralPath $candidatePath -PathType Leaf)) {
        throw "Candidate source is not a file: $candidatePath"
    }

    $targets = @($baseline.runs | Select-Object -ExpandProperty target)
    if ($targets.Count -eq 0) {
        throw 'Baseline report has no backend targets.'
    }
    $verifyArguments = @{
        Seed = [int]$baseline.seed
        Depth = [int]$baseline.depth
        Targets = $targets
        TimeoutSeconds = [int]$baseline.timeoutSeconds
        SourcePath = $candidatePath
        NoPersist = $true
    }

    $referenceCheckedProperty = $baseline.PSObject.Properties['referenceChecked']
    $referenceChecked = if ($null -ne $referenceCheckedProperty) {
        [bool]$referenceCheckedProperty.Value
    } else {
        -not [string]::IsNullOrEmpty([string]$baseline.expectedOutput)
    }
    if ($referenceChecked) {
        $verifyArguments.ExpectedOutput = [string]$baseline.expectedOutput
    }

    if ($baseline.injection) {
        if ($baseline.injection.kind -ne 'output-mismatch' -or
            [string]::IsNullOrWhiteSpace([string]$baseline.injection.target)) {
            throw 'This injected baseline cannot be replayed faithfully by the checker.'
        }
        $verifyArguments.InjectOutputMismatchTarget = [string]$baseline.injection.target
        if (-not [string]::IsNullOrEmpty([string]$baseline.injection.sourceTrigger)) {
            $verifyArguments.InjectOnlyWhenSourceContains = [string]$baseline.injection.sourceTrigger
        }
    }

    $rawOutput = & $verifyScript @verifyArguments
    $verifyExitCode = $LASTEXITCODE
    if ($null -eq $rawOutput) {
        throw "MoonSmith verification returned no report (exit code $verifyExitCode)."
    }
    $observed = ($rawOutput -join [Environment]::NewLine) | ConvertFrom-Json
    if ($observed.finding -eq 'environment-failure') {
        Return-CheckerResult -ExitCode 125 -Result ([pscustomobject]@{
            preserved = $false
            reason = 'environment-failure'
            expectedFinding = $baseline.finding
            observedFinding = $observed.finding
            sourceSha256 = $observed.sourceSha256
        })
    }

    $reductionKeyMatches = $observed.finding -eq $baseline.finding -and
        $observed.reductionKey -eq $baseline.reductionKey
    $result = [pscustomobject]@{
        preserved = $reductionKeyMatches
        reason = if ($reductionKeyMatches) { 'same-finding' } else { 'finding-changed' }
        expectedFinding = $baseline.finding
        observedFinding = $observed.finding
        reductionKeyMatches = $reductionKeyMatches
        sourceSha256 = $observed.sourceSha256
    }
    Return-CheckerResult -ExitCode $(if ($reductionKeyMatches) { 0 } else { 1 }) -Result $result
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    Return-CheckerResult -ExitCode 125 -Result ([pscustomobject]@{
        preserved = $false
        reason = 'checker-error'
        error = $_.Exception.Message
    })
}
