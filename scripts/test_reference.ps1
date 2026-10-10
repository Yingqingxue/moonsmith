$ErrorActionPreference = 'Stop'
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'

$normalRaw = & $verifyScript -Seed 42 -Depth 4 -NoPersist
$normal = $normalRaw | ConvertFrom-Json
if ($normal.finding -ne 'consistent' -or -not $normal.referenceChecked) {
    throw 'Reference verification did not accept the unmodified seed 42 case.'
}
if (-not $normal.expectedOutput) {
    throw 'The reference evaluator returned no expected output.'
}
if (@($normal.runs | Where-Object { $_.output -ne $normal.expectedOutput }).Count -ne 0) {
    throw 'A backend output differs from the reference value in the normal case.'
}

$arrayRaw = & $verifyScript -Seed 4 -Depth 3 -NoPersist
$array = $arrayRaw | ConvertFrom-Json
if ($array.finding -ne 'consistent' -or
    $array.referenceTrace.visited -notcontains 'valtype-enum-array-probe' -or
    @($array.runs | Where-Object { $_.output -ne $array.expectedOutput }).Count -ne 0) {
    throw 'Valtype enum array output did not agree with the reference evaluator.'
}

$injectedRaw = & $verifyScript -Seed 42 -Depth 4 -NoPersist `
    -InjectCommonWrongOutput '999'
$injectedExitCode = $LASTEXITCODE
$injected = $injectedRaw | ConvertFrom-Json
if ($injected.finding -ne 'reference-mismatch') {
    throw "Expected reference-mismatch, got $($injected.finding)."
}
if ($injectedExitCode -ne 1) {
    throw "Expected injected reference mismatch to exit 1, got $injectedExitCode."
}
if (@($injected.runs | Select-Object -ExpandProperty output -Unique).Count -ne 1) {
    throw 'Injected backend outputs are not identical.'
}

[pscustomobject]@{
    passed         = $true
    normalFinding = $normal.finding
    arrayFinding = $array.finding
    injectedFinding = $injected.finding
    expectedOutput = $normal.expectedOutput.Trim()
} | ConvertTo-Json -Depth 3
$global:LASTEXITCODE = 0
