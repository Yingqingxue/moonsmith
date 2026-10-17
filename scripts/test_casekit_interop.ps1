[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$CaseKitCliPath,

    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) '.moonsmith/casekit-interop')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
if (-not (Test-Path -LiteralPath $CaseKitCliPath -PathType Leaf)) {
    throw "CaseKit comparator executable does not exist: $CaseKitCliPath"
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Invoke-MoonSmithCase {
    param(
        [Parameter(Mandatory)][string]$Name,
        [hashtable]$ExtraParameters = @{},
        [Parameter(Mandatory)][string]$ExpectedFinding,
        [Parameter(Mandatory)][int]$ExpectedExitCode
    )

    $reportPath = Join-Path $OutputDirectory "$Name-moonsmith.json"
    $verifyArguments = @{
        Seed = 42
        Depth = 4
        Targets = @('js', 'wasm')
        NoPersist = $true
    }
    foreach ($key in $ExtraParameters.Keys) {
        $verifyArguments[$key] = $ExtraParameters[$key]
    }
    $raw = & $verifyScript @verifyArguments
    if ($null -eq $raw) {
        throw "MoonSmith emitted no report for CaseKit case '$Name'."
    }
    $report = ($raw -join [Environment]::NewLine) | ConvertFrom-Json
    # verify_seed.ps1 returns normally for a consistent report and executes
    # `exit 1` for findings; LASTEXITCODE is not set on the normal path when
    # this helper is invoked in-process with PowerShell's call operator.
    $verifyExitCode = if ($report.finding -eq 'consistent') { 0 } else { 1 }
    $report | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reportPath -Encoding utf8NoBOM
    if ($report.finding -ne $ExpectedFinding -or $verifyExitCode -ne $ExpectedExitCode) {
        throw "Unexpected MoonSmith result for '$Name': finding=$($report.finding), exit=$verifyExitCode."
    }
    return $report
}

function Write-CaseKitTranscript {
    param(
        [Parameter(Mandatory)][object]$Report,
        [Parameter(Mandatory)][string]$Target,
        [Parameter(Mandatory)][string]$Path
    )

    $run = $Report.runs | Where-Object target -eq $Target | Select-Object -First 1
    if ($null -eq $run -or $run.status -ne 'succeeded') {
        throw "CaseKit export requires a successful '$Target' run."
    }
    $transcript = [ordered]@{
        casekit = 1
        suite = "moonsmith-seed-$($Report.seed)"
        cases = @([ordered]@{
            id = 'program-stdout'
            value = [string]$run.output
        })
    }
    $transcript | ConvertTo-Json -Depth 20 -Compress | Set-Content `
        -LiteralPath $Path -Encoding utf8NoBOM
}

function Compare-CaseKitOutputs {
    param(
        [Parameter(Mandatory)][object]$Report,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ExpectedTarget,
        [Parameter(Mandatory)][string]$ActualTarget,
        [Parameter(Mandatory)][int]$ExpectedExitCode
    )

    $expectedPath = Join-Path $OutputDirectory "$Name-$ExpectedTarget.casekit.json"
    $actualPath = Join-Path $OutputDirectory "$Name-$ActualTarget.casekit.json"
    Write-CaseKitTranscript -Report $Report -Target $ExpectedTarget -Path $expectedPath
    Write-CaseKitTranscript -Report $Report -Target $ActualTarget -Path $actualPath
    $output = & $CaseKitCliPath $expectedPath $actualPath 2>&1
    $compareExitCode = $LASTEXITCODE
    if ($compareExitCode -ne $ExpectedExitCode) {
        throw "CaseKit comparison '$Name' returned $compareExitCode; expected $ExpectedExitCode. Output: $($output -join [Environment]::NewLine)"
    }
    return [pscustomobject]@{
        name = $Name
        expectedTarget = $ExpectedTarget
        actualTarget = $ActualTarget
        exitCode = $compareExitCode
        transcriptPaths = @($expectedPath, $actualPath)
    }
}

# CaseKit independently agrees on an ordinary same-output pair.
$normal = Invoke-MoonSmithCase -Name 'normal' `
    -ExpectedFinding 'consistent' -ExpectedExitCode 0
$normalComparison = Compare-CaseKitOutputs -Report $normal -Name 'normal' `
    -ExpectedTarget js -ActualTarget wasm -ExpectedExitCode 0

# A deliberately injected backend-only difference must be visible to CaseKit.
$divergent = Invoke-MoonSmithCase -Name 'injected-backend-difference' `
    -ExtraParameters @{ InjectOutputMismatchTarget = 'wasm'; InjectOnlyWhenSourceContains = '(if' } `
    -ExpectedFinding 'output-mismatch' -ExpectedExitCode 1
$divergentComparison = Compare-CaseKitOutputs -Report $divergent `
    -Name 'injected-backend-difference' -ExpectedTarget js -ActualTarget wasm `
    -ExpectedExitCode 1

# A common-mode wrong output is intentionally invisible to pairwise backend
# comparison, while MoonSmith's separate reference evaluator still catches it.
$commonMode = Invoke-MoonSmithCase -Name 'injected-common-mode-error' `
    -ExtraParameters @{ InjectCommonWrongOutput = '999' } `
    -ExpectedFinding 'reference-mismatch' -ExpectedExitCode 1
$commonModeComparison = Compare-CaseKitOutputs -Report $commonMode `
    -Name 'injected-common-mode-error' -ExpectedTarget js -ActualTarget wasm `
    -ExpectedExitCode 0

[pscustomobject]@{
    passed = $true
    casekitRole = 'independent comparator over MoonSmith-captured backend stdout'
    moonSmithReferenceCaughtCommonModeError = $commonMode.finding -eq 'reference-mismatch'
    comparisons = @($normalComparison, $divergentComparison, $commonModeComparison)
} | ConvertTo-Json -Depth 5
$global:LASTEXITCODE = 0
