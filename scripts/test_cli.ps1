$ErrorActionPreference = 'Stop'
$cli = Join-Path $PSScriptRoot 'moonsmith.ps1'
$verify = Join-Path $PSScriptRoot 'verify_seed.ps1'
$batchRunner = Join-Path $PSScriptRoot 'run_batch.ps1'

$seedRangeRejected = $false
try {
    & $batchRunner -SeedStart ([int]::MaxValue) -Count 2 -Depth 0 `
        -Targets @('js') | Out-Null
}
catch {
    if ($_.Exception.Message -notmatch 'Seed range exceeds the 32-bit signed Int maximum') {
        throw
    }
    $seedRangeRejected = $true
}
if (-not $seedRangeRejected) {
    throw 'A seed batch extending beyond the signed Int range was not rejected.'
}

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

$nativeReleaseRaw = & pwsh -NoProfile -File $verify -Seed 0 -Depth 4 `
    -Targets 'native-release' -NoPersist
$nativeReleaseExitCode = $LASTEXITCODE
$nativeRelease = $nativeReleaseRaw | ConvertFrom-Json
if ($nativeRelease.runs.Count -ne 1 -or
    $nativeRelease.runs[0].target -ne 'native-release' -or
    $nativeRelease.runs[0].backend -ne 'native' -or
    $nativeRelease.runs[0].buildMode -ne 'release') {
    throw 'native-release did not preserve its public target, native backend, and release build mode.'
}
if ($null -eq $nativeCompiler) {
    if ($nativeReleaseExitCode -ne 1 -or
        $nativeRelease.finding -ne 'environment-failure' -or
        $nativeRelease.runs[0].status -ne 'unavailable') {
        throw 'native-release without a C toolchain was not classified as an environment failure.'
    }
}
elseif ($nativeReleaseExitCode -ne 0 -or
    $nativeRelease.finding -ne 'consistent' -or
    $nativeRelease.runs[0].status -ne 'succeeded') {
    throw 'native-release with a compatible C toolchain did not pass the differential probe.'
}

$releaseBatchRaw = & $cli fuzz -SeedStart 0 -Count 1 -Depth 0 `
    -Targets @('native-release')
$releaseBatchExitCode = $LASTEXITCODE
$releaseBatch = $releaseBatchRaw | ConvertFrom-Json
if ($releaseBatch.count -ne 1 -or
    $releaseBatch.targets.Count -ne 1 -or
    $releaseBatch.targets[0] -ne 'native-release') {
    throw 'fuzz did not preserve native-release through the batch CLI.'
}
if ($null -eq $nativeCompiler) {
    if ($releaseBatchExitCode -ne 1 -or
        $releaseBatch.counts.'environment-failure' -ne 1) {
        throw 'native-release batch without a C toolchain was not classified as an environment failure.'
    }
}
elseif ($releaseBatchExitCode -ne 0 -or
    $releaseBatch.counts.consistent -ne 1) {
    throw 'native-release batch with a compatible C toolchain did not pass.'
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
$expectedSourceLineMaximum = ($batch.cases |
    Measure-Object -Property sourceLineCount -Maximum).Maximum
if ($LASTEXITCODE -ne 0 -or $batch.count -ne 2 -or
    $batch.unexpectedCount -ne 0 -or $batch.uniqueProgramBodies -ne 2 -or
    $batch.schemaVersion -lt 6 -or $batch.casesWithChoiceMatch -lt 1 -or
    $batch.casesWithForLoop -lt 1 -or $batch.casesWithForIteration -lt 1 -or
    $batch.casesWithValtypeRaiseProbe -lt 1 -or
    $batch.casesWithSourceLineCount -ne $batch.count -or
    $batch.sourceLineCountMaximum -ne $expectedSourceLineMaximum -or
    @($batch.cases | Where-Object { $null -eq $_.sourceLineCount }).Count -ne 0 -or
    $batch.referencePathCaseCounts.'valtype-raise-success-path' -lt 1 -or
    $batch.referencePathCaseCounts.'valtype-raise-error-path' -lt 1) {
    throw 'fuzz did not return a clean two-seed batch.'
}

$generatorLimitRaw = & $cli fuzz -SeedStart 8302 -Count 1 -Depth 11
$generatorLimitExitCode = $LASTEXITCODE
$generatorLimit = $generatorLimitRaw | ConvertFrom-Json
if ($generatorLimitExitCode -ne 1 -or
    $generatorLimit.counts.'generator-limit' -ne 1 -or
    $generatorLimit.cases[0].finding -ne 'generator-limit' -or
    $generatorLimit.cases[0].sourceLineCount -le 16300 -or
    $generatorLimit.cases[0].sourceLineLimit -ne 16300 -or
    $generatorLimit.cases[0].error -notmatch 'text-segment limit at 16384 lines') {
    throw 'oversized generated source was not classified as generator-limit.'
}

$nearLimitRaw = & $verify -Seed 8166 -Depth 10 -Targets @('wasm') -NoPersist
$nearLimit = $nearLimitRaw | ConvertFrom-Json
$nearLimitSource = Get-Content -LiteralPath $nearLimit.casePath -Raw -Encoding utf8
$nearLimitLineCount = [regex]::Matches($nearLimitSource, "`n").Count
if ($nearLimit.finding -ne 'consistent' -or $nearLimitLineCount -ge 16300 -or
    $nearLimit.sourceLineCount -ne $nearLimitLineCount -or
    $nearLimit.sourceLineLimit -ne 16300) {
    throw 'source below the configured line limit was incorrectly rejected.'
}

$injected = (& $verify -Seed 0 -Depth 3 `
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
    -not $reportMarkdown.Contains('wasm-gc / default') -or
    -not $reportMarkdown.Contains('## Reproduce')) {
    throw 'report did not render a clearly labelled Markdown finding.'
}

[pscustomobject]@{
    passed = $true
    doctorReady = $doctor.ready
    nativeCompilerAvailable = ($null -ne $nativeCompiler)
    nativeFinding = $native.finding
    nativeReleaseFinding = $nativeRelease.finding
    nativeReleaseBuildMode = $nativeRelease.runs[0].buildMode
    nativeReleaseBatchFinding = if ($null -eq $nativeCompiler) { 'environment-failure' } else { 'consistent' }
    boundarySeeds = $boundaryResults
    batchCount = $batch.count
    uniqueProgramBodies = $batch.uniqueProgramBodies
    generatorLimitCount = $generatorLimit.counts.'generator-limit'
    nearLimitLineCount = $nearLimitLineCount
    replayFinding = $replay.replayFinding
    seedRangeOverflowRejected = $seedRangeRejected
    reportPath = $rendered.reportPath
} | ConvertTo-Json -Depth 3
