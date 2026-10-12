$ErrorActionPreference = 'Stop'
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'

function Normalize-Output {
    param([AllowNull()][string]$Output)
    if ($null -eq $Output) { return '' }
    return $Output.Replace("`r`n", "`n")
}

$normalRaw = & $verifyScript -Seed 42 -Depth 4 -NoPersist
$normal = $normalRaw | ConvertFrom-Json
if ($normal.finding -ne 'consistent' -or -not $normal.referenceChecked) {
    throw 'Reference verification did not accept the unmodified seed 42 case.'
}
if (-not $normal.expectedOutput) {
    throw 'The reference evaluator returned no expected output.'
}
if (@($normal.runs | Where-Object {
        (Normalize-Output $_.output) -ne (Normalize-Output $normal.expectedOutput)
    }).Count -ne 0) {
    throw 'A backend output differs from the reference value in the normal case.'
}

$arrayRaw = & $verifyScript -Seed 4 -Depth 3 -NoPersist
$array = $arrayRaw | ConvertFrom-Json
if ($array.finding -ne 'consistent' -or
    $array.referenceTrace.visited -notcontains 'valtype-enum-array-probe' -or
    @($array.runs | Where-Object {
        (Normalize-Output $_.output) -ne (Normalize-Output $array.expectedOutput)
    }).Count -ne 0) {
    throw 'Valtype enum array output did not agree with the reference evaluator.'
}

$combinedTargets = @('js', 'wasm', 'wasm-gc')
if ($null -ne (Get-Command cl, clang-cl, gcc, clang, cc -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    $combinedTargets += 'native'
    $combinedTargets += 'native-release'
}
$combinedRaw = & $verifyScript -Seed 44607 -Depth 4 `
    -Targets $combinedTargets -NoPersist
$combined = $combinedRaw | ConvertFrom-Json
if ($combined.finding -ne 'consistent' -or
    $combined.referenceTrace.visited -notcontains 'valtype-enum-array-probe' -or
    ($combined.referenceTrace.visited -notcontains 'valtype-raise-success-path' -and
        $combined.referenceTrace.visited -notcontains 'valtype-raise-error-path') -or
    @($combined.runs | Where-Object {
        (Normalize-Output $_.output) -ne (Normalize-Output $combined.expectedOutput)
    }).Count -ne 0) {
    $diagnostics = [pscustomobject]@{
        finding = $combined.finding
        expectedOutput = $combined.expectedOutput
        referenceTrace = $combined.referenceTrace
        runs = @($combined.runs | ForEach-Object {
            [pscustomobject]@{
                target = $_.target
                status = $_.status
                exitCode = $_.exitCode
                output = $_.output
                error = $_.error
            }
        })
    } | ConvertTo-Json -Depth 5
    throw "Combined enum array and valtype raise output did not agree across backends and reference.`n$diagnostics"
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
    combinedFinding = $combined.finding
    injectedFinding = $injected.finding
    expectedOutput = $normal.expectedOutput.Trim()
} | ConvertTo-Json -Depth 3
$global:LASTEXITCODE = 0
