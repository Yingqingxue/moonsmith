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

$valtypeTargets = @('js', 'wasm', 'wasm-gc')
if ($null -ne (Get-Command cl, clang-cl, gcc, clang, cc -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    # Native debug is reserved for the dedicated #1322 regression check: this
    # probe is expected to hit its known Linux/GCC compile failure there.
    $valtypeTargets += 'native-release'
}

$valtypeRaw = & $reduceScript -Seed 0 -Depth 4 `
    -Targets $valtypeTargets `
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
if ($valtypeTargets -contains 'native-release' -and
    $valtypeResult.targets -notcontains 'native-release') {
    throw 'The valtype reducer did not include native-release in its replay matrix.'
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

$arrayRaw = & $reduceScript -Seed 4 -Depth 3 `
    -Targets @('js', 'wasm', 'wasm-gc') `
    -InjectOutputMismatchTarget 'wasm-gc' `
    -InjectOnlyWhenSourceContains '_ms_valtype_array_run' `
    -MaxAttempts 12
$arrayExitCode = $LASTEXITCODE
$arrayResult = $arrayRaw | ConvertFrom-Json
if ($arrayResult.finding -ne 'output-mismatch' -or
    $arrayResult.acceptedSteps -lt 1 -or
    $arrayResult.finalComplexity -ge $arrayResult.originalComplexity -or
    $arrayResult.injection.sourceTrigger -ne '_ms_valtype_array_run' -or
    $arrayExitCode -ne 1) {
    throw 'The valtype enum array reduction did not preserve its injected mismatch.'
}
$arrayMinimalPath = Join-Path $arrayResult.outputDirectory 'minimal.mbt'
$arrayMinimalSource = Get-Content -LiteralPath $arrayMinimalPath -Raw -Encoding utf8
foreach ($trigger in @('#valtype', 'Array[MoonSmithEntry]', 'let values : Array[MoonSmithEntry] = []', 'values.push({ id: i, kind: MoonSmithEntryKind::Ref("x") })', 'values.push({ id: i + 1, kind: MoonSmithEntryKind::Ref("x") })', 'match values[0].kind', 'values[1].id', '_ms_valtype_array_run')) {
    if (-not $arrayMinimalSource.Contains($trigger)) {
        throw "The valtype enum array reduction lost required trigger fragment: $trigger"
    }
}

$combinedTargets = @('js', 'wasm', 'wasm-gc')
if ($null -ne (Get-Command cl, clang-cl, gcc, clang, cc -ErrorAction SilentlyContinue | Select-Object -First 1)) {
    # Keep this injected output-mismatch reduction isolated from the known
    # #1322 native-debug compile failure; native-release remains a control.
    $combinedTargets += 'native-release'
}
$combinedRaw = & $reduceScript -Seed 44607 -Depth 4 `
    -Targets $combinedTargets `
    -InjectOutputMismatchTarget 'wasm-gc' `
    -InjectOnlyWhenSourceContains 'let _ms_valtype_input = _ms_valtype_array_run(' `
    -MaxAttempts 20
$combinedExitCode = $LASTEXITCODE
$combinedResult = $combinedRaw | ConvertFrom-Json
if ($combinedResult.finding -ne 'output-mismatch' -or
    $combinedResult.acceptedSteps -lt 1 -or
    $combinedResult.finalComplexity -ge $combinedResult.originalComplexity -or
    $combinedResult.injection.sourceTrigger -ne 'let _ms_valtype_input = _ms_valtype_array_run(' -or
    $combinedExitCode -ne 1) {
    throw 'The combined valtype probe reduction did not preserve its injected mismatch.'
}
if ($combinedTargets -contains 'native-release' -and
    $combinedResult.targets -notcontains 'native-release') {
    throw 'The combined valtype reducer did not include native-release in its replay matrix.'
}
$combinedMinimalPath = Join-Path $combinedResult.outputDirectory 'minimal.mbt'
$combinedMinimalSource = Get-Content -LiteralPath $combinedMinimalPath -Raw -Encoding utf8
foreach ($trigger in @('let _ms_valtype_input = _ms_valtype_array_run(', '#valtype', 'Array[MoonSmithEntry]', 'let values : Array[MoonSmithEntry] = []', 'values.push({ id: i, kind: MoonSmithEntryKind::Ref("x") })', 'values.push({ id: i + 1, kind: MoonSmithEntryKind::Ref("x") })', 'values[1].id', 'try? _ms_valtype_make', '_ms_valtype_run')) {
    if (-not $combinedMinimalSource.Contains($trigger)) {
        throw "The combined valtype reduction lost required trigger fragment: $trigger"
    }
}

$orRaw = & $reduceScript -Seed 353 -Depth 4 `
    -Targets @('js', 'wasm', 'wasm-gc') `
    -InjectOutputMismatchTarget 'wasm-gc' `
    -InjectOnlyWhenSourceContains ' || ' `
    -MaxAttempts 10
$orExitCode = $LASTEXITCODE
$orResult = $orRaw | ConvertFrom-Json
if ($orResult.finding -ne 'output-mismatch' -or
    $orResult.acceptedSteps -lt 1 -or
    $orResult.finalComplexity -ge $orResult.originalComplexity -or
    $orResult.injection.sourceTrigger -ne ' || ' -or
    $orExitCode -ne 1) {
    throw 'The generated short-circuit disjunction did not retain a reducible injected mismatch.'
}
$orMinimalPath = Join-Path $orResult.outputDirectory 'minimal.mbt'
$orMinimalSource = Get-Content -LiteralPath $orMinimalPath -Raw -Encoding utf8
if (-not $orMinimalSource.Contains(' || ')) {
    throw 'The short-circuit disjunction reduction lost its trigger syntax.'
}

$whileRaw = & $reduceScript -Seed 1 -Depth 3 `
    -Targets @('js', 'wasm', 'wasm-gc') `
    -InjectOutputMismatchTarget 'wasm-gc' `
    -InjectOnlyWhenSourceContains 'while _ms_index <' `
    -MaxAttempts 12
$whileExitCode = $LASTEXITCODE
$whileResult = $whileRaw | ConvertFrom-Json
if ($whileResult.finding -ne 'output-mismatch' -or
    $whileResult.acceptedSteps -lt 1 -or
    $whileResult.finalComplexity -ge $whileResult.originalComplexity -or
    $whileResult.injection.sourceTrigger -ne 'while _ms_index <' -or
    $whileExitCode -ne 1) {
    throw 'The bounded while-loop reduction did not retain a smaller, reproducible injected mismatch.'
}
$whileMinimalPath = Join-Path $whileResult.outputDirectory 'minimal.mbt'
if (-not (Test-Path -LiteralPath $whileMinimalPath -PathType Leaf) -or
    -not (Get-Content -LiteralPath $whileMinimalPath -Raw -Encoding utf8).Contains('while _ms_index <')) {
    throw 'The bounded while-loop reduction lost its trigger syntax.'
}

$growthRaw = & $reduceScript -Seed 1 -Depth 3 `
    -Targets @('js', 'wasm', 'wasm-gc') `
    -InjectOutputMismatchTarget 'wasm-gc' `
    -InjectOnlyWhenSourceContains 'grown_items.push' `
    -MaxAttempts 12
$growthExitCode = $LASTEXITCODE
$growthResult = $growthRaw | ConvertFrom-Json
if ($growthResult.finding -ne 'output-mismatch' -or
    $growthResult.acceptedSteps -lt 1 -or
    $growthResult.finalComplexity -ge $growthResult.originalComplexity -or
    $growthResult.injection.sourceTrigger -ne 'grown_items.push' -or
    $growthExitCode -ne 1) {
    throw 'The primitive-array-growth reduction did not retain a smaller, reproducible injected mismatch.'
}
$growthMinimalPath = Join-Path $growthResult.outputDirectory 'minimal.mbt'
if (-not (Test-Path -LiteralPath $growthMinimalPath -PathType Leaf)) {
    throw 'The primitive-array-growth reduction did not save minimal source.'
}
$growthMinimalSource = Get-Content -LiteralPath $growthMinimalPath -Raw -Encoding utf8
foreach ($trigger in @('let grown_items : Array[Bool] = []', 'grown_items.push(', 'grown_items[0]')) {
    if (-not $growthMinimalSource.Contains($trigger)) {
        throw "The primitive-array-growth reduction lost trigger fragment: $trigger"
    }
}

$aliasRaw = & $reduceScript -Seed 1 -Depth 3 `
    -Targets @('js', 'wasm', 'wasm-gc') `
    -InjectOutputMismatchTarget 'wasm-gc' `
    -InjectOnlyWhenSourceContains 'let _ms_alias = items' `
    -MaxAttempts 12
$aliasExitCode = $LASTEXITCODE
$aliasResult = $aliasRaw | ConvertFrom-Json
if ($aliasResult.finding -ne 'output-mismatch' -or
    $aliasResult.acceptedSteps -lt 1 -or
    $aliasResult.finalComplexity -ge $aliasResult.originalComplexity -or
    $aliasResult.injection.sourceTrigger -ne 'let _ms_alias = items' -or
    $aliasExitCode -ne 1) {
    throw 'The array-alias-update reduction did not retain a smaller, reproducible injected mismatch.'
}
$aliasMinimalPath = Join-Path $aliasResult.outputDirectory 'minimal.mbt'
if (-not (Test-Path -LiteralPath $aliasMinimalPath -PathType Leaf)) {
    throw 'The array-alias-update reduction did not save minimal source.'
}
$aliasMinimalSource = Get-Content -LiteralPath $aliasMinimalPath -Raw -Encoding utf8
if (-not $aliasMinimalSource.Contains('let _ms_alias = items')) {
    throw 'The array-alias-update reduction lost the alias binding.'
}
$aliasAssignment = [regex]::Match($aliasMinimalSource, '_ms_alias\[([01])\] = replacement')
if (-not $aliasAssignment.Success -or
    -not $aliasMinimalSource.Contains("items[$($aliasAssignment.Groups[1].Value)] == replacement")) {
    throw 'The array-alias-update reduction lost the observable write/read pair.'
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
    valtypeTargets = $valtypeResult.targets
    valtypeMinimalPath = $valtypeMinimalPath
    arrayOriginalComplexity = $arrayResult.originalComplexity
    arrayFinalComplexity = $arrayResult.finalComplexity
    arrayAcceptedSteps = $arrayResult.acceptedSteps
    arrayMinimalPath = $arrayMinimalPath
    combinedOriginalComplexity = $combinedResult.originalComplexity
    combinedFinalComplexity = $combinedResult.finalComplexity
    combinedAcceptedSteps = $combinedResult.acceptedSteps
    combinedTargets = $combinedResult.targets
    combinedMinimalPath = $combinedMinimalPath
    disjunctionOriginalComplexity = $orResult.originalComplexity
    disjunctionFinalComplexity = $orResult.finalComplexity
    disjunctionAcceptedSteps = $orResult.acceptedSteps
    disjunctionAttempts = $orResult.attempts
    disjunctionMinimalPath = $orMinimalPath
    whileOriginalComplexity = $whileResult.originalComplexity
    whileFinalComplexity = $whileResult.finalComplexity
    whileAcceptedSteps = $whileResult.acceptedSteps
    whileMinimalPath = $whileMinimalPath
    growthOriginalComplexity = $growthResult.originalComplexity
    growthFinalComplexity = $growthResult.finalComplexity
    growthAcceptedSteps = $growthResult.acceptedSteps
    growthMinimalPath = $growthMinimalPath
    aliasOriginalComplexity = $aliasResult.originalComplexity
    aliasFinalComplexity = $aliasResult.finalComplexity
    aliasAcceptedSteps = $aliasResult.acceptedSteps
    aliasMinimalPath = $aliasMinimalPath
} | ConvertTo-Json -Depth 3
$global:LASTEXITCODE = 0
