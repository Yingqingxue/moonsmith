$ErrorActionPreference = 'Stop'
$cli = Join-Path $PSScriptRoot 'moonsmith.ps1'
$verify = Join-Path $PSScriptRoot 'verify_seed.ps1'

$doctor = (& $cli doctor | ConvertFrom-Json)
if (-not $doctor.ready -or $LASTEXITCODE -ne 0) {
    throw 'doctor did not validate the three default backends.'
}

$batch = (& $cli fuzz -SeedStart 0 -Count 2 -Depth 4 | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or $batch.count -ne 2 -or
    $batch.unexpectedCount -ne 0 -or $batch.uniqueProgramBodies -ne 2 -or
    $batch.schemaVersion -lt 5 -or $batch.casesWithChoiceMatch -lt 1 -or
    $batch.casesWithForLoop -lt 1 -or $batch.casesWithForIteration -lt 1 -or
    $batch.casesWithValtypeRaiseProbe -lt 1 -or
    $batch.referencePathCaseCounts.'valtype-raise-success-path' -lt 1 -or
    $batch.referencePathCaseCounts.'valtype-raise-error-path' -lt 1) {
    throw 'fuzz did not return a clean two-seed batch.'
}

$generatorLimitRaw = & $cli fuzz -SeedStart 8163 -Count 1 -Depth 10
$generatorLimitExitCode = $LASTEXITCODE
$generatorLimit = $generatorLimitRaw | ConvertFrom-Json
if ($generatorLimitExitCode -ne 1 -or
    $generatorLimit.counts.'generator-limit' -ne 1 -or
    $generatorLimit.cases[0].finding -ne 'generator-limit' -or
    $generatorLimit.cases[0].error -notmatch 'text-segment limit at 16384 lines') {
    throw 'oversized generated source was not classified as generator-limit.'
}

$injected = (& $verify -Seed 0 -Depth 2 `
    -InjectOutputMismatchTarget wasm-gc `
    -InjectOnlyWhenSourceContains '(if' | ConvertFrom-Json)
if ($injected.finding -ne 'output-mismatch' -or -not $injected.savedTo) {
    throw 'Failed to prepare the explicitly injected replay fixture.'
}

$replay = (& $cli replay -CasePath $injected.savedTo | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or -not $replay.reproduced) {
    throw 'replay did not reproduce the saved injected finding.'
}

$rendered = (& $cli report -CasePath $injected.savedTo -Force | ConvertFrom-Json)
$reportMarkdown = Get-Content -LiteralPath $rendered.reportPath -Raw
if ($LASTEXITCODE -ne 0 -or -not $rendered.reportPath -or
    -not $reportMarkdown.Contains('HARNESS-INJECTED DEMONSTRATION') -or
    -not $reportMarkdown.Contains('## Backend results') -or
    -not $reportMarkdown.Contains('## Reproduce')) {
    throw 'report did not render a clearly labelled Markdown finding.'
}

[pscustomobject]@{
    passed = $true
    doctorReady = $doctor.ready
    batchCount = $batch.count
    uniqueProgramBodies = $batch.uniqueProgramBodies
    generatorLimitCount = $generatorLimit.counts.'generator-limit'
    replayFinding = $replay.replayFinding
    reportPath = $rendered.reportPath
} | ConvertTo-Json -Depth 3
