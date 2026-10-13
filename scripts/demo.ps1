$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
$reduceScript = Join-Path $PSScriptRoot 'reduce_case.ps1'
$reportScript = Join-Path $PSScriptRoot 'render_report.ps1'
$cliScript = Join-Path $PSScriptRoot 'moonsmith.ps1'
$demoOptions = @{
    Seed = 0
    Depth = 2
    Targets = @('js', 'wasm', 'wasm-gc')
    InjectOutputMismatchTarget = 'wasm-gc'
    InjectOnlyWhenSourceContains = '(if'
}

$baselineRaw = & $verifyScript @demoOptions -NoPersist
$baseline = $baselineRaw | ConvertFrom-Json
if ($LASTEXITCODE -ne 1 -or $baseline.finding -ne 'output-mismatch' -or
    $baseline.injection.kind -ne 'output-mismatch' -or
    -not $baseline.casePath) {
    throw 'The demonstration did not create the expected injected mismatch.'
}
$originalSource = Get-Content -LiteralPath $baseline.casePath -Raw -Encoding utf8

$reductionRaw = & $reduceScript @demoOptions -MaxAttempts 30
$reduction = $reductionRaw | ConvertFrom-Json
if ($reduction.finding -ne 'output-mismatch' -or
    $reduction.caseId -ne $baseline.caseId -or
    $reduction.originalSignature -ne $baseline.signature -or
    $reduction.acceptedSteps -lt 1 -or
    $reduction.finalComplexity -ge $reduction.originalComplexity -or
    $reduction.attemptBudgetHit) {
    throw 'The demonstration did not produce a verified smaller case.'
}

$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') + '_' +
    [System.Guid]::NewGuid().ToString('N').Substring(0, 8)
$demoDirectory = Join-Path $projectRoot ".moonsmith\demos\$runId"
New-Item -ItemType Directory -Path $demoDirectory | Out-Null
Set-Content -LiteralPath (Join-Path $demoDirectory 'source.mbt') `
    -Value $originalSource -Encoding utf8 -NoNewline
Set-Content -LiteralPath (Join-Path $demoDirectory 'report.json') `
    -Value $baselineRaw -Encoding utf8

$renderedRaw = & $reportScript -CasePath $demoDirectory `
    -ReductionPath $reduction.outputDirectory
$rendered = $renderedRaw | ConvertFrom-Json
if (-not $rendered.includesReduction -or
    -not (Test-Path -LiteralPath $rendered.reportPath -PathType Leaf) -or
    -not (Test-Path -LiteralPath $rendered.htmlReportPath -PathType Leaf)) {
    throw 'The demonstration did not render both case reports with reduction evidence.'
}

$replayRaw = & $cliScript replay -CasePath $demoDirectory
$replay = $replayRaw | ConvertFrom-Json
if ($LASTEXITCODE -ne 0 -or -not $replay.reproduced) {
    throw 'The saved demonstration case did not replay.'
}

[pscustomobject]@{
    command = 'demo'
    evidence = 'HARNESS-INJECTED DEMONSTRATION — not a MoonBit compiler defect'
    caseId = $baseline.caseId
    finding = $baseline.finding
    replayReproduced = $replay.reproduced
    originalComplexity = $reduction.originalComplexity
    finalComplexity = $reduction.finalComplexity
    acceptedSteps = $reduction.acceptedSteps
    caseDirectory = $demoDirectory
    reductionDirectory = $reduction.outputDirectory
    reportPath = $rendered.reportPath
    htmlReportPath = $rendered.htmlReportPath
} | ConvertTo-Json -Depth 4
