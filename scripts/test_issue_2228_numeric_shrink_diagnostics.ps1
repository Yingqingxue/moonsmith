$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$mockVerifier = Join-Path $PSScriptRoot 'testdata/issue_2228_mock_verifier.ps1'

# Cover both branches of the checked-in #2228 probe without requiring a local
# native compiler: the reported SIGSEGV path and a hypothetical native fix.
$reproDirectory = Join-Path ([IO.Path]::GetTempPath()) "moonsmith-issue-2228-repro-$([guid]::NewGuid().ToString('N'))"
$reproOutput = & (Join-Path $PSScriptRoot 'test_issue_2228.ps1') `
    -VerifierScriptPath $mockVerifier -OutputDirectory $reproDirectory
$reproReport = ($reproOutput -join [Environment]::NewLine) | ConvertFrom-Json
if ($reproReport.classification -ne 'upstream-reported-sigsegv-reproduced' -or
    $reproReport.targetExitCode -ne 139 -or $reproReport.stdoutBytes -ne 0) {
    throw 'The mocked #2228 native-crash signature was not classified correctly.'
}

$fixedDirectory = Join-Path ([IO.Path]::GetTempPath()) "moonsmith-issue-2228-fixed-$([guid]::NewGuid().ToString('N'))"
$env:MOONSMITH_MOCK_NATIVE_FIXED = '1'
try {
    $fixedOutput = & (Join-Path $PSScriptRoot 'test_issue_2228.ps1') `
        -VerifierScriptPath $mockVerifier -OutputDirectory $fixedDirectory
} finally {
    Remove-Item Env:MOONSMITH_MOCK_NATIVE_FIXED -ErrorAction SilentlyContinue
}
$fixedReport = ($fixedOutput -join [Environment]::NewLine) | ConvertFrom-Json
if ($fixedReport.classification -ne 'not-reproduced-on-this-toolchain' -or
    $fixedReport.targetExitCode -ne 0 -or $fixedReport.stdoutBytes -eq 0) {
    throw 'The mocked native-success path after a hypothetical fix was not classified correctly.'
}

$outputDirectory = Join-Path ([IO.Path]::GetTempPath()) "moonsmith-numeric-shrink-unknown-$([guid]::NewGuid().ToString('N'))"
$unknownReport = Join-Path $outputDirectory 'unknown-depth-500000.json'
$caught = $false
$env:MOONSMITH_MOCK_UNKNOWN_AT_500K = '1'
try {
    & (Join-Path $PSScriptRoot 'test_issue_2228_numeric_shrink.ps1') `
        -OutputDirectory $outputDirectory `
        -VerifierScriptPath $mockVerifier
} catch {
    $caught = $true
    if ($_.Exception.Message -notmatch 'nativeStatus.*timed-out') {
        throw "Expected diagnostic exception to identify native timeout; got: $($_.Exception.Message)"
    }
} finally {
    Remove-Item Env:MOONSMITH_MOCK_UNKNOWN_AT_500K -ErrorAction SilentlyContinue
}
if (-not $caught) { throw 'Unknown verifier outcome should fail closed.' }
if (-not (Test-Path -LiteralPath $unknownReport)) { throw 'Unknown candidate JSON was not preserved.' }
$report = Get-Content -LiteralPath $unknownReport -Raw | ConvertFrom-Json
if ($report.finding -ne 'mixed-failure' -or $report.nativeStatus -ne 'timed-out' -or
    $report.javascriptStatus -ne 'runtime-failed' -or -not $report.javascriptRangeError) {
    throw 'Unknown candidate report did not preserve both backend classifications.'
}

# Separately verify that a known partial outcome (native normal completion,
# JS RangeError) is a non-match for the paired signature and can guide a
# bounded search to the first exact match. This models threshold behavior; it
# is a unit test, not evidence about MoonBit's actual stack limits.
$searchDirectory = Join-Path ([IO.Path]::GetTempPath()) "moonsmith-numeric-shrink-boundary-$([guid]::NewGuid().ToString('N'))"
$searchOutput = & (Join-Path $PSScriptRoot 'test_issue_2228_numeric_shrink.ps1') `
    -OutputDirectory $searchDirectory `
    -VerifierScriptPath $mockVerifier
$searchResult = ($searchOutput -join [Environment]::NewLine) | ConvertFrom-Json
$partial = $searchResult.checks | Where-Object depth -eq 500000 | Select-Object -First 1
if ($searchResult.status -ne 'verified_parameter_reduction' -or
    $searchResult.reducedDepth -ne 750000 -or
    -not $searchResult.minimalWithinMonotoneSearchInterval -or
    $searchResult.finalIndependentReplays -ne 3 -or
    -not $searchResult.sourceChangedOnlyAtDepthArgument -or
    $null -eq $partial -or -not $partial.signatureAbsent -or
    -not $partial.nativeExpectedNormalOutput) {
    throw 'Known partial outcomes did not produce the expected bounded parameter-search result.'
}
Write-Output 'Unknown outcomes fail closed with diagnostics; known partial signatures guide a tested bounded search.'
