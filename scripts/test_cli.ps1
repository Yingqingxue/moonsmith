$ErrorActionPreference = 'Stop'
$cli = Join-Path $PSScriptRoot 'moonsmith.ps1'
$verify = Join-Path $PSScriptRoot 'verify_seed.ps1'

$doctor = (& $cli doctor | ConvertFrom-Json)
if (-not $doctor.ready -or $LASTEXITCODE -ne 0) {
    throw 'doctor did not validate the three default backends.'
}

$nativeCompiler = Get-Command cl, clang-cl, gcc, clang, cc `
    -ErrorAction SilentlyContinue | Select-Object -First 1
$nativeRaw = & pwsh -NoProfile -File $verify -Seed 0 -Depth 4 `
    -Targets 'native' -NoPersist
$nativeExitCode = $LASTEXITCODE
$native = $nativeRaw | ConvertFrom-Json
if ($null -eq $nativeCompiler) {
    if ($nativeExitCode -ne 1 -or $native.finding -ne 'environment-failure' -or
        $native.runs[0].status -ne 'unavailable' -or
        $native.runs[0].error -notmatch 'cl, clang-cl, gcc, clang, or cc') {
        throw 'native without a C toolchain was not classified as an environment failure.'
    }
}
elseif ($nativeExitCode -ne 0 -or $native.finding -ne 'consistent' -or
    $native.runs[0].status -ne 'succeeded') {
    throw 'native with a compatible C toolchain did not pass the differential probe.'
}

$boundaryTargets = @('js', 'wasm', 'wasm-gc')
if ($null -ne $nativeCompiler) {
    $boundaryTargets += 'native'
}
$boundaryResults = @()
$verifyForCommand = $verify.Replace("'", "''")
$targetsForCommand = ($boundaryTargets | ForEach-Object { "'$_'" }) -join ','
foreach ($seed in @(-2147483648, -1, 2147483647)) {
    $boundaryCommand = "& '$verifyForCommand' -Seed $seed -Depth 3 -Targets @($targetsForCommand) -NoPersist"
    $boundaryRaw = & pwsh -NoProfile -Command $boundaryCommand
    $boundaryExitCode = $LASTEXITCODE
    $boundary = $boundaryRaw | ConvertFrom-Json
    if ($boundaryExitCode -ne 0 -or $boundary.finding -ne 'consistent' -or
        -not $boundary.referenceChecked -or
        $boundary.runs.Count -ne $boundaryTargets.Count -or
        @($boundary.runs | Where-Object status -ne 'succeeded').Count -ne 0) {
        throw "extreme seed $seed did not pass the complete backend differential check."
    }
    $boundaryResults += [pscustomobject]@{
        seed = $seed
        finding = $boundary.finding
        targets = @($boundary.runs | ForEach-Object target)
        expectedOutput = $boundary.expectedOutput
    }
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

$nearLimitRaw = & $verify -Seed 8166 -Depth 10 -Targets @('wasm') -NoPersist
$nearLimit = $nearLimitRaw | ConvertFrom-Json
$nearLimitSource = Get-Content -LiteralPath $nearLimit.casePath -Raw -Encoding utf8
$nearLimitLineCount = [regex]::Matches($nearLimitSource, "`n").Count
if ($nearLimit.finding -ne 'consistent' -or $nearLimitLineCount -ge 16300) {
    throw 'source below the configured line limit was incorrectly rejected.'
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
    nativeCompilerAvailable = ($null -ne $nativeCompiler)
    nativeFinding = $native.finding
    boundarySeeds = $boundaryResults
    batchCount = $batch.count
    uniqueProgramBodies = $batch.uniqueProgramBodies
    generatorLimitCount = $generatorLimit.counts.'generator-limit'
    nearLimitLineCount = $nearLimitLineCount
    replayFinding = $replay.replayFinding
    reportPath = $rendered.reportPath
} | ConvertTo-Json -Depth 3
