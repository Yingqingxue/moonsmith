[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) '.moonsmith/issue-2228-numeric-shrink'),
    [ValidateRange(1, 100)][int]$MaxSearchChecks = 24,
    [string]$VerifierScriptPath = (Join-Path $PSScriptRoot 'verify_seed.ps1'),
    [string]$SourcePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'regressions/issue_2228_native_stack_overflow.mbt')
)

$ErrorActionPreference = 'Stop'
$sourcePath = (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
$source = [IO.File]::ReadAllText($sourcePath)
$depthPattern = 'println\(deep\((?<depth>[\d_]+)\)\)'
$depthMatch = [regex]::Match($source, $depthPattern)
if (-not $depthMatch.Success -or [regex]::Matches($source, $depthPattern).Count -ne 1) {
    throw 'Expected exactly one println(deep(<integer>)) recursion-depth trigger.'
}
$originalDepth = [int](($depthMatch.Groups['depth'].Value) -replace '_', '')
if ($originalDepth -lt 1) {
    throw "The recursion-depth trigger must be positive; got $originalDepth."
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Test-RecursionDepth {
    param([Parameter(Mandatory)][int]$Depth)

    $candidatePath = Join-Path $OutputDirectory "candidate-$Depth.mbt"
    $literal = $depthMatch.Groups['depth']
    $candidateSource = $source.Remove($literal.Index, $literal.Length).Insert($literal.Index, [string]$Depth)
    [IO.File]::WriteAllText($candidatePath, $candidateSource, [Text.UTF8Encoding]::new($false))
    $raw = & $VerifierScriptPath -Seed 0 -Depth 0 -Targets @('native', 'js') `
        -TimeoutSeconds 60 -SourcePath $candidatePath -NoPersist
    if ($null -eq $raw) {
        throw "MoonSmith emitted no report at recursion depth $Depth."
    }
    $report = ($raw -join [Environment]::NewLine) | ConvertFrom-Json
    # Like other PowerShell scripts, verify_seed does not set LASTEXITCODE on
    # its normal (consistent) path. Derive its documented 0/1 result from the
    # structured finding, leaving native child exit 139 in the run record.
    $exitCode = if ($report.finding -eq 'consistent') { 0 } else { 1 }
    $native = $report.runs | Where-Object target -eq 'native' | Select-Object -First 1
    $js = $report.runs | Where-Object target -eq 'js' | Select-Object -First 1
    $nativeOutput = [string]$native.output
    $nativeOutputLines = [regex]::Split($nativeOutput, '\r?\n')
    # deep(n) returns n after exactly n recursive increments. A candidate that
    # completes natively therefore prints the depth, not the base-case value 0.
    $nativeNormalOutput = $nativeOutputLines -contains 'before-deep-recursion' -and
        $nativeOutputLines -contains [string]$Depth
    $nativeReportedCrash = $native.status -eq 'runtime-failed' -and
        $native.exitCode -eq 139
    $jsRangeError = $js.error -match 'RangeError|Maximum call stack size exceeded'
    $reproduced = $report.finding -eq 'runtime-failure' -and
        $exitCode -eq 1 -and
        $nativeReportedCrash -and
        [string]::IsNullOrEmpty($nativeOutput) -and
        $js.status -eq 'runtime-failed' -and
        $jsRangeError
    # A lower bound may have a different but fully observed outcome: e.g. the
    # native target returns the expected value while JS still reaches its
    # RangeError, or native still crashes while JS returns normally. These are
    # known absences of the exact paired signature, not unknown harness errors.
    $knownNativeSuccess = $native.status -eq 'succeeded' -and $nativeNormalOutput
    $knownJsSuccess = $js.status -eq 'succeeded'
    $signatureAbsent = ($report.finding -eq 'consistent' -and $exitCode -eq 0 -and
            $knownNativeSuccess -and $knownJsSuccess) -or
        ($knownNativeSuccess -and $js.status -eq 'runtime-failed' -and $jsRangeError) -or
        ($nativeReportedCrash -and -not [string]::IsNullOrEmpty($nativeOutput) -and
            $js.status -eq 'runtime-failed' -and $jsRangeError) -or
        ($nativeReportedCrash -and $knownJsSuccess)
    [pscustomobject]@{
        depth = $Depth
        reproduced = $reproduced
        signatureAbsent = $signatureAbsent
        finding = [string]$report.finding
        nativeStatus = [string]$native.status
        nativeExitCode = $native.exitCode
        nativeError = [string]$native.error
        nativeStdoutLength = $nativeOutput.Length
        nativeExpectedNormalOutput = $nativeNormalOutput
        javascriptStatus = [string]$js.status
        javascriptExitCode = $js.exitCode
        javascriptError = [string]$js.error
        javascriptStdoutLength = ([string]$js.output).Length
        javascriptRangeError = [bool]$jsRangeError
        candidatePath = $candidatePath
    }
}

# The upstream reproducer is the known high endpoint. Search downward by
# halving, then bisect the first non-reproducing/reproducing interval. This is
# intentionally scoped to one integer argument, not an arbitrary-source AST reducer.
$checks = [Collections.Generic.List[object]]::new()
$high = $originalDepth
$highResult = Test-RecursionDepth -Depth $high
$checks.Add($highResult)
if (-not $highResult.reproduced -and -not $highResult.signatureAbsent) {
    throw 'The original #2228 probe returned an unknown outcome, not a valid reproduction or a clean non-reproduction.'
}
if ($highResult.signatureAbsent) {
    $summary = [pscustomobject]@{
        status = 'not-reproduced'
        source = 'upstream issue #2228; not discovered by MoonSmith'
        toolchainVersion = (& moon version | Select-Object -First 1)
        originalDepth = $originalDepth
        reducedDepth = $null
        searchChecks = 1
        finalIndependentReplays = 0
        reason = 'the baseline did not reproduce the paired native exit-139/empty-stdout and JavaScript RangeError signature; no shrink search was attempted'
        checks = $checks
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content `
        -LiteralPath (Join-Path $OutputDirectory 'numeric-shrink-result.json') -Encoding utf8NoBOM
    $summary | ConvertTo-Json -Depth 8
    return
}

$low = 0
$next = [int][Math]::Floor($high / 2)
while ($next -ge 1 -and $checks.Count -lt $MaxSearchChecks) {
    $result = Test-RecursionDepth -Depth $next
    $checks.Add($result)
    if (-not $result.reproduced -and -not $result.signatureAbsent) {
        $result | ConvertTo-Json -Depth 8 | Set-Content `
            -LiteralPath (Join-Path $OutputDirectory "unknown-depth-$next.json") -Encoding utf8NoBOM
        throw "Candidate at depth $next had an unknown result; it cannot be used as a lower bound. Details: $($result | ConvertTo-Json -Compress -Depth 8)"
    }
    if ($result.reproduced) {
        $high = $next
    } else {
        $low = $next
        break
    }
    $next = [int][Math]::Floor($high / 2)
}

if ($low -eq 0 -and $high -gt 1) {
    # Depth 1 is the smallest possible positive input; check it before treating
    # the found endpoint as minimal.
    $one = Test-RecursionDepth -Depth 1
    $checks.Add($one)
    if (-not $one.reproduced -and -not $one.signatureAbsent) {
        throw 'Candidate at recursion depth 1 had an unknown result; it cannot establish a lower bound.'
    }
    if ($one.reproduced) {
        $high = 1
    } else {
        $low = 1
    }
}

while ($high -gt $low + 1 -and $checks.Count -lt $MaxSearchChecks) {
    $middle = [int][Math]::Floor(($high + $low) / 2)
    $result = Test-RecursionDepth -Depth $middle
    $checks.Add($result)
    if (-not $result.reproduced -and -not $result.signatureAbsent) {
        throw "Candidate at depth $middle had an unknown result; it cannot be used as a lower bound."
    }
    if ($result.reproduced) {
        $high = $middle
    } else {
        $low = $middle
    }
}

$binarySearchHigh = $high
$stabilityAdjustmentChecks = [Collections.Generic.List[object]]::new()
$finalChecks = @()
$stabilityAdjusted = $false
$stabilityStep = [Math]::Max(1, [int][Math]::Ceiling($originalDepth / 100.0))
for ($adjustment = 0; $adjustment -le 20; $adjustment++) {
    $candidateChecks = @()
    for ($index = 0; $index -lt 3; $index++) {
        $candidateChecks += Test-RecursionDepth -Depth $high
    }
    $stabilityAdjustmentChecks.Add([pscustomobject]@{
        depth = $high
        reproducedRuns = @($candidateChecks | Where-Object reproduced).Count
        replays = $candidateChecks
    })
    if (@($candidateChecks | Where-Object { -not $_.reproduced }).Count -eq 0) {
        $finalChecks = $candidateChecks
        $stabilityAdjusted = $high -ne $binarySearchHigh
        break
    }
    if ($high -ge $originalDepth) {
        $stabilityAdjustmentChecks | ConvertTo-Json -Depth 8 | Set-Content `
            -LiteralPath (Join-Path $OutputDirectory 'unstable-final-replays.json') -Encoding utf8NoBOM
        throw "The original endpoint is not stable across three final replays at recursion depth $high."
    }
    $high = [Math]::Min($originalDepth, $high + $stabilityStep)
}
if ($finalChecks.Count -ne 3) {
    $stabilityAdjustmentChecks | ConvertTo-Json -Depth 8 | Set-Content `
        -LiteralPath (Join-Path $OutputDirectory 'unstable-final-replays.json') -Encoding utf8NoBOM
    throw "No three-replay-stable candidate was found after bounded upward adjustment from depth $binarySearchHigh."
}

$reducedSourcePath = Join-Path $OutputDirectory 'reduced.mbt'
Copy-Item -LiteralPath $finalChecks[0].candidatePath -Destination $reducedSourcePath -Force
$originalBytes = (Get-Item -LiteralPath $sourcePath).Length
$reducedBytes = (Get-Item -LiteralPath $reducedSourcePath).Length
$reducedSource = [IO.File]::ReadAllText($reducedSourcePath)
$reducedDepthMatch = [regex]::Match($reducedSource, $depthPattern)
$onlyParameterChanged = $false
if ($reducedDepthMatch.Success -and [regex]::Matches($reducedSource, $depthPattern).Count -eq 1) {
    $reducedLiteral = $reducedDepthMatch.Groups['depth']
    $restoredSource = $reducedSource.Remove($reducedLiteral.Index, $reducedLiteral.Length).Insert($reducedLiteral.Index, $depthMatch.Groups['depth'].Value)
    $onlyParameterChanged = $restoredSource -ceq $source
}
$summary = [pscustomobject]@{
    status = 'verified_parameter_reduction'
    source = 'upstream issue #2228; not discovered by MoonSmith'
    toolchainVersion = (& moon version | Select-Object -First 1)
    originalDepth = $originalDepth
    reducedDepth = $high
    lowerNonReproducingDepth = $low
    minimalWithinMonotoneSearchInterval = (-not $stabilityAdjusted -and ($high -eq $low + 1 -or $high -eq 1))
    binarySearchCandidate = $binarySearchHigh
    stabilityAdjusted = $stabilityAdjusted
    stabilityAdjustmentStep = $stabilityStep
    stabilityChecks = @($stabilityAdjustmentChecks.ToArray())
    monotonicityAssumption = 'greater recursive depth does not remove the same stack-overflow signature in this pinned runner/toolchain'
    originalBytes = $originalBytes
    reducedBytes = $reducedBytes
    searchChecks = $checks.Count
    finalIndependentReplays = $finalChecks.Count
    finalReplaysPassed = $true
    nativeSignature = 'runtime-failed; exit 139; empty redirected stdout'
    javascriptControl = 'RangeError'
    sourceChangedOnlyAtDepthArgument = $onlyParameterChanged
    inputSourcePath = $sourcePath
    checks = $checks
    reducedSourcePath = $reducedSourcePath
}
$summary | ConvertTo-Json -Depth 8 | Set-Content `
    -LiteralPath (Join-Path $OutputDirectory 'numeric-shrink-result.json') -Encoding utf8NoBOM
$summary | ConvertTo-Json -Depth 8
