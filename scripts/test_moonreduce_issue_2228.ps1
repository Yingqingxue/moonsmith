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
$sourcePath = Join-Path $projectRoot 'regressions/issue_2228_native_stack_overflow.mbt'
$pwshPath = (Get-Process -Id $PID).Path
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$verifyForCommand = $verifyScript.Replace("'", "''")
$sourceForCommand = $sourcePath.Replace("'", "''")
$verifyCommand = "& '$verifyForCommand' -Seed 0 -Depth 0 -Targets @('native','js') -TimeoutSeconds 60 -SourcePath '$sourceForCommand' -NoPersist"
$rawReport = & $pwshPath -NoProfile -Command $verifyCommand
$verifyExitCode = $LASTEXITCODE
if ($null -eq $rawReport) {
    throw "MoonSmith emitted no report for upstream #2228 (exit code $verifyExitCode)."
}
$baseline = ($rawReport -join [Environment]::NewLine) | ConvertFrom-Json
$baseline | ConvertTo-Json -Depth 10 | Set-Content `
    -LiteralPath (Join-Path $OutputDirectory 'verifier-result.json') -Encoding utf8NoBOM

function Write-StudySummary {
    param([Parameter(Mandatory)][object]$Summary)

    $summaryPath = Join-Path $OutputDirectory 'moonreduce-result.json'
    $Summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $summaryPath -Encoding utf8NoBOM
    $Summary | ConvertTo-Json -Depth 8 -Compress
}

$native = $baseline.runs | Where-Object target -eq 'native' | Select-Object -First 1
$js = $baseline.runs | Where-Object target -eq 'js' | Select-Object -First 1
$knownNativeCrash = $baseline.finding -eq 'runtime-failure' -and
    $verifyExitCode -eq 1 -and
    $native.status -eq 'runtime-failed' -and
    $native.exitCode -eq 139 -and
    [string]::IsNullOrEmpty([string]$native.output)
$knownJavaScriptControl = $js.status -eq 'runtime-failed' -and
    $js.error -match 'RangeError|Maximum call stack size exceeded'

if (-not $knownNativeCrash -or -not $knownJavaScriptControl) {
    Write-StudySummary ([pscustomobject]@{
        status = 'not-reproduced'
        source = 'upstream issue #2228; not discovered by MoonSmith'
        reductionAttempted = $false
        finding = [string]$baseline.finding
        nativeStatus = [string]$native.status
        nativeExitCode = $native.exitCode
        javascriptStatus = [string]$js.status
        javascriptRangeError = [bool]($js.error -match 'RangeError|Maximum call stack size exceeded')
        toolchainVersion = $baseline.toolchainVersion
    })
    return
}

if ([string]::IsNullOrWhiteSpace([string]$baseline.reductionKey) -or
    [string]::IsNullOrWhiteSpace([string]$baseline.sourceSha256)) {
    throw 'MoonSmith did not persist the reduction key and source hash for upstream #2228.'
}

$checkerSourcePath = Join-Path $OutputDirectory 'source.mbt'
$baselinePath = Join-Path $OutputDirectory 'baseline-report.json'
Copy-Item -LiteralPath $sourcePath -Destination $checkerSourcePath
$baseline | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $baselinePath -Encoding utf8NoBOM

$reductionDirectory = Join-Path $OutputDirectory 'moonreduce-reduction'
$arguments = @(
    'reduce', '--input', $checkerSourcePath, '--format', 'lines',
    '--checker', $pwshPath,
    '--checker-arg', '-NoProfile',
    '--checker-arg', '-File',
    '--checker-arg', (Join-Path $PSScriptRoot 'moonreduce_checker.ps1'),
    '--checker-arg', '-BaselineReportPath',
    '--checker-arg', $baselinePath,
    '--checker-arg', '-RequiredSourceFragment',
    '--checker-arg', 'println("before-deep-recursion")',
    '--out', $reductionDirectory,
    '--timeout-ms', '60000',
    '--max-tests', '100'
)
$output = & $MoonReduceBinary @arguments 2>&1
$exitCode = $LASTEXITCODE
if ($exitCode -ne 0) {
    throw "MoonReduce failed on upstream #2228 (exit=$exitCode): $($output -join [Environment]::NewLine)"
}

$reportPath = Join-Path $reductionDirectory 'report.json'
$originalPath = Join-Path $reductionDirectory 'original.txt'
$reducedPath = Join-Path $reductionDirectory 'reduced.txt'
foreach ($path in @($reportPath, $originalPath, $reducedPath)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "MoonReduce omitted expected output: $path"
    }
}
$reduction = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
if ($reduction.status -notin @('verified_reduction', 'verified_unchanged') -or
    -not $reduction.verification_passed) {
    throw "MoonReduce did not independently verify its #2228 result: $($reduction.status)."
}

$original = [IO.File]::ReadAllText($originalPath)
$reduced = [IO.File]::ReadAllText($reducedPath)
$reducedTextLines = @($reduced -split '\r?\n' | Where-Object { $_.Trim().Length -gt 0 -and $_.Trim() -ne '///|' })
$requiredTriggerLines = @(
    'fn deep(n : Int) -> Int {',
    'if n <= 0 {',
    '1 + deep(n - 1)',
    'println("before-deep-recursion")',
    'println(deep(1_000_000))'
)
$triggerPreserved = $true
foreach ($line in $requiredTriggerLines) {
    if (-not $reduced.Contains($line)) { $triggerPreserved = $false }
}
if (-not $triggerPreserved) {
    throw 'MoonReduce accepted a result that dropped part of the stack-overflow trigger or the pre-crash stdout write.'
}
$originalContentLineCount = @($original -split '\r?\n' | Where-Object { $_.Trim().Length -gt 0 -and $_.Trim() -ne '///|' }).Count
$removedContentLines = $originalContentLineCount - $reducedTextLines.Count
$changeClass = & (Join-Path $PSScriptRoot 'classify_moonreduce_change.ps1') `
    -OriginalPath $originalPath -ReducedPath $reducedPath

# MoonReduce's pinned text strategies cannot edit integer literals. Continue
# the verified artifact with MoonSmith's separate, source-anchored parameter
# search so the combined pipeline can be measured without attributing the
# semantic change to MoonReduce.
$parameterDirectory = Join-Path $OutputDirectory 'moonsmith-parameter-reduction'
$parameterOutput = & (Join-Path $PSScriptRoot 'test_issue_2228_numeric_shrink.ps1') `
    -SourcePath $reducedPath `
    -OutputDirectory $parameterDirectory `
    -VerifierScriptPath $verifyScript
if (-not $parameterOutput) {
    throw 'MoonSmith parameter reduction emitted no result after MoonReduce.'
}
$parameterSummary = ($parameterOutput -join [Environment]::NewLine) | ConvertFrom-Json
if ($parameterSummary.status -ne 'verified_parameter_reduction' -or
    [int]$parameterSummary.reducedDepth -ge [int]$parameterSummary.originalDepth -or
    -not $parameterSummary.finalReplaysPassed -or
    -not $parameterSummary.sourceChangedOnlyAtDepthArgument) {
    throw "The composed MoonReduce + MoonSmith parameter-reduction pipeline did not verify: $($parameterSummary | ConvertTo-Json -Compress -Depth 5)"
}
$composedSourcePath = Join-Path $parameterDirectory 'reduced.mbt'
$composedReplay = & $verifyScript -Seed 0 -Depth 0 -Targets @('native', 'js') `
    -TimeoutSeconds 60 -SourcePath $composedSourcePath -NoPersist
if (-not $composedReplay) {
    throw 'The composed reduced source failed its independent final replay.'
}
$composedReport = ($composedReplay -join [Environment]::NewLine) | ConvertFrom-Json
$composedNative = $composedReport.runs | Where-Object target -eq 'native' | Select-Object -First 1
$composedJs = $composedReport.runs | Where-Object target -eq 'js' | Select-Object -First 1
if ($composedReport.finding -ne 'runtime-failure' -or
    $composedNative.status -ne 'runtime-failed' -or $composedNative.exitCode -ne 139 -or
    -not [string]::IsNullOrEmpty([string]$composedNative.output) -or
    $composedJs.status -ne 'runtime-failed' -or
    $composedJs.error -notmatch 'RangeError|Maximum call stack size exceeded') {
    throw 'The composed reduced source did not independently preserve the paired #2228 signature.'
}
$composedBytes = (Get-Item -LiteralPath $composedSourcePath).Length
if ($composedBytes -ge (Get-Item -LiteralPath $originalPath).Length) {
    throw "The composed pipeline did not reduce source bytes: original=$((Get-Item -LiteralPath $originalPath).Length), final=$composedBytes."
}

Write-StudySummary ([pscustomobject]@{
    status = [string]$reduction.status
    changeClass = [string]$changeClass
    source = 'upstream issue #2228; not discovered by MoonSmith'
    originalBytes = [long]$reduction.original_bytes
    reducedBytes = [long]$reduction.reduced_bytes
    acceptedCandidates = [int]$reduction.accepted_candidates
    searchTests = [int]$reduction.search_tests
    verificationPassed = [bool]$reduction.verification_passed
    triggerPreserved = $triggerPreserved
    preCrashOutputWritePreserved = $reduced.Contains('println("before-deep-recursion")')
    removedContentLines = $removedContentLines
    triggerPreservingContentReduction = $triggerPreserved -and $removedContentLines -gt 0
    composedPipeline = [pscustomobject]@{
        description = 'MoonReduce text deletion followed by separate MoonSmith numeric-parameter shrink'
        semanticStepProducer = 'MoonSmith, not MoonReduce'
        parameterBefore = [int]$parameterSummary.originalDepth
        parameterAfter = [int]$parameterSummary.reducedDepth
        adjacentLowerNonReproducing = [int]$parameterSummary.lowerNonReproducingDepth
        minimalWithinMonotoneSearchInterval = [bool]$parameterSummary.minimalWithinMonotoneSearchInterval
        searchChecks = [int]$parameterSummary.searchChecks
        independentParameterReplays = [int]$parameterSummary.finalIndependentReplays
        parameterSourceOnlyChangedAtArgument = [bool]$parameterSummary.sourceChangedOnlyAtDepthArgument
        finalReplayPreservedPairedSignature = $true
        totalBytesReduced = [long]((Get-Item -LiteralPath $originalPath).Length - $composedBytes)
        finalBytes = [long]$composedBytes
        parameterReducedSource = $composedSourcePath
    }
    toolchainVersion = $baseline.toolchainVersion
})
