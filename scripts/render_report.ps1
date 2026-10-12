param(
    [Parameter(Mandatory)]
    [string]$CasePath,

    [string]$ReductionPath = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$resolved = (Resolve-Path -LiteralPath $CasePath -ErrorAction Stop).Path
$caseDirectory = if (Test-Path -LiteralPath $resolved -PathType Container) {
    $resolved
} else {
    Split-Path -Parent $resolved
}
$jsonPath = Join-Path $caseDirectory 'report.json'
$sourcePath = Join-Path $caseDirectory 'source.mbt'
foreach ($required in @($jsonPath, $sourcePath)) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
        throw "Saved finding is missing $required"
    }
}

$finding = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json
if (-not $finding.caseId -or $finding.finding -eq 'consistent') {
    throw 'The saved report does not describe a non-consistent finding.'
}
$sourceHash = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
if ($finding.sourceSha256 -and $finding.sourceSha256 -ne $sourceHash) {
    throw 'The saved source no longer matches the hash in report.json.'
}
$source = Get-Content -LiteralPath $sourcePath -Raw -Encoding utf8

$reduction = $null
$minimalSource = $null
if ($ReductionPath) {
    $resolvedReduction = (Resolve-Path -LiteralPath $ReductionPath -ErrorAction Stop).Path
    $reductionDirectory = if (Test-Path -LiteralPath $resolvedReduction -PathType Container) {
        $resolvedReduction
    } else {
        Split-Path -Parent $resolvedReduction
    }
    $reductionJsonPath = Join-Path $reductionDirectory 'reduction.json'
    $reductionOriginalPath = Join-Path $reductionDirectory 'original.mbt'
    $minimalPath = Join-Path $reductionDirectory 'minimal.mbt'
    foreach ($required in @($reductionJsonPath, $reductionOriginalPath, $minimalPath)) {
        if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
            throw "Reduction record is missing $required"
        }
    }
    $reduction = Get-Content -LiteralPath $reductionJsonPath -Raw | ConvertFrom-Json
    if ($reduction.caseId -ne $finding.caseId -or
        $reduction.originalSignature -ne $finding.signature) {
        throw 'Reduction record does not match the selected finding.'
    }
    $reductionOriginalHash = (Get-FileHash -LiteralPath $reductionOriginalPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($reductionOriginalHash -ne $sourceHash) {
        throw 'Reduction source differs from the saved canonical finding source.'
    }
    $minimalSource = Get-Content -LiteralPath $minimalPath -Raw -Encoding utf8
}

$outputPath = Join-Path $caseDirectory 'report.md'
if ((Test-Path -LiteralPath $outputPath) -and -not $Force) {
    throw "Report already exists: $outputPath. Pass -Force to replace it."
}
$htmlOutputPath = Join-Path $caseDirectory 'report.html'
if ((Test-Path -LiteralPath $htmlOutputPath) -and -not $Force) {
    throw "Report already exists: $htmlOutputPath. Pass -Force to replace it."
}

$lines = [System.Collections.Generic.List[string]]::new()
function Add-Line([string]$Value = '') {
    $lines.Add($Value)
}
function Add-Fence([string]$Content, [string]$Language = '') {
    $maxTicks = 2
    foreach ($match in [regex]::Matches($Content, '`+')) {
        if ($match.Length -gt $maxTicks) { $maxTicks = $match.Length }
    }
    $fence = '`' * ($maxTicks + 1)
    Add-Line ($fence + $Language)
    Add-Line ($Content.TrimEnd("`r", "`n"))
    Add-Line $fence
}

$evidenceStatus = if ($finding.injection) {
    'HARNESS-INJECTED DEMONSTRATION — not a MoonBit compiler defect.'
} elseif ($finding.finding -eq 'environment-failure') {
    'Environment failure — not evidence of a compiler defect.'
} else {
    'Unconfirmed candidate — manually reproduce and rule out allowed behavior before filing an issue.'
}
$toolchainVersion = if ($finding.toolchainVersion) {
    [string]$finding.toolchainVersion
} else {
    'not recorded in the original report'
}
$hostOS = if ($finding.hostOS) { [string]$finding.hostOS } else { 'not recorded' }
$targetList = @($finding.runs | Select-Object -ExpandProperty target) -join ', '

Add-Line "# MoonSmith case $($finding.caseId)"
Add-Line
Add-Line "> **Evidence status:** $evidenceStatus"
Add-Line
Add-Line '## Summary'
Add-Line
Add-Line "- Finding: ``$($finding.finding)``"
Add-Line "- Seed / depth: ``$($finding.seed)`` / ``$($finding.depth)``"
Add-Line "- Targets: $targetList"
Add-Line "- MoonBit: $toolchainVersion"
Add-Line "- Host OS: $hostOS"
Add-Line "- Per-process timeout: $($finding.timeoutSeconds) s"
Add-Line "- Source SHA-256: ``$sourceHash``"
Add-Line "- Reference checked: $([bool]$finding.referenceChecked)"
Add-Line
Add-Line '## Backend results'
Add-Line
Add-Line '| Target | Backend / mode | Status | Exit code | Duration (ms) |'
Add-Line '|---|---|---|---:|---:|'
foreach ($run in $finding.runs) {
    $backendMode = if ($run.backend -and $run.buildMode) {
        "$($run.backend) / $($run.buildMode)"
    } else {
        'not recorded'
    }
    Add-Line "| $($run.target) | $backendMode | $($run.status) | $($run.exitCode) | $($run.durationMs) |"
}
Add-Line
if ($finding.referenceChecked) {
    Add-Line '## Reference output'
    Add-Line
    Add-Fence ([string]$finding.expectedOutput) 'text'
    Add-Line "Exact JSON string: ``$([string]$finding.expectedOutput | ConvertTo-Json -Compress)``"
    Add-Line
}
Add-Line '## Backend output and diagnostics'
Add-Line
foreach ($run in $finding.runs) {
    Add-Line "### $($run.target)"
    Add-Line
    Add-Line 'Stdout:'
    Add-Fence ([string]$run.output) 'text'
    Add-Line "Exact JSON string: ``$([string]$run.output | ConvertTo-Json -Compress)``"
    Add-Line
    Add-Line 'Stderr / diagnostic:'
    Add-Fence ([string]$run.error) 'text'
    Add-Line
}
Add-Line '## Original source'
Add-Line
Add-Fence $source 'moonbit'
Add-Line
if ($null -ne $reduction) {
    Add-Line '## AST reduction'
    Add-Line
    Add-Line "- Complexity: $($reduction.originalComplexity) → $($reduction.finalComplexity)"
    Add-Line "- Source bytes: $($reduction.originalBytes) → $($reduction.finalBytes)"
    Add-Line "- Accepted steps / attempts: $($reduction.acceptedSteps) / $($reduction.attempts)"
    Add-Line "- Attempt budget hit: $([bool]$reduction.attemptBudgetHit)"
    Add-Line
    Add-Line '### Reduced source'
    Add-Line
    Add-Fence $minimalSource 'moonbit'
    Add-Line
}
Add-Line '## Reproduce'
Add-Line
Add-Line 'From the MoonSmith project root, with the saved case directory present:'
Add-Line
$relativeCase = [System.IO.Path]::GetRelativePath($projectRoot, $caseDirectory)
$caseArgument = if ($relativeCase.StartsWith('..')) { $caseDirectory } else { $relativeCase }
$caseArgument = $caseArgument.Replace("'", "''")
Add-Fence "pwsh -File scripts/moonsmith.ps1 replay -CasePath '$caseArgument'" 'powershell'
Add-Line
Add-Line 'A replay compares the finding kind and reduction key. The same result may still require human investigation; cross-backend agreement alone does not prove semantic correctness.'

Set-Content -LiteralPath $outputPath -Value ($lines -join "`n") -Encoding utf8

function ConvertTo-HtmlText([AllowNull()][object]$Value) {
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

$html = [System.Collections.Generic.List[string]]::new()
$html.Add('<!doctype html>')
$html.Add('<html lang="en">')
$html.Add('<head>')
$html.Add('<meta charset="utf-8">')
$html.Add('<meta name="viewport" content="width=device-width, initial-scale=1">')
$html.Add("<title>MoonSmith case $(ConvertTo-HtmlText $finding.caseId)</title>")
$html.Add('<style>')
$html.Add(':root{color-scheme:light dark;font:16px/1.55 system-ui,sans-serif}body{max-width:1000px;margin:0 auto;padding:2rem;color:CanvasText;background:Canvas}h1,h2{line-height:1.2}section,header{margin:1.5rem 0;padding:1rem;border:1px solid color-mix(in srgb,CanvasText 22%,transparent);border-radius:.6rem}header{border-left:.35rem solid #39875b}table{width:100%;border-collapse:collapse;display:block;overflow-x:auto}th,td{text-align:left;padding:.55rem;border-bottom:1px solid color-mix(in srgb,CanvasText 20%,transparent);white-space:nowrap}pre{white-space:pre-wrap;overflow-wrap:anywhere;padding:1rem;background:color-mix(in srgb,CanvasText 7%,Canvas);border-radius:.4rem}code{overflow-wrap:anywhere}.muted{opacity:.8}.status{font-weight:700}')
$html.Add('</style>')
$html.Add('</head>')
$html.Add('<body>')
$html.Add("<header><h1>MoonSmith case $(ConvertTo-HtmlText $finding.caseId)</h1><p class='status'>$(ConvertTo-HtmlText $evidenceStatus)</p></header>")
$html.Add('<main>')
$html.Add('<section><h2>Summary</h2><dl>')
$html.Add("<dt>Finding</dt><dd><code>$(ConvertTo-HtmlText $finding.finding)</code></dd>")
$html.Add("<dt>Seed / depth</dt><dd>$(ConvertTo-HtmlText $finding.seed) / $(ConvertTo-HtmlText $finding.depth)</dd>")
$html.Add("<dt>Targets</dt><dd>$(ConvertTo-HtmlText $targetList)</dd>")
$html.Add("<dt>MoonBit</dt><dd>$(ConvertTo-HtmlText $toolchainVersion)</dd>")
$html.Add("<dt>Host OS</dt><dd>$(ConvertTo-HtmlText $hostOS)</dd>")
$html.Add("<dt>Per-process timeout</dt><dd>$(ConvertTo-HtmlText $finding.timeoutSeconds) s</dd>")
$html.Add("<dt>Source SHA-256</dt><dd><code>$(ConvertTo-HtmlText $sourceHash)</code></dd>")
$html.Add("<dt>Reference checked</dt><dd>$(ConvertTo-HtmlText ([bool]$finding.referenceChecked))</dd>")
$html.Add('</dl></section>')
$html.Add('<section><h2>Backend results</h2><table><thead><tr><th>Target</th><th>Backend / mode</th><th>Status</th><th>Exit code</th><th>Duration (ms)</th></tr></thead><tbody>')
foreach ($run in $finding.runs) {
    $backendMode = if ($run.backend -and $run.buildMode) { "$($run.backend) / $($run.buildMode)" } else { 'not recorded' }
    $html.Add("<tr><td>$(ConvertTo-HtmlText $run.target)</td><td>$(ConvertTo-HtmlText $backendMode)</td><td>$(ConvertTo-HtmlText $run.status)</td><td>$(ConvertTo-HtmlText $run.exitCode)</td><td>$(ConvertTo-HtmlText $run.durationMs)</td></tr>")
}
$html.Add('</tbody></table></section>')
if ($finding.referenceChecked) {
    $html.Add("<section><h2>Reference output</h2><pre>$(ConvertTo-HtmlText $finding.expectedOutput)</pre></section>")
}
$html.Add('<section><h2>Backend output and diagnostics</h2>')
foreach ($run in $finding.runs) {
    $html.Add("<h3>$(ConvertTo-HtmlText $run.target)</h3><h4>Stdout</h4><pre>$(ConvertTo-HtmlText $run.output)</pre><h4>Stderr / diagnostic</h4><pre>$(ConvertTo-HtmlText $run.error)</pre>")
}
$html.Add('</section>')
$html.Add("<section><h2>Original source</h2><pre><code>$(ConvertTo-HtmlText $source)</code></pre></section>")
if ($null -ne $reduction) {
    $html.Add("<section><h2>AST reduction</h2><p>Complexity: $(ConvertTo-HtmlText $reduction.originalComplexity) → $(ConvertTo-HtmlText $reduction.finalComplexity)</p><p>Source bytes: $(ConvertTo-HtmlText $reduction.originalBytes) → $(ConvertTo-HtmlText $reduction.finalBytes)</p><p>Accepted steps / attempts: $(ConvertTo-HtmlText $reduction.acceptedSteps) / $(ConvertTo-HtmlText $reduction.attempts)</p><p>Attempt budget hit: $(ConvertTo-HtmlText ([bool]$reduction.attemptBudgetHit))</p><h3>Reduced source</h3><pre><code>$(ConvertTo-HtmlText $minimalSource)</code></pre></section>")
}
$html.Add('<section><h2>Reproduce</h2><p>From the MoonSmith project root, with the saved case directory present:</p>')
$html.Add("<pre><code>pwsh -File scripts/moonsmith.ps1 replay -CasePath '$(ConvertTo-HtmlText $caseArgument)'</code></pre>")
$html.Add('<p class="muted">Replay compares the finding kind and reduction key. A matching result still requires human investigation; cross-backend agreement alone does not prove semantic correctness.</p></section>')
$html.Add('</main></body></html>')
Set-Content -LiteralPath $htmlOutputPath -Value ($html -join "`n") -Encoding utf8
[pscustomobject]@{
    caseId = $finding.caseId
    reportPath = $outputPath
    htmlReportPath = $htmlOutputPath
    evidenceStatus = $evidenceStatus
    includesReduction = $null -ne $reduction
    sourceSha256 = $sourceHash
} | ConvertTo-Json -Depth 3
