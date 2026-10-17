param(
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
$sourcePath = Join-Path $projectRoot 'regressions/issue_2228_native_stack_overflow.mbt'

# CI sets the upstream report's 8 MiB Linux stack limit and disables core files.
# verify_seed launches `moon run` as a child and bounds it with a timeout.
$raw = & $verifyScript -SourcePath $sourcePath -Targets @('native', 'js') `
    -TimeoutSeconds $TimeoutSeconds -NoPersist
$verifyExitCode = $LASTEXITCODE
$report = $raw | ConvertFrom-Json
$native = $report.runs | Where-Object target -eq 'native' | Select-Object -First 1
$js = $report.runs | Where-Object target -eq 'js' | Select-Object -First 1
$outputLines = if ($null -ne $native) {
    [regex]::Split([string]$native.output, '\r?\n')
} else {
    @()
}

if ($verifyExitCode -ne 1 -or $null -eq $native -or $null -eq $js -or
    $js.status -ne 'runtime-failed' -or
    $js.error -notmatch 'RangeError|Maximum call stack size exceeded') {
    throw "Expected the JavaScript control to report a stack RangeError; verifierExit=$verifyExitCode, finding=$($report.finding), jsStatus=$($js.status), jsExit=$($js.exitCode), jsError=[$($js.error)]."
}

if ($native.status -eq 'runtime-failed' -and $native.exitCode -eq 139 -and
    [string]::IsNullOrEmpty([string]$native.output)) {
    $classification = 'upstream-reported-sigsegv-reproduced'
} elseif ($native.status -eq 'succeeded' -and
    $outputLines -contains 'before-deep-recursion' -and
    $outputLines -contains '0') {
    # Keep this historical regression useful after a future upstream fix.
    $classification = 'not-reproduced-on-this-toolchain'
} else {
    throw "Unexpected native stack-overflow probe result; verifierExit=$verifyExitCode, finding=$($report.finding), status=$($native.status), exit=$($native.exitCode), output=[$($native.output)], timedOut=$($native.status -eq 'timed-out')."
}

$result = [pscustomobject]@{
    upstreamIssue = 2228
    sourceIssue = 'https://github.com/moonbitlang/moon/issues/2228'
    origin = 'Externally reported; not discovered by MoonSmith.'
    classification = $classification
    finding = $report.finding
    targetStatus = $native.status
    targetExitCode = $native.exitCode
    stdoutBytes = [System.Text.Encoding]::UTF8.GetByteCount([string]$native.output)
    stderrBytes = [System.Text.Encoding]::UTF8.GetByteCount([string]$native.error)
    javascriptStatus = $js.status
    javascriptHasRangeError = $js.error -match 'RangeError|Maximum call stack size exceeded'
    timeoutSeconds = $TimeoutSeconds
    toolchainVersion = $report.toolchainVersion
}

$evidenceDirectory = Join-Path $projectRoot '.moonsmith'
New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
$evidencePath = Join-Path $evidenceDirectory 'issue_2228.json'
$resultJson = $result | ConvertTo-Json -Depth 3
Set-Content -LiteralPath $evidencePath -Value $resultJson -Encoding utf8
$resultJson
