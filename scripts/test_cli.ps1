$ErrorActionPreference = 'Stop'
$cli = Join-Path $PSScriptRoot 'moonsmith.ps1'
$verify = Join-Path $PSScriptRoot 'verify_seed.ps1'
$batchRunner = Join-Path $PSScriptRoot 'run_batch.ps1'

$duplicateTargetsRejected = $false
try {
    & $verify -Seed 0 -Depth 0 -Targets @('js', 'js') -NoPersist | Out-Null
}
catch {
    if ($_.Exception.Message -notmatch 'Targets must not contain duplicates') {
        throw
    }
    $duplicateTargetsRejected = $true
}
if (-not $duplicateTargetsRejected) {
    throw 'verify_seed accepted a repeated backend and could produce a misleading parity report.'
}

$emptyTargetsRejected = $false
try {
    & $verify -Seed 0 -Depth 0 -Targets @() -NoPersist | Out-Null
}
catch {
    if ($_.Exception.Message -notmatch 'Targets must contain at least one backend') {
        throw
    }
    $emptyTargetsRejected = $true
}
if (-not $emptyTargetsRejected) {
    throw 'verify_seed accepted an empty backend matrix.'
}

$duplicateBatchTargetsRejected = $false
try {
    & $cli fuzz -SeedStart 0 -Count 1 -Depth 0 `
        -Targets @('js', 'js') | Out-Null
}
catch {
    if ($_.Exception.Message -notmatch 'Targets must not contain duplicates') {
        throw
    }
    $duplicateBatchTargetsRejected = $true
}
if (-not $duplicateBatchTargetsRejected) {
    throw 'fuzz accepted duplicate targets instead of rejecting the invalid matrix before scanning.'
}

$fmaProbeSource = (& moon run --target js cmd/main --fma-probe | Out-String).Trim()
if ($LASTEXITCODE -ne 0 -or
    -not $fmaProbeSource.Contains('seed=2262') -or
    -not $fmaProbeSource.Contains('_ms_fma_product') -or
    -not $fmaProbeSource.Contains('@string.parse_double(value)') -or
    -not $fmaProbeSource.Contains('_ms_fma_result == 0.0')) {
    throw 'The FMA probe CLI did not emit the reproducible typed source.'
}

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
$nativeRaw = & pwsh -NoProfile -File $verify -Seed 1 -Depth 4 `
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

$nativeReleaseRaw = & pwsh -NoProfile -File $verify -Seed 1 -Depth 4 `
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
    # Native debug is expected to hit the tracked #1322 compiler ICE for some
    # generated seeds. Keep boundary checks differential by using release here;
    # the debug signature is exercised separately by test_issue_1322.ps1.
    $boundaryTargets += 'native-release'
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
        $boundary.targetParity.status -ne 'pass' -or
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
$whileRaw = & pwsh -NoProfile -File $verify -Seed 1 -Depth 3 -NoPersist
$whileExitCode = $LASTEXITCODE
$whileProbe = $whileRaw | ConvertFrom-Json
if ($whileExitCode -ne 0 -or $whileProbe.finding -ne 'consistent' -or
    $whileProbe.referenceTrace.visited -notcontains 'while-loop' -or
    $whileProbe.referenceTrace.visited -notcontains 'while-iteration' -or
    $whileProbe.referenceTrace.visited -notcontains 'array-grow' -or
    $whileProbe.referenceTrace.visited -notcontains 'array-grow-index-0' -or
    @($whileProbe.runs | Where-Object status -ne 'succeeded').Count -ne 0) {
    throw 'bounded while-loop and array-growth probe did not agree across the default backends.'
}
$expectedSourceLineMaximum = ($batch.cases |
    Measure-Object -Property sourceLineCount -Maximum).Maximum
$expectedDirectCompositionCount = @($batch.cases | Where-Object {
    $_.sourceConstructCounts -and
    $_.sourceConstructCounts.valtypeRaiseArrayComposition -gt 0
}).Count
$expectedBothProbeTraceCount = @($batch.cases | Where-Object {
    $_.referencePathKinds -contains 'valtype-raise-probe' -and
    $_.referencePathKinds -contains 'valtype-enum-array-probe'
}).Count
$expectedDisjunctionCount = @($batch.cases | Where-Object {
    $_.sourceConstructCounts -and $_.sourceConstructCounts.or -gt 0
}).Count
$expectedConjunctionCount = @($batch.cases | Where-Object {
    $_.sourceConstructCounts -and $_.sourceConstructCounts.and -gt 0
}).Count
$expectedArrayGrowthCount = @($batch.cases | Where-Object {
    $_.sourceConstructCounts -and $_.sourceConstructCounts.arrayGrow -gt 0
}).Count
$expectedArrayAliasUpdateCount = @($batch.cases | Where-Object {
    $_.sourceConstructCounts -and $_.sourceConstructCounts.arrayAliasUpdate -gt 0
}).Count
$expectedForIterationCount = @($batch.cases | Where-Object {
    $_.referencePathKinds -contains 'for-iteration'
}).Count
$expectedAndRhsExecutedCases = @($batch.cases | Where-Object {
    $_.referencePathKinds -contains 'and-rhs-executed'
}).Count
$expectedAndRhsSkippedCases = @($batch.cases | Where-Object {
    $_.referencePathKinds -contains 'and-rhs-skipped'
}).Count
if ($LASTEXITCODE -ne 0 -or $batch.count -ne 2 -or
    $batch.unexpectedCount -ne 0 -or $batch.uniqueProgramBodies -ne 2 -or
    $batch.schemaVersion -lt 11 -or $batch.casesWithChoiceMatch -lt 1 -or
    $batch.targetParityPassCount -ne $batch.count -or
    @($batch.cases | Where-Object { $_.targetParity.status -ne 'pass' }).Count -ne 0 -or
    $batch.casesWithForLoop -lt 1 -or
    $batch.casesWithForIteration -ne $expectedForIterationCount -or
    $batch.casesWithWhileLoop -lt 1 -or $batch.casesWithWhileIteration -lt 1 -or
    $batch.casesWithArrayGrow -ne $expectedArrayGrowthCount -or
    $batch.casesWithArrayAliasUpdate -ne $expectedArrayAliasUpdateCount -or
    $batch.casesWithValtypeRaiseProbe -lt 1 -or
    $batch.casesWithDirectValtypeRaiseArrayComposition -ne $expectedDirectCompositionCount -or
    $batch.casesVisitingBothValtypeProbeKinds -ne $expectedBothProbeTraceCount -or
    $batch.casesWithAnd -ne $expectedConjunctionCount -or
    [int]$batch.referencePathCaseCounts.'and-rhs-executed' -ne $expectedAndRhsExecutedCases -or
    [int]$batch.referencePathCaseCounts.'and-rhs-skipped' -ne $expectedAndRhsSkippedCases -or
    $batch.casesWithOr -ne $expectedDisjunctionCount -or
    $batch.casesWithSourceLineCount -ne $batch.count -or
    $batch.sourceLineCountMaximum -ne $expectedSourceLineMaximum -or
    @($batch.cases | Where-Object { $null -eq $_.sourceLineCount }).Count -ne 0 -or
    $batch.referencePathCaseCounts.'valtype-raise-success-path' -lt 1 -or
    $batch.referencePathCaseCounts.'valtype-raise-error-path' -lt 1) {
    throw 'fuzz did not return a clean two-seed batch.'
}

$choiceFunctionBatch = (& $cli fuzz -SeedStart 14990 -Count 1 -Depth 4 | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or
    $choiceFunctionBatch.schemaVersion -ne 11 -or
    $choiceFunctionBatch.cases[0].targetParity.status -ne 'pass' -or
    $choiceFunctionBatch.casesWithChoiceReturningFunction -ne 1 -or
    $choiceFunctionBatch.choiceReturningFunctionCount -lt 1 -or
    $choiceFunctionBatch.cases[0].sourceConstructCounts.functionChoice -lt 1) {
    throw 'fuzz did not report the generated Choice-returning local function.'
}

$disjunctionBatch = (& $cli fuzz -SeedStart 353 -Count 1 -Depth 4 | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or
    $disjunctionBatch.schemaVersion -ne 11 -or
    $disjunctionBatch.cases[0].targetParity.status -ne 'pass' -or
    $disjunctionBatch.casesWithOr -ne 1 -or
    $disjunctionBatch.cases[0].sourceConstructCounts.or -lt 1) {
    throw 'fuzz did not report the generated short-circuit disjunction.'
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

# Alias-update guards enlarged seed 8164 past the limit; keep a separate
# generated case that remains below it so both sides of the bound are tested.
$nearLimitRaw = & $verify -Seed 8165 -Depth 10 -Targets @('wasm') -NoPersist
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
if ($injected.finding -ne 'output-mismatch' -or -not $injected.savedTo -or
    $injected.schemaVersion -ne 7 -or
    $injected.targetParity.status -ne 'divergent') {
    throw 'Failed to prepare the explicitly injected replay fixture.'
}

$unreferencedInjected = (& $verify -Seed 0 -Depth 3 `
    -SourcePath $boundary.casePath -Targets @('js', 'wasm') `
    -InjectOutputMismatchTarget wasm | ConvertFrom-Json)
if ($unreferencedInjected.finding -ne 'output-mismatch' -or
    $unreferencedInjected.referenceChecked -or
    -not $unreferencedInjected.savedTo) {
    throw 'Failed to prepare an unreferenced output-mismatch replay fixture.'
}
$unreferencedReplay = (& $cli replay -CasePath $unreferencedInjected.savedTo |
    ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or -not $unreferencedReplay.reproduced) {
    throw 'replay did not preserve the original no-reference classification.'
}

$emptyReferenceInjected = (& $verify -Seed 0 -Depth 3 `
    -SourcePath $boundary.casePath -Targets @('js', 'wasm') `
    -ExpectedOutput '' | ConvertFrom-Json)
if ($emptyReferenceInjected.finding -ne 'reference-mismatch' -or
    -not $emptyReferenceInjected.referenceChecked -or
    $emptyReferenceInjected.expectedOutput -ne '' -or
    -not $emptyReferenceInjected.savedTo) {
    throw 'Failed to save a finding with an explicitly empty reference output.'
}
$emptyReferenceReplay = (& $cli replay -CasePath $emptyReferenceInjected.savedTo |
    ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or -not $emptyReferenceReplay.reproduced) {
    throw 'replay did not preserve the explicitly empty reference contract.'
}

$replay = (& $cli replay -CasePath $injected.savedTo | ConvertFrom-Json)
$persistedInjectedReport = Get-Content -LiteralPath (Join-Path $injected.savedTo 'report.json') -Raw |
    ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $replay.reproduced -or
    -not $replay.sourceIntegrityChecked -or
    $replay.sourceSha256 -ne $persistedInjectedReport.sourceSha256) {
    throw 'replay did not reproduce the saved injected finding.'
}

$tamperedFixtureRoot = Join-Path ([IO.Path]::GetTempPath()) `
    ('moonsmith-cli-tampered-source-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tamperedFixtureRoot -Force | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $injected.savedTo 'report.json') `
        -Destination (Join-Path $tamperedFixtureRoot 'report.json')
    Copy-Item -LiteralPath (Join-Path $injected.savedTo 'source.mbt') `
        -Destination (Join-Path $tamperedFixtureRoot 'source.mbt')
    [IO.File]::AppendAllText(
        (Join-Path $tamperedFixtureRoot 'source.mbt'),
        "`n// Tampered after the finding was saved.`n",
        [Text.UTF8Encoding]::new($false)
    )
    $tamperingRejected = $false
    try {
        & $cli replay -CasePath $tamperedFixtureRoot | Out-Null
    }
    catch {
        if ($_.Exception.Message -notmatch 'does not match the SHA-256 recorded in report.json') {
            throw
        }
        $tamperingRejected = $true
    }
    if (-not $tamperingRejected) {
        throw 'replay accepted source changed after its finding report was saved.'
    }

    Copy-Item -LiteralPath (Join-Path $injected.savedTo 'source.mbt') `
        -Destination (Join-Path $tamperedFixtureRoot 'source.mbt') -Force
    $legacyReplayReport = Get-Content -LiteralPath (Join-Path $tamperedFixtureRoot 'report.json') -Raw |
        ConvertFrom-Json
    $null = $legacyReplayReport.PSObject.Properties.Remove('sourceSha256')
    $legacyReplayReport | ConvertTo-Json -Depth 10 | Set-Content `
        -LiteralPath (Join-Path $tamperedFixtureRoot 'report.json') -Encoding utf8
    $legacyReplay = (& $cli replay -CasePath $tamperedFixtureRoot | ConvertFrom-Json)
    if ($LASTEXITCODE -ne 0 -or -not $legacyReplay.reproduced -or
        $legacyReplay.sourceIntegrityChecked) {
        throw 'replay did not preserve compatibility with a legacy finding report without a source hash.'
    }
}
finally {
    $resolvedTamperedFixture = [IO.Path]::GetFullPath($tamperedFixtureRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTamperedFixture.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove tampered-source fixture outside the temporary directory: $resolvedTamperedFixture"
    }
    if (Test-Path -LiteralPath $resolvedTamperedFixture) {
        Remove-Item -LiteralPath $resolvedTamperedFixture -Recurse -Force
    }
}

$reportFixtureRoot = Join-Path ([IO.Path]::GetTempPath()) `
    ('moonsmith-cli-report-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $reportFixtureRoot -Force | Out-Null
try {
    Copy-Item -LiteralPath $injected.casePath -Destination (Join-Path $reportFixtureRoot 'source.mbt')
    $injected | ConvertTo-Json -Depth 10 | Set-Content `
        -LiteralPath (Join-Path $reportFixtureRoot 'report.json') -Encoding utf8
    $rendered = (& $cli report -CasePath $reportFixtureRoot -Force | ConvertFrom-Json)
    $reportMarkdown = Get-Content -LiteralPath $rendered.reportPath -Raw
    $reportHtml = Get-Content -LiteralPath $rendered.htmlReportPath -Raw
    if ($LASTEXITCODE -ne 0 -or -not $rendered.reportPath -or
        -not $rendered.htmlReportPath -or
        -not $reportMarkdown.Contains('HARNESS-INJECTED DEMONSTRATION') -or
        -not $reportMarkdown.Contains('## Backend results') -or
        -not $reportMarkdown.Contains('## Target Parity cross-check') -or
        -not $reportMarkdown.Contains('- Status: `divergent`') -or
        -not $reportMarkdown.Contains('wasm-gc / default') -or
        -not $reportMarkdown.Contains('## Reproduce')) {
        throw 'report did not render a clearly labelled Markdown finding.'
    }
    if (-not $reportHtml.StartsWith('<!doctype html>') -or
        -not $reportHtml.Contains('HARNESS-INJECTED DEMONSTRATION') -or
        -not $reportHtml.Contains('<table>') -or
        -not $reportHtml.Contains('<h2>Target Parity cross-check</h2>') -or
        -not $reportHtml.Contains('divergent') -or
        -not $reportHtml.Contains('Source SHA-256') -or
        -not $reportHtml.Contains('Original source') -or
        -not $reportHtml.Contains('&lt;') -or
        $reportHtml.Contains('if i < 0L') -or
        -not $reportHtml.Contains('Replay compares the finding kind') -or
        $reportHtml -match '<script\b|\son[a-z]+\s*=') {
        throw 'report did not render a standalone, escaped HTML case page.'
    }

    $legacyReport = Get-Content -LiteralPath (Join-Path $reportFixtureRoot 'report.json') -Raw |
        ConvertFrom-Json
    $null = $legacyReport.PSObject.Properties.Remove('targetParity')
    $legacyReport.schemaVersion = 6
    $legacyReport | ConvertTo-Json -Depth 10 | Set-Content `
        -LiteralPath (Join-Path $reportFixtureRoot 'report.json') -Encoding utf8
    $legacyRendered = (& $cli report -CasePath $reportFixtureRoot -Force | ConvertFrom-Json)
    $legacyMarkdown = Get-Content -LiteralPath $legacyRendered.reportPath -Raw
    $legacyHtml = Get-Content -LiteralPath $legacyRendered.htmlReportPath -Raw
    if ($LASTEXITCODE -ne 0 -or
        -not $legacyMarkdown.Contains('Status: not recorded') -or
        $legacyMarkdown.Contains('Status: not run') -or
        -not $legacyHtml.Contains('Status: not recorded') -or
        $legacyHtml.Contains('Status: not run')) {
        throw 'legacy saved report did not distinguish absent parity evidence from a skipped comparison.'
    }

    $incompleteReport = $legacyReport | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $incompleteReport.schemaVersion = 7
    $incompleteReport | Add-Member -NotePropertyName targetParity -NotePropertyValue $null
    $incompleteReport | ConvertTo-Json -Depth 10 | Set-Content `
        -LiteralPath (Join-Path $reportFixtureRoot 'report.json') -Encoding utf8
    $incompleteRendered = (& $cli report -CasePath $reportFixtureRoot -Force | ConvertFrom-Json)
    $incompleteMarkdown = Get-Content -LiteralPath $incompleteRendered.reportPath -Raw
    $incompleteHtml = Get-Content -LiteralPath $incompleteRendered.htmlReportPath -Raw
    if ($LASTEXITCODE -ne 0 -or
        -not $incompleteMarkdown.Contains('Status: not run') -or
        $incompleteMarkdown.Contains('Status: not recorded') -or
        -not $incompleteHtml.Contains('Status: not run') -or
        $incompleteHtml.Contains('Status: not recorded')) {
        throw 'current incomplete report did not identify Target Parity as not run.'
    }
}
finally {
    $resolvedFixture = [IO.Path]::GetFullPath($reportFixtureRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedFixture.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove report fixture outside the temporary directory: $resolvedFixture"
    }
    if (Test-Path -LiteralPath $resolvedFixture) {
        Remove-Item -LiteralPath $resolvedFixture -Recurse -Force
    }
}

$demo = (& $cli demo | ConvertFrom-Json)
$demoMarkdown = Get-Content -LiteralPath $demo.reportPath -Raw
$demoHtml = Get-Content -LiteralPath $demo.htmlReportPath -Raw
if ($LASTEXITCODE -ne 0 -or $demo.command -ne 'demo' -or
    $demo.finding -ne 'output-mismatch' -or -not $demo.replayReproduced -or
    $demo.acceptedSteps -lt 1 -or
    $demo.finalComplexity -ge $demo.originalComplexity -or
    -not $demoMarkdown.Contains('HARNESS-INJECTED DEMONSTRATION') -or
    -not $demoMarkdown.Contains('## AST reduction') -or
    -not $demoMarkdown.Contains('### Accepted steps') -or
    -not $demoHtml.Contains('HARNESS-INJECTED DEMONSTRATION') -or
    -not $demoHtml.Contains('<h2>AST reduction</h2>') -or
    -not $demoHtml.Contains('<h3>Accepted steps</h3>') -or
    -not $demoHtml.Contains('rejected attempts are omitted')) {
    throw 'demo did not complete detection, reduction, replay, and reporting.'
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
    reportMarkdownVerified = $reportMarkdown.Contains('## Target Parity cross-check')
    reportHtmlVerified = $reportHtml.Contains('<h2>Target Parity cross-check</h2>')
    legacyReportBoundaryVerified = $legacyMarkdown.Contains('Status: not recorded') -and
        $legacyHtml.Contains('Status: not recorded')
    incompleteReportBoundaryVerified = $incompleteMarkdown.Contains('Status: not run') -and
        $incompleteHtml.Contains('Status: not run')
    demoReportPath = $demo.htmlReportPath
} | ConvertTo-Json -Depth 3
