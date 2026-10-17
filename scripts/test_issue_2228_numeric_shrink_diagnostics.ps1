$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path ([IO.Path]::GetTempPath()) "moonsmith-numeric-shrink-test-$([guid]::NewGuid().ToString('N'))"
$unknownReport = Join-Path $outputDirectory 'unknown-depth-500000.json'
$caught = $false
try {
    & (Join-Path $PSScriptRoot 'test_issue_2228_numeric_shrink.ps1') `
        -OutputDirectory $outputDirectory `
        -VerifierScriptPath (Join-Path $PSScriptRoot 'testdata/issue_2228_mock_verifier.ps1')
} catch {
    $caught = $true
    if ($_.Exception.Message -notmatch 'finding.*mixed-failure') {
        throw "Expected diagnostic exception to identify mixed-failure; got: $($_.Exception.Message)"
    }
}
if (-not $caught) { throw 'Unknown verifier outcome should fail closed.' }
if (-not (Test-Path -LiteralPath $unknownReport)) { throw 'Unknown candidate JSON was not preserved.' }
$report = Get-Content -LiteralPath $unknownReport -Raw | ConvertFrom-Json
if ($report.finding -ne 'mixed-failure' -or $report.nativeStatus -ne 'succeeded' -or
    $report.javascriptStatus -ne 'runtime-failed' -or -not $report.javascriptRangeError) {
    throw 'Unknown candidate report did not preserve both backend classifications.'
}
Write-Output 'Unknown parameter-search outcomes fail closed and preserve structured diagnostics.'
