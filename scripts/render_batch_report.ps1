param(
    [Parameter(Mandatory)]
    [string]$BatchPath,

    [string]$OutputPath = '',

    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$resolved = (Resolve-Path -LiteralPath $BatchPath -ErrorAction Stop).Path
if (Test-Path -LiteralPath $resolved -PathType Container) {
    $batchFile = Get-ChildItem -LiteralPath $resolved -Filter 'batch_*.json' -File |
        Sort-Object -Property LastWriteTimeUtc -Descending |
        Select-Object -First 1
    if ($null -eq $batchFile) { throw "No batch_*.json report exists in $resolved" }
    $resolved = $batchFile.FullName
}
if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
    throw "Batch report is not a file: $resolved"
}

$summary = Get-Content -LiteralPath $resolved -Raw | ConvertFrom-Json
if ($summary.schemaVersion -notin @(7, 8, 9)) {
    throw "Unsupported batch report schemaVersion '$($summary.schemaVersion)'."
}
if ($summary.cases.Count -ne $summary.count) {
    throw "Batch report declares $($summary.count) cases but contains $($summary.cases.Count)."
}

if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($resolved, '.html')
} else {
    $parent = Split-Path -Parent $OutputPath
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "Output directory does not exist: $parent"
    }
}
$resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
if ([string]::Equals($resolved, $resolvedOutput, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'Refusing to replace the source batch JSON with its HTML rendering.'
}
if ((Test-Path -LiteralPath $OutputPath) -and -not $Force) {
    throw "Batch HTML report already exists: $OutputPath. Pass -Force to replace it."
}

function ConvertTo-HtmlText([AllowNull()][object]$Value) {
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

$statusText = if ($summary.unexpectedCount -eq 0 -and -not $summary.harnessChangedDuringRun) {
    'No unexpected findings in this bounded batch.'
} else {
    'Review required: this batch contains unexpected findings or a changed harness.'
}
$statusClass = if ($summary.unexpectedCount -eq 0 -and -not $summary.harnessChangedDuringRun) {
    'ok'
} else {
    'problem'
}
$targets = @($summary.targets) -join ', '
$rangeEnd = [long]$summary.seedStart + [long]$summary.count - 1
$html = [System.Collections.Generic.List[string]]::new()
$html.Add('<!doctype html>')
$html.Add('<html lang="en"><head><meta charset="utf-8">')
$html.Add('<meta name="viewport" content="width=device-width, initial-scale=1">')
$html.Add("<title>MoonSmith batch $(ConvertTo-HtmlText $summary.seedStart)–$(ConvertTo-HtmlText $rangeEnd)</title>")
$html.Add('<style>')
$html.Add(':root{color-scheme:light dark;font:16px/1.5 system-ui,sans-serif}body{max-width:1200px;margin:auto;padding:1.5rem;color:CanvasText;background:Canvas}header,section{margin:1rem 0;padding:1rem;border:1px solid color-mix(in srgb,CanvasText 22%,transparent);border-radius:.6rem}header{border-left:.35rem solid #39875b}.problem{border-left-color:#bc3434}.ok{border-left-color:#39875b}.cards{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:.65rem}.card{padding:.75rem;border:1px solid color-mix(in srgb,CanvasText 20%,transparent);border-radius:.4rem}.label{display:block;font-size:.85rem;opacity:.75}.value{font-size:1.15rem;font-weight:650;overflow-wrap:anywhere}table{width:100%;border-collapse:collapse;display:block;overflow-x:auto}caption{text-align:left;font-weight:650;padding:.5rem}th,td{text-align:left;vertical-align:top;padding:.45rem;border-bottom:1px solid color-mix(in srgb,CanvasText 18%,transparent)}th{white-space:nowrap}code{overflow-wrap:anywhere}pre{white-space:pre-wrap;overflow-wrap:anywhere;margin:0}tbody tr:nth-child(even){background:color-mix(in srgb,CanvasText 4%,Canvas)}')
$html.Add('</style></head><body>')
$html.Add("<header class='$statusClass'><h1>MoonSmith batch report</h1><p>$(ConvertTo-HtmlText $statusText)</p></header>")
$html.Add('<main><section><h2>Run summary</h2><div class="cards">')
$summaryCards = @(
    @{ label = 'Seeds'; value = "$(ConvertTo-HtmlText $summary.seedStart)–$(ConvertTo-HtmlText $rangeEnd)" },
    @{ label = 'Depth'; value = (ConvertTo-HtmlText $summary.depth) },
    @{ label = 'Targets'; value = (ConvertTo-HtmlText $targets) },
    @{ label = 'Cases'; value = (ConvertTo-HtmlText $summary.count) },
    @{ label = 'Unique program bodies'; value = (ConvertTo-HtmlText $summary.uniqueProgramBodies) },
    @{ label = 'Reference checked'; value = (ConvertTo-HtmlText $summary.referenceCheckedCount) },
    @{ label = 'Unexpected'; value = (ConvertTo-HtmlText $summary.unexpectedCount) },
    @{ label = 'Duration'; value = "$(ConvertTo-HtmlText $summary.durationMs) ms" },
    @{ label = 'MoonBit'; value = (ConvertTo-HtmlText $summary.toolchainVersion) }
)
foreach ($card in $summaryCards) {
    $html.Add("<div class='card'><span class='label'>$($card.label)</span><span class='value'>$($card.value)</span></div>")
}
$html.Add('</div></section>')

$html.Add('<section><h2>Findings</h2><table><caption>Cases per finding classification</caption><thead><tr><th scope="col">Finding</th><th scope="col">Count</th></tr></thead><tbody>')
foreach ($property in $summary.counts.PSObject.Properties | Sort-Object -Property Name) {
    $html.Add("<tr><td><code>$(ConvertTo-HtmlText $property.Name)</code></td><td>$(ConvertTo-HtmlText $property.Value)</td></tr>")
}
$html.Add('</tbody></table></section>')

$sourceCoverageProperties = @($summary.PSObject.Properties |
    Where-Object { $_.Name -match '^casesWith' } |
    Sort-Object -Property Name)
$traceCoverageProperties = @($summary.PSObject.Properties |
    Where-Object { $_.Name -match '^casesVisiting' } |
    Sort-Object -Property Name)
$referencePathProperty = $summary.PSObject.Properties['referencePathCaseCounts']
if ($sourceCoverageProperties.Count -gt 0 -or $traceCoverageProperties.Count -gt 0 -or
    ($null -ne $referencePathProperty -and $null -ne $referencePathProperty.Value)) {
    $html.Add('<section><h2>Generator and reference coverage</h2>')
}
if ($sourceCoverageProperties.Count -gt 0) {
    $html.Add('<table><caption>Generated source coverage</caption><thead><tr><th scope="col">Feature or property</th><th scope="col">Cases</th><th scope="col">Share of batch</th></tr></thead><tbody>')
    foreach ($property in $sourceCoverageProperties) {
        $caseCount = [long]$property.Value
        $share = if ([long]$summary.count -gt 0) {
            '{0:P1}' -f ($caseCount / [double]$summary.count)
        } else { 'n/a' }
        $html.Add("<tr><td><code>$(ConvertTo-HtmlText $property.Name)</code></td><td>$(ConvertTo-HtmlText $caseCount)</td><td>$(ConvertTo-HtmlText $share)</td></tr>")
    }
    $html.Add('</tbody></table>')
}
if ($traceCoverageProperties.Count -gt 0) {
    $html.Add('<table><caption>Reference trace coverage</caption><thead><tr><th scope="col">Path group</th><th scope="col">Cases</th><th scope="col">Share of batch</th></tr></thead><tbody>')
    foreach ($property in $traceCoverageProperties) {
        $caseCount = [long]$property.Value
        $share = if ([long]$summary.count -gt 0) {
            '{0:P1}' -f ($caseCount / [double]$summary.count)
        } else { 'n/a' }
        $html.Add("<tr><td><code>$(ConvertTo-HtmlText $property.Name)</code></td><td>$(ConvertTo-HtmlText $caseCount)</td><td>$(ConvertTo-HtmlText $share)</td></tr>")
    }
    $html.Add('</tbody></table>')
}
if ($null -ne $referencePathProperty -and $null -ne $referencePathProperty.Value) {
    $html.Add('<table><caption>Reference interpreter path counts (not backend runtime instrumentation)</caption><thead><tr><th scope="col">Path</th><th scope="col">Visits</th></tr></thead><tbody>')
    foreach ($property in $referencePathProperty.Value.PSObject.Properties | Sort-Object -Property Name) {
        $html.Add("<tr><td><code>$(ConvertTo-HtmlText $property.Name)</code></td><td>$(ConvertTo-HtmlText $property.Value)</td></tr>")
    }
    $html.Add('</tbody></table>')
}
if ($sourceCoverageProperties.Count -gt 0 -or $traceCoverageProperties.Count -gt 0 -or
    ($null -ne $referencePathProperty -and $null -ne $referencePathProperty.Value)) {
    if ($null -eq $referencePathProperty -or $null -eq $referencePathProperty.Value) {
        $html.Add('<p>Reference-path counts were not recorded in this batch.</p>')
    }
    $html.Add('</section>')
}

$clustersProperty = $summary.PSObject.Properties['failureClusters']
$clusters = if ($null -ne $clustersProperty -and $null -ne $clustersProperty.Value) {
    @($clustersProperty.Value)
} else {
    @()
}
$html.Add('<section><h2>Failure clusters</h2>')
if ($null -eq $clustersProperty) {
    $html.Add('<p>Failure-cluster data was not recorded in this batch schema.</p>')
} elseif ($clusters.Count -eq 0) {
    $html.Add('<p>No signed non-consistent cases were clustered in this batch.</p>')
} else {
    $html.Add('<table><caption>Grouped by finding classification and stable signature</caption><thead><tr><th scope="col">Finding</th><th scope="col">Signature</th><th scope="col">Cases</th><th scope="col">Seeds</th><th scope="col">Representative case</th></tr></thead><tbody>')
    foreach ($cluster in $clusters) {
        $seedList = @($cluster.seeds) -join ', '
        $html.Add("<tr><td>$(ConvertTo-HtmlText $cluster.finding)</td><td><code>$(ConvertTo-HtmlText $cluster.signature)</code></td><td>$(ConvertTo-HtmlText $cluster.count)</td><td>$(ConvertTo-HtmlText $seedList)</td><td>$(ConvertTo-HtmlText $cluster.representativeCaseId)</td></tr>")
    }
    $html.Add('</tbody></table>')
}
$html.Add('</section>')

$html.Add('<section><h2>Per-seed results</h2><table><caption>One row per requested seed</caption><thead><tr><th scope="col">Seed</th><th scope="col">Finding</th><th scope="col">Case ID</th><th scope="col">Program body SHA-256</th><th scope="col">Reference checked</th><th scope="col">Expected output</th><th scope="col">Duration (ms)</th><th scope="col">Error</th></tr></thead><tbody>')
foreach ($case in $summary.cases) {
    $html.Add("<tr><td>$(ConvertTo-HtmlText $case.seed)</td><td>$(ConvertTo-HtmlText $case.finding)</td><td><code>$(ConvertTo-HtmlText $case.caseId)</code></td><td><code>$(ConvertTo-HtmlText $case.bodySha256)</code></td><td>$(ConvertTo-HtmlText $case.referenceChecked)</td><td><code>$(ConvertTo-HtmlText $case.expectedOutput)</code></td><td>$(ConvertTo-HtmlText $case.durationMs)</td><td><pre>$(ConvertTo-HtmlText $case.error)</pre></td></tr>")
}
$html.Add('</tbody></table></section>')
$html.Add("<footer><p>Harness stable during run: $(ConvertTo-HtmlText ([bool](-not $summary.harnessChangedDuringRun))). Reference checks are generated by MoonSmith's interpreter; they are not backend runtime instrumentation.</p></footer>")
$html.Add('</main></body></html>')

Set-Content -LiteralPath $OutputPath -Value ($html -join "`n") -Encoding utf8
[pscustomobject]@{
    batchPath = $resolved
    htmlReportPath = $OutputPath
    count = $summary.count
    failureClusters = $clusters.Count
} | ConvertTo-Json -Depth 3
