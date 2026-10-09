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

$valtypeRaw = & $reduceScript -Seed 0 -Depth 4 `
    -Targets @('js', 'wasm', 'wasm-gc') `
    -InjectOutputMismatchTarget 'wasm' `
    -InjectOnlyWhenSourceContains '_ms_valtype_run' `
    -MaxAttempts 10
$valtypeExitCode = $LASTEXITCODE
$valtypeResult = $valtypeRaw | ConvertFrom-Json
if ($valtypeResult.finding -ne 'output-mismatch' -or
    $valtypeResult.acceptedSteps -lt 1 -or
    $valtypeResult.finalComplexity -ge $valtypeResult.originalComplexity) {
    throw 'The valtype probe did not retain a reducible injected mismatch.'
}
if ($valtypeExitCode -ne 1) {
    throw "Expected the valtype-injected mismatch workflow to retain exit 1, got $valtypeExitCode."
}
$valtypeMinimalPath = Join-Path $valtypeResult.outputDirectory 'minimal.mbt'
if (-not (Test-Path -LiteralPath $valtypeMinimalPath)) {
    throw "Missing valtype reduction artifact: $valtypeMinimalPath"
}
$valtypeMinimalSource = Get-Content -LiteralPath $valtypeMinimalPath -Raw -Encoding utf8
foreach ($trigger in @('#valtype', 'value : Double', 'raise MoonSmithValtypeError', 'try? _ms_valtype_make', '_ms_valtype_run')) {
    if (-not $valtypeMinimalSource.Contains($trigger)) {
        throw "The valtype reduction lost required trigger fragment: $trigger"
    }
}
if ($valtypeResult.injection.sourceTrigger -ne '_ms_valtype_run') {
    throw 'The valtype reduction was not guarded by the intended source trigger.'
}

[pscustomobject]@{
    passed             = $true
    originalComplexity = $result.originalComplexity
    finalComplexity    = $result.finalComplexity
    acceptedSteps      = $result.acceptedSteps
    attempts           = $result.attempts
    minimalPath        = $minimalPath
    valtypeOriginalComplexity = $valtypeResult.originalComplexity
    valtypeFinalComplexity = $valtypeResult.finalComplexity
    valtypeAcceptedSteps = $valtypeResult.acceptedSteps
    valtypeAttempts = $valtypeResult.attempts
    valtypeMinimalPath = $valtypeMinimalPath
} | ConvertTo-Json -Depth 3
$global:LASTEXITCODE = 0
