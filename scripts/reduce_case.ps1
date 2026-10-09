param(
    [Parameter()]
    [int]$Seed = 42,

    [Parameter()]
    [ValidateRange(0, 12)]
    [int]$Depth = 4,

    [Parameter()]
    [ValidateSet('js', 'wasm', 'wasm-gc', 'native', 'native-release')]
    [string[]]$Targets = @('js', 'wasm', 'wasm-gc'),

    [Parameter()]
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 10,

    [Parameter()]
    [ValidateRange(1, 10000)]
    [int]$MaxAttempts = 100,

    [Parameter()]
    [string]$InjectOutputMismatchTarget = '',

    [Parameter()]
    [string]$InjectOnlyWhenSourceContains = '',

    [Parameter()]
    [string]$InjectCommonWrongOutput = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
$workDirectory = Join-Path $projectRoot '.moonsmith\reduction'
$candidatePath = Join-Path $workDirectory ("seed_{0}_candidate.mbt" -f $Seed)
New-Item -ItemType Directory -Force -Path $workDirectory | Out-Null

function Invoke-Verification {
    param(
        [string]$Path = '',
        [string]$ReferenceOutput = ''
    )
    $options = @{
        Seed                       = $Seed
        Depth                      = $Depth
        Targets                    = $Targets
        TimeoutSeconds             = $TimeoutSeconds
        InjectOutputMismatchTarget = $InjectOutputMismatchTarget
        InjectOnlyWhenSourceContains = $InjectOnlyWhenSourceContains
        InjectCommonWrongOutput = $InjectCommonWrongOutput
        NoPersist                  = $true
    }
    if ($Path) {
        $options.SourcePath = $Path
        $options.ExpectedOutput = $ReferenceOutput
    }
    $raw = & $verifyScript @options
    if (-not $raw) {
        throw 'Verification returned no JSON report.'
    }
    $raw | ConvertFrom-Json
}

function Get-Candidates {
    param([int[]]$AcceptedIndices)
    $commandArgs = @('run', '--target', 'js', 'cmd/reduce', [string]$Seed, [string]$Depth)
    foreach ($index in $AcceptedIndices) {
        $commandArgs += [string]$index
    }
    $raw = & moon @commandArgs
    if ($LASTEXITCODE -ne 0) {
        throw "MoonBit candidate generator failed for seed $Seed."
    }
    $raw | ConvertFrom-Json
}

$baseline = Invoke-Verification
if ($baseline.finding -eq 'consistent') {
    throw "Seed $Seed has no failure to reduce."
}
if ($baseline.finding -eq 'environment-failure') {
    throw 'Environment failures cannot be reduced as compiler findings.'
}
$baselineConfirmation = Invoke-Verification
if ($baselineConfirmation.finding -ne $baseline.finding -or
    $baselineConfirmation.reductionKey -ne $baseline.reductionKey) {
    throw 'Baseline failure is not stable across two independent replays.'
}

$acceptedIndices = [System.Collections.Generic.List[int]]::new()
$history = [System.Collections.Generic.List[object]]::new()
$current = Get-Candidates -AcceptedIndices @()
$originalSource = [string]$current.source
$originalComplexity = [int]$current.complexity
$lastReport = $baseline
$attempts = 0
$exhausted = $false

while ($attempts -lt $MaxAttempts) {
    $accepted = $false
    foreach ($candidate in $current.candidates) {
        if ($attempts -ge $MaxAttempts) {
            $exhausted = $true
            break
        }
        if ([int]$candidate.complexity -ge [int]$current.complexity) {
            throw 'Candidate complexity did not decrease.'
        }
        $attempts++
        Set-Content -LiteralPath $candidatePath -Value ([string]$candidate.source) `
            -Encoding utf8 -NoNewline
        $report = Invoke-Verification -Path $candidatePath `
            -ReferenceOutput ([string]$candidate.expectedOutput)
        if ($report.finding -eq $baseline.finding -and
            $report.reductionKey -eq $baseline.reductionKey) {
            $acceptedIndices.Add([int]$candidate.index)
            $history.Add([pscustomobject]@{
                attempt    = $attempts
                index      = [int]$candidate.index
                complexity = [int]$candidate.complexity
                finding    = [string]$report.finding
            })
            $lastReport = $report
            $current = Get-Candidates -AcceptedIndices $acceptedIndices.ToArray()
            if ([int]$current.complexity -ne [int]$candidate.complexity) {
                throw 'Reconstructed AST differs from the accepted candidate.'
            }
            $accepted = $true
            break
        }
    }
    if (-not $accepted) {
        break
    }
}

$finalSource = [string]$current.source
Set-Content -LiteralPath $candidatePath -Value $finalSource -Encoding utf8 -NoNewline
$finalConfirmation = Invoke-Verification -Path $candidatePath `
    -ReferenceOutput ([string]$current.expectedOutput)
if ($finalConfirmation.finding -ne $baseline.finding -or
    $finalConfirmation.reductionKey -ne $baseline.reductionKey) {
    throw 'Minimal case did not preserve the failure on final replay.'
}
$lastReport = $finalConfirmation
$signatureBytes = [System.Text.Encoding]::UTF8.GetBytes([string]$baseline.signature)
$signatureHash = [System.Security.Cryptography.SHA256]::HashData($signatureBytes)
$caseId = [System.Convert]::ToHexString($signatureHash).Substring(0, 16).ToLowerInvariant()
$collection = if ($InjectOutputMismatchTarget -or $InjectCommonWrongOutput) {
    'injected'
} else {
    'corpus'
}
$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' +
    [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
$outputDirectory = Join-Path $projectRoot ".moonsmith\reduced\$collection\$caseId\$runId"
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
Set-Content -LiteralPath (Join-Path $outputDirectory 'original.mbt') `
    -Value $originalSource -Encoding utf8 -NoNewline
Set-Content -LiteralPath (Join-Path $outputDirectory 'minimal.mbt') `
    -Value $finalSource -Encoding utf8 -NoNewline

$result = [pscustomobject]@{
    schemaVersion       = 1
    caseId              = $caseId
    runId               = $runId
    seed                = $Seed
    depth               = $Depth
    targets             = $Targets
    finding             = $baseline.finding
    reductionKey        = $baseline.reductionKey
    originalSignature   = $baseline.signature
    finalSignature      = $lastReport.signature
    originalComplexity  = $originalComplexity
    finalComplexity     = [int]$current.complexity
    originalBytes       = [System.Text.Encoding]::UTF8.GetByteCount($originalSource)
    finalBytes          = [System.Text.Encoding]::UTF8.GetByteCount($finalSource)
    attempts            = $attempts
    acceptedSteps       = $acceptedIndices.Count
    attemptBudgetHit    = $exhausted -or $attempts -ge $MaxAttempts
    acceptedIndices     = @($acceptedIndices.ToArray())
    history             = @($history.ToArray())
    outputDirectory     = $outputDirectory
    injection           = $baseline.injection
}
$resultJson = $result | ConvertTo-Json -Depth 8
Set-Content -LiteralPath (Join-Path $outputDirectory 'reduction.json') `
    -Value $resultJson -Encoding utf8
$resultJson
