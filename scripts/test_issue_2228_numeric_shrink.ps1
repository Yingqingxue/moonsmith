[CmdletBinding()]
param(
    [string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) '.moonsmith/issue-2228-numeric-shrink'),
    [ValidateRange(1, 100)][int]$MaxSearchChecks = 24,
    [string]$VerifierScriptPath = (Join-Path $PSScriptRoot 'verify_seed.ps1')
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $projectRoot 'regressions/issue_2228_native_stack_overflow.mbt'
$source = [IO.File]::ReadAllText($sourcePath)
$matches = [regex]::Matches($source, 'println\(deep\(1_000_000\)\)')
if ($matches.Count -ne 1) {
    throw "Expected one known #2228 recursion-depth trigger, found $($matches.Count)."
}
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

function Test-RecursionDepth {
    param([Parameter(Mandatory)][int]$Depth)

    $candidatePath = Join-Path $OutputDirectory "candidate-$Depth.mbt"
    $candidateSource = [regex]::Replace(
        $source,
        'println\(deep\(1_000_000\)\)',
        "println(deep($Depth))",
        1
    )
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
    $reproduced = $report.finding -eq 'runtime-failure' -and
        $exitCode -eq 1 -and
        $native.status -eq 'runtime-failed' -and
        $native.exitCode -eq 139 -and
        [string]::IsNullOrEmpty([string]$native.output) -and
        $js.status -eq 'runtime-failed' -and
        $js.error -match 'RangeError|Maximum call stack size exceeded'
    $notReproduced = $report.finding -eq 'consistent' -and
        $exitCode -eq 0 -and
        $native.status -eq 'succeeded' -and
        $js.status -eq 'succeeded'
    [pscustomobject]@{
        depth = $Depth
        reproduced = $reproduced
        notReproduced = $notReproduced
        finding = [string]$report.finding
        nativeStatus = [string]$native.status
        nativeExitCode = $native.exitCode
        nativeError = [string]$native.error
        nativeStdoutLength = ([string]$native.output).Length
        javascriptStatus = [string]$js.status
        javascriptExitCode = $js.exitCode
        javascriptError = [string]$js.error
        javascriptStdoutLength = ([string]$js.output).Length
        javascriptRangeError = [bool]($js.error -match 'RangeError|Maximum call stack size exceeded')
        candidatePath = $candidatePath
    }
}

# The upstream reproducer is the known high endpoint. Search downward by
# halving, then bisect the first non-reproducing/reproducing interval. This is
# intentionally scoped to one integer argument, not an arbitrary-source AST reducer.
$checks = [Collections.Generic.List[object]]::new()
$high = 1000000
$highResult = Test-RecursionDepth -Depth $high
$checks.Add($highResult)
if (-not $highResult.reproduced -and -not $highResult.notReproduced) {
    throw 'The original #2228 probe returned an unknown outcome, not a valid reproduction or a clean non-reproduction.'
}
if ($highResult.notReproduced) {
    $summary = [pscustomobject]@{
        status = 'not-reproduced'
        source = 'upstream issue #2228; not discovered by MoonSmith'
        toolchainVersion = (& moon version | Select-Object -First 1)
        originalDepth = 1000000
        reducedDepth = $null
        searchChecks = 1
        finalIndependentReplays = 0
        reason = 'the baseline did not reproduce the native exit-139 and JavaScript RangeError signature; no shrink search was attempted'
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
    if (-not $result.reproduced -and -not $result.notReproduced) {
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
    if (-not $one.reproduced -and -not $one.notReproduced) {
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
    if (-not $result.reproduced -and -not $result.notReproduced) {
        throw "Candidate at depth $middle had an unknown result; it cannot be used as a lower bound."
    }
    if ($result.reproduced) {
        $high = $middle
    } else {
        $low = $middle
    }
}

$finalChecks = @()
for ($index = 0; $index -lt 3; $index++) {
    $finalChecks += Test-RecursionDepth -Depth $high
}
if (@($finalChecks | Where-Object { -not $_.reproduced }).Count -gt 0) {
    throw "Final independent replay was unstable at recursion depth $high."
}

$reducedSourcePath = Join-Path $OutputDirectory 'reduced.mbt'
Copy-Item -LiteralPath $finalChecks[0].candidatePath -Destination $reducedSourcePath -Force
$originalBytes = (Get-Item -LiteralPath $sourcePath).Length
$reducedBytes = (Get-Item -LiteralPath $reducedSourcePath).Length
$summary = [pscustomobject]@{
    status = 'verified_parameter_reduction'
    source = 'upstream issue #2228; not discovered by MoonSmith'
    toolchainVersion = (& moon version | Select-Object -First 1)
    originalDepth = 1000000
    reducedDepth = $high
    lowerNonReproducingDepth = $low
    minimalWithinMonotoneSearchInterval = ($high -eq $low + 1 -or $high -eq 1)
    monotonicityAssumption = 'greater recursive depth does not remove the same stack-overflow signature in this pinned runner/toolchain'
    originalBytes = $originalBytes
    reducedBytes = $reducedBytes
    searchChecks = $checks.Count
    finalIndependentReplays = $finalChecks.Count
    finalReplaysPassed = $true
    nativeSignature = 'runtime-failed; exit 139; empty redirected stdout'
    javascriptControl = 'RangeError'
    sourceChangedOnlyAtDepthArgument = (([IO.File]::ReadAllText($reducedSourcePath) -replace "deep\($high\)", 'deep(1_000_000)') -ceq $source)
    checks = $checks
    reducedSourcePath = $reducedSourcePath
}
$summary | ConvertTo-Json -Depth 8 | Set-Content `
    -LiteralPath (Join-Path $OutputDirectory 'numeric-shrink-result.json') -Encoding utf8NoBOM
$summary | ConvertTo-Json -Depth 8
