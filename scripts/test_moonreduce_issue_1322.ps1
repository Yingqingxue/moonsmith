[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$MoonReduceBinary,

    [Parameter(Mandatory)]
    [string]$OutputDirectory
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
$sourcePath = Join-Path $projectRoot 'regressions/issue_1322_native_valtype_enum_array/repro.mbt'
$pwshPath = (Get-Process -Id $PID).Path
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$rawReport = & $pwshPath -NoProfile -File $verifyScript -Seed 0 -Depth 0 -Targets 'native' `
    -TimeoutSeconds 180 -SourcePath $sourcePath
$verifyExitCode = $LASTEXITCODE
if ($null -eq $rawReport) {
    throw "MoonSmith emitted no report for the upstream #1322 reproducer (exit code $verifyExitCode)."
}
$baseline = ($rawReport -join [Environment]::NewLine) | ConvertFrom-Json
$baseline | ConvertTo-Json -Depth 10 | Set-Content `
    -LiteralPath (Join-Path $OutputDirectory 'verifier-result.json') -Encoding utf8NoBOM

function Write-InteropSummary {
    param([Parameter(Mandatory)][object]$Summary)

    $summaryPath = Join-Path $OutputDirectory 'moonreduce-result.json'
    $Summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
    $Summary | ConvertTo-Json -Depth 8 -Compress
}

if ($baseline.finding -eq 'environment-failure') {
    $nativeRun = $baseline.runs | Where-Object target -eq 'native' | Select-Object -First 1
    if ($nativeRun.status -ne 'unavailable') {
        throw "The upstream #1322 verifier had an environment failure, not an unavailable native compiler: $($nativeRun.error)"
    }
    Write-InteropSummary ([pscustomobject]@{
        status = 'skipped-native-unavailable'
        source = 'upstream issue #1322; not discovered by MoonSmith'
        reductionAttempted = $false
    })
    return
}

if ($baseline.finding -eq 'consistent') {
    if ($verifyExitCode -ne 0) {
        throw "Expected the non-reproduced #1322 control to exit 0; got $verifyExitCode."
    }
    Write-InteropSummary ([pscustomobject]@{
        status = 'not-reproduced'
        source = 'upstream issue #1322; not discovered by MoonSmith'
        reductionAttempted = $false
        toolchainVersion = $baseline.toolchainVersion
    })
    return
}

if ($baseline.finding -ne 'compile-failure' -or $verifyExitCode -ne 1) {
    throw "Unexpected result for the known upstream #1322 reproducer: finding=$($baseline.finding); exit=$verifyExitCode."
}
$nativeRun = $baseline.runs | Where-Object target -eq 'native' | Select-Object -First 1
if ($nativeRun.status -ne 'compile-failed' -or
    $nativeRun.error -notmatch 'uninitialized non-null GC ref arrays are not lowered') {
    throw 'The native compile failure did not match the externally reported #1322 signature.'
}
if ([string]::IsNullOrWhiteSpace([string]$baseline.reductionKey) -or
    [string]::IsNullOrWhiteSpace([string]$baseline.sourceSha256)) {
    throw 'MoonSmith did not persist a reduction key and source hash for the known #1322 finding.'
}

# Keep the current-run baseline and exact fixture together for the checker;
# do not rely on a potentially older corpus report with the same case ID.
$checkerSourcePath = Join-Path $OutputDirectory 'source.mbt'
$checkerBaselinePath = Join-Path $OutputDirectory 'baseline-report.json'
Copy-Item -LiteralPath $sourcePath -Destination $checkerSourcePath
$baseline | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $checkerBaselinePath -Encoding utf8NoBOM

$reductionDirectory = Join-Path $OutputDirectory 'moonreduce-reduction'
$moonReduceArguments = @(
    'reduce',
    '--input', $checkerSourcePath,
    '--format', 'lines',
    '--checker', $pwshPath,
    '--checker-arg', '-NoProfile',
    '--checker-arg', '-File',
    '--checker-arg', (Join-Path $PSScriptRoot 'moonreduce_checker.ps1'),
    '--checker-arg', '-BaselineReportPath',
    '--checker-arg', $checkerBaselinePath,
    '--out', $reductionDirectory,
    '--timeout-ms', '60000',
    '--max-tests', '100'
)
$moonReduceOutput = & $MoonReduceBinary @moonReduceArguments 2>&1
$moonReduceExitCode = $LASTEXITCODE
if ($moonReduceExitCode -ne 0) {
    throw "MoonReduce failed on the externally reported #1322 finding (exit=$moonReduceExitCode): $($moonReduceOutput -join [Environment]::NewLine)"
}

$reductionReportPath = Join-Path $reductionDirectory 'report.json'
if (-not (Test-Path -LiteralPath $reductionReportPath -PathType Leaf)) {
    throw 'MoonReduce did not write a report for the known #1322 finding.'
}
$reductionReport = Get-Content -LiteralPath $reductionReportPath -Raw | ConvertFrom-Json
if ($reductionReport.status -notin @('verified_reduction', 'verified_unchanged') -or
    -not $reductionReport.verification_passed) {
    throw "MoonReduce did not independently verify the known #1322 finding: $($reductionReport.status)."
}

Write-InteropSummary ([pscustomobject]@{
    status = [string]$reductionReport.status
    source = 'upstream issue #1322; not discovered by MoonSmith'
    originalBytes = [long]$reductionReport.original_bytes
    reducedBytes = [long]$reductionReport.reduced_bytes
    acceptedCandidates = [int]$reductionReport.accepted_candidates
    searchTests = [int]$reductionReport.search_tests
    verificationPassed = [bool]$reductionReport.verification_passed
    toolchainVersion = $baseline.toolchainVersion
})
