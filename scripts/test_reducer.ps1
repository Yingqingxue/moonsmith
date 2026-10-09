$ErrorActionPreference = 'Stop'
$reduceScript = Join-Path $PSScriptRoot 'reduce_case.ps1'
$raw = & $reduceScript -Seed 0 -Depth 2 `
    -InjectOutputMismatchTarget 'wasm-gc' `
    -InjectOnlyWhenSourceContains '(if' `
    -MaxAttempts 30
$reduceExitCode = $LASTEXITCODE
$result = $raw | ConvertFrom-Json

if ($result.finding -ne 'output-mismatch') {
    throw "Expected output-mismatch, got $($result.finding)."
}
if ($result.acceptedSteps -lt 1) {
    throw 'The reducer did not accept any candidate.'
}
if ($result.finalComplexity -ge $result.originalComplexity) {
    throw 'The final AST is not simpler than the original.'
}
if ($result.attemptBudgetHit) {
    throw 'The integration fixture exhausted its attempt budget.'
}
if ($reduceExitCode -ne 1) {
    throw "Expected the injected mismatch workflow to retain exit 1, got $reduceExitCode."
}

$minimalPath = Join-Path $result.outputDirectory 'minimal.mbt'
$originalPath = Join-Path $result.outputDirectory 'original.mbt'
$reportPath = Join-Path $result.outputDirectory 'reduction.json'
foreach ($path in @($minimalPath, $originalPath, $reportPath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Missing reduction artifact: $path"
    }
}
$minimalSource = Get-Content -LiteralPath $minimalPath -Raw -Encoding utf8
if (-not $minimalSource.Contains('(if')) {
    throw 'The reduced source lost the syntax that triggers the injected fault.'
}

[pscustomobject]@{
    passed             = $true
    originalComplexity = $result.originalComplexity
    finalComplexity    = $result.finalComplexity
    acceptedSteps      = $result.acceptedSteps
    attempts           = $result.attempts
    minimalPath        = $minimalPath
} | ConvertTo-Json -Depth 3
$global:LASTEXITCODE = 0
