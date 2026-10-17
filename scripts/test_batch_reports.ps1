$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'compare_batch_reports.ps1'
$cliPath = Join-Path $PSScriptRoot 'moonsmith.ps1'
. (Join-Path $PSScriptRoot 'failure_clusters.ps1')
$tempDirectory = [IO.Path]::GetTempPath()
$testRoot = Join-Path $tempDirectory ('moonsmith-batch-report-test-' + [guid]::NewGuid().ToString('N'))
$linuxDirectory = Join-Path $testRoot 'linux'
$windowsDirectory = Join-Path $testRoot 'windows'
New-Item -ItemType Directory -Path $linuxDirectory, $windowsDirectory -Force | Out-Null

function New-TestReport {
    param(
        [int]$SeedStart,
        [string[]]$Targets,
        [string]$Finding = 'consistent',
        [string]$FirstHash = ('a' * 64),
        [string]$FirstExpectedOutput = '<img src=x onerror=alert(1)>',
        [string]$ToolchainVersion = 'moon <script>alert(1)</script>'
    )

    $cases = @(
        [ordered]@{
            seed = $SeedStart
            caseId = "case-$SeedStart"
            bodySha256 = $FirstHash
            finding = $Finding
            expectedOutput = $FirstExpectedOutput
            error = '<img src=x onerror=alert(1)>'
            referenceChecked = $true
            targetParity = [ordered]@{ status = 'pass' }
            sourceConstructCounts = [ordered]@{ functionChoice = 1; and = 1; or = 1 }
        },
        [ordered]@{
            seed = $SeedStart + 1
            caseId = "case-$($SeedStart + 1)"
            bodySha256 = ('b' * 64)
            finding = 'consistent'
            expectedOutput = "43`n"
            error = ''
            referenceChecked = $true
            targetParity = [ordered]@{ status = 'pass' }
            sourceConstructCounts = [ordered]@{ functionChoice = 0; and = 0; or = 0 }
        }
    )
    [ordered]@{
        schemaVersion = 11
        seedStart = $SeedStart
        count = 2
        depth = 4
        targets = $Targets
        toolchainVersion = $ToolchainVersion
        harnessDigestStart = ('c' * 64)
        harnessDigestEnd = ('c' * 64)
        counts = [ordered]@{
            consistent = 2
            'generator-limit' = 0
            'harness-error' = 0
        }
        unexpectedCount = 0
        durationMs = 1234
        uniqueProgramBodies = 2
        referenceCheckedCount = 2
        targetParityPassCount = 2
        targetParityDivergentCount = 0
        targetParityInconclusiveCount = 0
        harnessChangedDuringRun = $false
        casesWithValtypeRaiseProbe = 1
        casesWithDirectValtypeRaiseArrayComposition = 1
        casesWithChoiceReturningFunction = 1
        choiceReturningFunctionCount = 1
        casesWithAnd = 1
        casesWithOr = 1
        casesWithForLoop = 1
        casesWithForIteration = 1
        casesWithWhileLoop = 1
        casesWithWhileIteration = 1
        casesVisitingBothValtypeProbeKinds = 1
        referencePathCaseCounts = [ordered]@{
            'valtype-raise-probe' = 1
            'valtype-raise-success-path' = 1
            'and-rhs-executed' = 1
            'and-rhs-skipped' = 1
        }
        failureClusters = @()
        cases = $cases
    }
}

function Assert-ComparisonRejected {
    param(
        [string]$ExpectedMessage,
        [string]$Label
    )

    try {
        $null = & $scriptPath -LinuxReportDirectory $linuxDirectory `
            -WindowsReportDirectory $windowsDirectory
    }
    catch {
        if ($_.Exception.Message -match $ExpectedMessage) {
            return
        }
        throw "$Label failed for the wrong reason: $($_.Exception.Message)"
    }
    throw "$Label was not rejected."
}

try {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $nightlyWorkflowPath = Join-Path $repoRoot '.github/workflows/nightly-generator-corpus.yml'
    $nightlyWorkflow = Get-Content -LiteralPath $nightlyWorkflowPath -Raw
    $dependencyUpdateIndex = $nightlyWorkflow.IndexOf('run: moon update')
    $dependencyCheckIndex = $nightlyWorkflow.IndexOf('run: moon check --deny-warn')
    $corpusRunIndex = $nightlyWorkflow.IndexOf('$summary = ./scripts/run_batch.ps1')
    if ($dependencyUpdateIndex -lt 0 -or $dependencyCheckIndex -lt 0 -or
        $corpusRunIndex -lt 0 -or $dependencyUpdateIndex -ge $corpusRunIndex -or
        $dependencyCheckIndex -ge $corpusRunIndex) {
        throw 'Nightly corpus must resolve and check Mooncakes dependencies before running the batch.'
    }

    $clusterCases = @(
        [pscustomobject]@{ seed = 21; finding = 'output-mismatch'; signature = 'sig-a'; caseId = 'case-21' }
        [pscustomobject]@{ seed = 7; finding = 'output-mismatch'; signature = 'sig-a'; caseId = 'case-7' }
        [pscustomobject]@{ seed = 25; finding = 'runtime-failure'; signature = 'sig-a'; caseId = 'case-25' }
        [pscustomobject]@{ seed = 30; finding = 'output-mismatch'; signature = 'sig-b'; caseId = 'case-30' }
        [pscustomobject]@{ seed = 31; finding = 'output-mismatch'; signature = $null; caseId = $null }
        [pscustomobject]@{ seed = 32; finding = 'consistent'; signature = 'sig-a'; caseId = $null }
    )
    $clusters = @(Get-MoonSmithFailureClusters -Cases $clusterCases)
    if ($clusters.Count -ne 3 -or
        $clusters[0].finding -ne 'output-mismatch' -or
        $clusters[0].signature -ne 'sig-a' -or
        $clusters[0].count -ne 2 -or
        $clusters[0].firstSeed -ne 7 -or
        $clusters[0].representativeCaseId -ne 'case-7' -or
        ($clusters[0].seeds -join ',') -ne '7,21' -or
        ($clusters[0].caseIds -join ',') -ne 'case-7,case-21' -or
        $clusters[1].finding -ne 'runtime-failure' -or
        $clusters[2].signature -ne 'sig-b') {
        throw 'failure clusters did not group by finding and signature or select the lowest-seed representative.'
    }

    $linuxReport = New-TestReport -SeedStart 41000 -Targets @('js', 'wasm', 'wasm-gc')
    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release')
    $linuxReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $linuxDirectory 'batch_linux.json') -Encoding utf8
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8

    $outputPath = Join-Path $testRoot 'summary.json'
    $output = & $scriptPath -LinuxReportDirectory $linuxDirectory `
        -WindowsReportDirectory $windowsDirectory -OutputPath $outputPath
    $summary = $output | ConvertFrom-Json
    if ($summary.seedsCompared -ne 2 -or
        $summary.matchingSourceHashes -ne 2 -or
        $summary.matchingExpectedOutputs -ne 2 -or
        $summary.distinctProgramBodies -ne 2 -or
        $summary.linuxExecutions -ne 6 -or
        $summary.windowsExecutions -ne 2 -or
        $summary.consistentOnBothPlatforms -ne 2 -or
        -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw 'valid paired reports produced an incorrect comparison summary.'
    }

    $windowsReport.cases[1].targetParity.status = 'divergent'
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'does not have a passing Target Parity result' `
        -Label 'non-passing Target Parity'
    $rejectedNonPassingTargetParity = $true
    $windowsReport.cases[1].targetParity.status = 'pass'
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8

    $linuxReport.schemaVersion = 7
    $windowsReport.schemaVersion = 7
    $linuxReport.Remove('casesWithChoiceReturningFunction')
    $linuxReport.Remove('choiceReturningFunctionCount')
    $linuxReport.Remove('casesWithOr')
    $linuxReport.Remove('casesWithAnd')
    $windowsReport.Remove('casesWithChoiceReturningFunction')
    $windowsReport.Remove('choiceReturningFunctionCount')
    $windowsReport.Remove('casesWithOr')
    $windowsReport.Remove('casesWithAnd')
    foreach ($case in @($linuxReport.cases) + @($windowsReport.cases)) {
        $case.sourceConstructCounts.Remove('functionChoice')
        $case.sourceConstructCounts.Remove('or')
        $case.sourceConstructCounts.Remove('and')
    }
    $linuxReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $linuxDirectory 'batch_linux.json') -Encoding utf8
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    $legacyComparison = (& $scriptPath -LinuxReportDirectory $linuxDirectory `
        -WindowsReportDirectory $windowsDirectory | ConvertFrom-Json)
    if ($legacyComparison.seedsCompared -ne 2) {
        throw 'schema-7 paired reports were not accepted by the cross-platform comparer.'
    }
    $linuxReport.schemaVersion = 8
    $windowsReport.schemaVersion = 8
    $linuxReport.casesWithChoiceReturningFunction = 1
    $linuxReport.choiceReturningFunctionCount = 1
    $windowsReport.casesWithChoiceReturningFunction = 1
    $windowsReport.choiceReturningFunctionCount = 1
    $linuxReport.cases[0].sourceConstructCounts.functionChoice = 1
    $linuxReport.cases[1].sourceConstructCounts.functionChoice = 0
    $windowsReport.cases[0].sourceConstructCounts.functionChoice = 1
    $windowsReport.cases[1].sourceConstructCounts.functionChoice = 0
    $linuxReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $linuxDirectory 'batch_linux.json') -Encoding utf8
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8

    $schemaEightComparison = (& $scriptPath -LinuxReportDirectory $linuxDirectory `
        -WindowsReportDirectory $windowsDirectory | ConvertFrom-Json)
    if ($schemaEightComparison.seedsCompared -ne 2) {
        throw 'schema-8 paired reports were not accepted by the cross-platform comparer.'
    }
    $linuxReport.schemaVersion = 9
    $windowsReport.schemaVersion = 9
    $linuxReport.casesWithOr = 1
    $windowsReport.casesWithOr = 1
    $linuxReport.casesWithAnd = 1
    $windowsReport.casesWithAnd = 1
    $linuxReport.cases[0].sourceConstructCounts.or = 1
    $windowsReport.cases[0].sourceConstructCounts.or = 1
    $linuxReport.cases[1].sourceConstructCounts.or = 0
    $windowsReport.cases[1].sourceConstructCounts.or = 0
    $linuxReport.cases[0].sourceConstructCounts.and = 1
    $windowsReport.cases[0].sourceConstructCounts.and = 1
    $linuxReport.cases[1].sourceConstructCounts.and = 0
    $windowsReport.cases[1].sourceConstructCounts.and = 0
    $linuxReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $linuxDirectory 'batch_linux.json') -Encoding utf8
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8

    $customBatchHtmlPath = Join-Path $testRoot 'custom-batch-summary.html'
    $batchReport = (& $cliPath batch-report `
        -BatchPath (Join-Path $linuxDirectory 'batch_linux.json') `
        -BatchOutputPath $customBatchHtmlPath | ConvertFrom-Json)
    $batchHtml = Get-Content -LiteralPath $batchReport.htmlReportPath -Raw
    $batchHtmlRows = [regex]::Matches($batchHtml, '<tr>').Count
    if ($batchReport.count -ne 2 -or
        $batchReport.htmlReportPath -ne $customBatchHtmlPath -or
        -not (Test-Path -LiteralPath $customBatchHtmlPath -PathType Leaf) -or
        $batchHtmlRows -ne 24 -or
        -not $batchHtml.StartsWith('<!doctype html>') -or
        -not $batchHtml.Contains('Run summary') -or
        -not $batchHtml.Contains('Generator and reference coverage') -or
        -not $batchHtml.Contains('Generated source coverage') -or
        -not $batchHtml.Contains('Reference trace coverage') -or
        -not $batchHtml.Contains('casesWithValtypeRaiseProbe') -or
        -not $batchHtml.Contains('casesWithChoiceReturningFunction') -or
        -not $batchHtml.Contains('casesWithOr') -or
        -not $batchHtml.Contains('casesWithAnd') -or
        -not $batchHtml.Contains('casesWithWhileLoop') -or
        -not $batchHtml.Contains('casesWithWhileIteration') -or
        $batchHtml.IndexOf('casesWithWhileIteration') -lt $batchHtml.IndexOf('Reference trace coverage') -or
        -not $batchHtml.Contains('valtype-raise-success-path') -or
        -not $batchHtml.Contains('Failure clusters') -or
        -not $batchHtml.Contains('Per-seed results') -or
        -not $batchHtml.Contains('Target Parity') -or
        -not $batchHtml.Contains('case-41000') -or
        -not $batchHtml.Contains('&lt;script&gt;alert(1)&lt;/script&gt;') -or
        -not $batchHtml.Contains('&lt;img src=x onerror=alert(1)&gt;') -or
        $batchHtml -match '<script\b|<img\b') {
        throw "batch-report did not render an offline, escaped batch summary (count=$($batchReport.count), rows=$batchHtmlRows, doctype=$($batchHtml.StartsWith('<!doctype html>')), script=$($batchHtml -match '<script\b|<img\b'))."
    }

    $nightlySummary = [pscustomobject]@{
        schemaVersion = 11
        count = 2
        uniqueProgramBodies = 2
        referenceCheckedCount = 2
        targetParityPassCount = 2
        unexpectedCount = 0
        harnessChangedDuringRun = $false
        casesWithValtypeRaiseProbe = 1
        casesWithDirectValtypeRaiseArrayComposition = 1
        casesVisitingBothValtypeProbeKinds = 1
        casesWithChoiceReturningFunction = 1
        choiceReturningFunctionCount = 1
        casesWithAnd = 1
        casesWithOr = 1
        casesWithWhileLoop = 1
        casesWithWhileIteration = 1
        casesWithArrayGrow = 2
        casesWithArrayAliasUpdate = 2
        cases = @(
            [pscustomobject]@{
                seed = 1
                targetParity = [pscustomobject]@{ status = 'pass' }
                sourceConstructCounts = [pscustomobject]@{ functionChoice = 1; and = 1; or = 1; whileLoop = 1; arrayGrow = 1; arrayAliasUpdate = 1 }
                referencePathKinds = @('and-rhs-executed', 'or-rhs-executed', 'while-iteration', 'array-grow-index-0', 'array-alias-update-index-0')
            }
            [pscustomobject]@{
                seed = 2
                targetParity = [pscustomobject]@{ status = 'pass' }
                sourceConstructCounts = [pscustomobject]@{ functionChoice = 0; and = 0; or = 0; whileLoop = 0; arrayGrow = 1; arrayAliasUpdate = 1 }
                referencePathKinds = @('and-rhs-skipped', 'or-rhs-skipped', 'array-grow-index-1', 'array-alias-update-index-1')
            }
        )
        referencePathCaseCounts = [pscustomobject]@{
            'valtype-raise-success-path' = 1
            'valtype-raise-error-path' = 1
            'or-rhs-executed' = 1
            'or-rhs-skipped' = 1
            'and-rhs-executed' = 1
            'and-rhs-skipped' = 1
            'while-iteration' = 1
            'array-grow-index-0' = 1
            'array-grow-index-1' = 1
            'array-alias-update-index-0' = 1
            'array-alias-update-index-1' = 1
        }
    }
    $coverageValidation = (& (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
        -Summary $nightlySummary -ExpectedCount 2)
    if (-not $coverageValidation.valid -or
        $coverageValidation.bothProbeTraceCases -ne 1 -or
        $coverageValidation.choiceReturningFunctionCases -ne 1 -or
        $coverageValidation.raiseErrorPathCases -ne 1 -or
        $coverageValidation.whileLoopCases -ne 1 -or
        $coverageValidation.whileIterationCases -ne 1 -or
        $coverageValidation.arrayGrowFirstIndexCases -ne 1 -or
        $coverageValidation.arrayGrowSecondIndexCases -ne 1 -or
        $coverageValidation.arrayGrowSourceCases -ne 2 -or
        $coverageValidation.arrayAliasUpdateSourceCases -ne 2 -or
        $coverageValidation.arrayAliasUpdateFirstIndexCases -ne 1 -or
        $coverageValidation.arrayAliasUpdateSecondIndexCases -ne 1) {
        throw 'nightly summary validation accepted an incorrect coverage summary.'
    }
    $skewedAliasSummary = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $skewedAliasSummary.count = 4
    $skewedAliasSummary.uniqueProgramBodies = 4
    $skewedAliasSummary.referenceCheckedCount = 4
    $skewedAliasSummary.targetParityPassCount = 4
    $skewedAliasSummary.casesWithArrayAliasUpdate = 4
    $skewedAliasSummary.referencePathCaseCounts.'array-alias-update-index-0' = 3
    foreach ($seed in @(3, 4)) {
        $skewedAliasSummary.cases += [pscustomobject]@{
            seed = $seed
            targetParity = [pscustomobject]@{ status = 'pass' }
            sourceConstructCounts = [pscustomobject]@{
                functionChoice = 0; and = 0; or = 0; whileLoop = 0
                arrayGrow = 0; arrayAliasUpdate = 1
            }
            referencePathKinds = @('array-alias-update-index-0')
        }
    }
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $skewedAliasSummary -ExpectedCount 4
        throw 'nightly gate accepted skewed array-alias-update index coverage.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'array-alias-update index balance') { throw }
    }
    $badArrayAliasSource = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $badArrayAliasSource.casesWithArrayAliasUpdate = 1
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $badArrayAliasSource -ExpectedCount 2
        throw 'nightly gate accepted an inconsistent array-alias-update source count.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'array-alias-update case total does not match') { throw }
    }
    $badArrayGrowSource = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $badArrayGrowSource.casesWithArrayGrow = 1
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $badArrayGrowSource -ExpectedCount 2
        throw 'nightly gate accepted an inconsistent array-growth source count.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'array-growth case total does not match') { throw }
    }
    $badArrayGrowIndex = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $badArrayGrowIndex.referencePathCaseCounts.'array-grow-index-1' = 0
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $badArrayGrowIndex -ExpectedCount 2
        throw 'nightly gate accepted missing grown-array second-index coverage.'
    }
    catch {
        if ($_.Exception.Message -notmatch "did not exercise the required 'array-grow-index-1' path") { throw }
    }
    $badWhileSource = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $badWhileSource.cases[0].sourceConstructCounts.whileLoop = 0
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $badWhileSource -ExpectedCount 2
        throw 'nightly gate accepted inconsistent while-loop source coverage.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'while-loop case total does not match') { throw }
    }
    $badWhileTrace = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $badWhileTrace.casesWithWhileIteration = 0
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $badWhileTrace -ExpectedCount 2
        throw 'nightly gate accepted missing while-iteration coverage.'
    }
    catch {
        if ($_.Exception.Message -notmatch "casesWithWhileIteration") { throw }
    }
    $nightlySummary.schemaVersion = 8
    $legacyNightlySummaryRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'requires batch schema 11') {
            throw "nightly schema gate rejected the legacy fixture for the wrong reason: $($_.Exception.Message)"
        }
        $legacyNightlySummaryRejected = $true
    }
    if (-not $legacyNightlySummaryRejected) {
        throw 'nightly validator accepted a schema-7 batch summary.'
    }
    $nightlySummary.schemaVersion = 9
    $legacyNightlySummaryRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'requires batch schema 11') {
            throw "nightly schema gate rejected the schema-9 fixture for the wrong reason: $($_.Exception.Message)"
        }
        $legacyNightlySummaryRejected = $true
    }
    if (-not $legacyNightlySummaryRejected) {
        throw 'nightly validator accepted a schema-9 batch summary.'
    }
    $nightlySummary.schemaVersion = 10
    $legacyNightlySummaryRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'requires batch schema 11') {
            throw "nightly schema gate rejected the schema-10 fixture for the wrong reason: $($_.Exception.Message)"
        }
        $legacyNightlySummaryRejected = $true
    }
    if (-not $legacyNightlySummaryRejected) {
        throw 'nightly validator accepted a schema-10 batch summary.'
    }
    $nightlySummary.schemaVersion = 11
    $nightlySummary.targetParityPassCount = 1
    $targetParityRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
        throw 'nightly gate accepted an incomplete Target Parity pass count.'
    }
    catch {
        if ($_.Exception.Message -notmatch 'Nightly Target Parity must pass all 2 cases') { throw }
        $targetParityRejected = $true
    }
    if (-not $targetParityRejected) {
        throw 'nightly gate accepted a divergent or missing Target Parity result.'
    }
    $nightlySummary.targetParityPassCount = 2
    $nightlySummary.casesVisitingBothValtypeProbeKinds = 0
    $nightlyCoverageRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'casesVisitingBothValtypeProbeKinds') {
            throw "nightly coverage gate rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $nightlyCoverageRejected = $true
    }
    if (-not $nightlyCoverageRejected) {
        throw 'nightly coverage gate accepted a report with no composed-probe reference traces.'
    }

    $nightlySummary.casesVisitingBothValtypeProbeKinds = 1
    $nightlySummary.cases[0].sourceConstructCounts.functionChoice = 0
    $choiceFunctionCasesMismatchRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'case total does not match per-case') {
            throw "nightly Choice-function case-total check rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $choiceFunctionCasesMismatchRejected = $true
    }
    if (-not $choiceFunctionCasesMismatchRejected) {
        throw 'nightly coverage gate accepted inconsistent Choice-function case totals.'
    }
    $nightlySummary.cases[0].sourceConstructCounts.functionChoice = 2
    $choiceFunctionCountMismatchRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'count does not match per-case') {
            throw "nightly Choice-function total check rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $choiceFunctionCountMismatchRejected = $true
    }
    if (-not $choiceFunctionCountMismatchRejected) {
        throw 'nightly coverage gate accepted an inconsistent Choice-returning function count.'
    }
    $nightlySummary.cases[0].sourceConstructCounts.functionChoice = 1
    $nightlySummary.casesWithChoiceReturningFunction = 0
    $choiceFunctionCoverageRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'casesWithChoiceReturningFunction') {
            throw "nightly Choice-function gate rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $choiceFunctionCoverageRejected = $true
    }
    if (-not $choiceFunctionCoverageRejected) {
        throw 'nightly coverage gate accepted a report with no Choice-returning functions.'
    }

    $nightlySummary.casesWithChoiceReturningFunction = 1
    $nightlySummary.choiceReturningFunctionCount = 0
    $choiceFunctionCountRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'did not count any Choice-returning local functions') {
            throw "nightly Choice-function count gate rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $choiceFunctionCountRejected = $true
    }
    if (-not $choiceFunctionCountRejected) {
        throw 'nightly coverage gate accepted a report with no counted Choice-returning functions.'
    }

    $nightlySummary.choiceReturningFunctionCount = 1
    $nightlySummary.cases[1].sourceConstructCounts.or = -1
    $invalidOrCountRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'valid sourceConstructCounts.or') {
            throw "nightly disjunction validation rejected a negative count for the wrong reason: $($_.Exception.Message)"
        }
        $invalidOrCountRejected = $true
    }
    if (-not $invalidOrCountRejected) {
        throw 'nightly coverage gate accepted a negative per-case disjunction count.'
    }
    $nightlySummary.cases[1].sourceConstructCounts.or = 0
    $nightlySummary.cases[0].sourceConstructCounts.or = 0
    $orCoverageMismatchRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'disjunction case total does not match') {
            throw "nightly disjunction reconciliation rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $orCoverageMismatchRejected = $true
    }
    if (-not $orCoverageMismatchRejected) {
        throw 'nightly coverage gate accepted an inconsistent disjunction case total.'
    }
    $nightlySummary.cases[0].sourceConstructCounts.or = 1

    $lowOrCoverageSummary = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $lowOrCoverageSummary.count = 10
    $lowOrCoverageSummary.uniqueProgramBodies = 10
    $lowOrCoverageSummary.referenceCheckedCount = 10
    $lowOrCoverageSummary.targetParityPassCount = 10
    $lowOrCoverageSummary.cases = @($lowOrCoverageSummary.cases)
    $lowOrCoverageSummary.cases[1].sourceConstructCounts.and = 1
    $lowOrCoverageSummary.casesWithAnd = 2
    for ($caseIndex = 2; $caseIndex -lt 10; $caseIndex++) {
        $lowOrCoverageSummary.cases += [pscustomobject]@{
            seed = $caseIndex
            targetParity = [pscustomobject]@{ status = 'pass' }
            sourceConstructCounts = [pscustomobject]@{ functionChoice = 0; and = 0; or = 0; whileLoop = 0; arrayGrow = 0; arrayAliasUpdate = 0 }
            referencePathKinds = @()
        }
    }
    $lowOrCoverageRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $lowOrCoverageSummary -ExpectedCount 10
    }
    catch {
        if ($_.Exception.Message -notmatch 'below the minimum of 2 cases') {
            throw "nightly disjunction minimum coverage rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $lowOrCoverageRejected = $true
    }
    if (-not $lowOrCoverageRejected) {
        throw 'nightly coverage gate accepted disjunction in less than 20% of the corpus.'
    }

    $lowAndCoverageSummary = $nightlySummary | ConvertTo-Json -Depth 10 | ConvertFrom-Json
    $lowAndCoverageSummary.count = 10
    $lowAndCoverageSummary.uniqueProgramBodies = 10
    $lowAndCoverageSummary.referenceCheckedCount = 10
    $lowAndCoverageSummary.targetParityPassCount = 10
    $lowAndCoverageSummary.cases[1].sourceConstructCounts.or = 1
    $lowAndCoverageSummary.casesWithOr = 2
    $lowAndCoverageSummary.cases = @($lowAndCoverageSummary.cases)
    for ($caseIndex = 2; $caseIndex -lt 10; $caseIndex++) {
        $lowAndCoverageSummary.cases += [pscustomobject]@{
            seed = $caseIndex
            targetParity = [pscustomobject]@{ status = 'pass' }
            sourceConstructCounts = [pscustomobject]@{ functionChoice = 0; and = 0; or = 0; whileLoop = 0; arrayGrow = 0; arrayAliasUpdate = 0 }
            referencePathKinds = @()
        }
    }
    $lowAndCoverageRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $lowAndCoverageSummary -ExpectedCount 10
    }
    catch {
        if ($_.Exception.Message -notmatch 'conjunction coverage is below the minimum of 2 cases') {
            throw "nightly conjunction minimum coverage rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $lowAndCoverageRejected = $true
    }
    if (-not $lowAndCoverageRejected) {
        throw 'nightly coverage gate accepted conjunction in less than 20% of the corpus.'
    }

    $nightlySummary.casesWithAnd = 0
    $andCoverageRequiredRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch "required generator coverage metric 'casesWithAnd'") {
            throw "nightly conjunction coverage requirement rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $andCoverageRequiredRejected = $true
    }
    if (-not $andCoverageRequiredRejected) {
        throw 'nightly coverage gate accepted a corpus with no conjunction sources.'
    }
    $nightlySummary.casesWithAnd = 1

    $nightlySummary.referencePathCaseCounts.'or-rhs-skipped' = 0
    $orShortCircuitPathRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch "did not exercise the required 'or-rhs-skipped' path") {
            throw "nightly disjunction path gate rejected missing short-circuit coverage for the wrong reason: $($_.Exception.Message)"
        }
        $orShortCircuitPathRejected = $true
    }
    if (-not $orShortCircuitPathRejected) {
        throw 'nightly coverage gate accepted a corpus with no short-circuit-skipped OR path.'
    }
    $nightlySummary.referencePathCaseCounts.'or-rhs-skipped' = 1

    $nightlySummary.referencePathCaseCounts.'or-rhs-executed' = 2
    $orTraceCountMismatchRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch "reference trace 'or-rhs-executed' case total does not match per-case records") {
            throw "nightly OR trace reconciliation rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $orTraceCountMismatchRejected = $true
    }
    if (-not $orTraceCountMismatchRejected) {
        throw 'nightly coverage gate accepted an inconsistent per-case OR trace total.'
    }
    $nightlySummary.referencePathCaseCounts.'or-rhs-executed' = 1

    $nightlySummary.referencePathCaseCounts.'and-rhs-skipped' = 0
    $andShortCircuitPathRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch "did not exercise the required 'and-rhs-skipped' path") {
            throw "nightly conjunction path gate rejected missing short-circuit coverage for the wrong reason: $($_.Exception.Message)"
        }
        $andShortCircuitPathRejected = $true
    }
    if (-not $andShortCircuitPathRejected) {
        throw 'nightly coverage gate accepted a corpus with no short-circuit-skipped AND path.'
    }
    $nightlySummary.referencePathCaseCounts.'and-rhs-skipped' = 1

    $nightlySummary.referencePathCaseCounts.'and-rhs-executed' = 2
    $andTraceCountMismatchRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch "reference trace 'and-rhs-executed' case total does not match per-case records") {
            throw "nightly AND trace reconciliation rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $andTraceCountMismatchRejected = $true
    }
    if (-not $andTraceCountMismatchRejected) {
        throw 'nightly coverage gate accepted an inconsistent per-case AND trace total.'
    }
    $nightlySummary.referencePathCaseCounts.'and-rhs-executed' = 1

    $nightlySummary.cases[1].sourceConstructCounts.and = -1
    $invalidAndCountRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'valid sourceConstructCounts.and') {
            throw "nightly conjunction validation rejected a negative count for the wrong reason: $($_.Exception.Message)"
        }
        $invalidAndCountRejected = $true
    }
    if (-not $invalidAndCountRejected) {
        throw 'nightly coverage gate accepted a negative per-case conjunction count.'
    }
    $nightlySummary.cases[1].sourceConstructCounts.and = 0

    $nightlySummary.casesWithAnd = 2
    $andCoverageMismatchRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'validate_nightly_summary.ps1') `
            -Summary $nightlySummary -ExpectedCount 2
    }
    catch {
        if ($_.Exception.Message -notmatch 'conjunction case total does not match') {
            throw "nightly conjunction reconciliation rejected the fixture for the wrong reason: $($_.Exception.Message)"
        }
        $andCoverageMismatchRejected = $true
    }
    if (-not $andCoverageMismatchRejected) {
        throw 'nightly coverage gate accepted an inconsistent conjunction case total.'
    }
    $nightlySummary.casesWithAnd = 1

    $legacyReportPath = Join-Path $testRoot 'batch_legacy.json'
    $legacyHtmlPath = Join-Path $testRoot 'batch_legacy.html'
    $legacyReport = [ordered]@{}
    foreach ($property in $linuxReport.Keys) {
        if ($property -notin @(
                'failureClusters',
                'casesWithChoiceReturningFunction',
                'choiceReturningFunctionCount',
                'casesWithOr',
                'casesWithAnd'
            )) {
            $legacyReport[$property] = $linuxReport[$property]
        }
    }
    $legacyReport.schemaVersion = 7
    foreach ($case in $legacyReport.cases) {
        if ($null -ne $case.sourceConstructCounts) {
            $case.sourceConstructCounts.Remove('functionChoice')
            $case.sourceConstructCounts.Remove('or')
            $case.sourceConstructCounts.Remove('and')
        }
    }
    $legacyReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $legacyReportPath -Encoding utf8
    $legacyHtmlResult = (& (Join-Path $PSScriptRoot 'render_batch_report.ps1') `
        -BatchPath $legacyReportPath -OutputPath $legacyHtmlPath | ConvertFrom-Json)
    $legacyHtml = Get-Content -LiteralPath $legacyHtmlResult.htmlReportPath -Raw
    if ($legacyHtmlResult.count -ne 2 -or
        -not $legacyHtml.Contains('Failure-cluster data was not recorded in this batch schema.')) {
        throw 'schema-7 batch report did not render and explain unavailable failure-cluster data.'
    }

    $sourceJsonBefore = Get-Content -LiteralPath (Join-Path $linuxDirectory 'batch_linux.json') -Raw
    $sourceOverwriteRejected = $false
    try {
        $null = & (Join-Path $PSScriptRoot 'render_batch_report.ps1') `
            -BatchPath (Join-Path $linuxDirectory 'batch_linux.json') `
            -OutputPath (Join-Path $linuxDirectory 'batch_linux.json') -Force
    }
    catch {
        if ($_.Exception.Message -notmatch 'Refusing to replace the source batch JSON') {
            throw "batch-report source protection failed for the wrong reason: $($_.Exception.Message)"
        }
        $sourceOverwriteRejected = $true
    }
    if (-not $sourceOverwriteRejected -or
        (Get-Content -LiteralPath (Join-Path $linuxDirectory 'batch_linux.json') -Raw) -ne $sourceJsonBefore) {
        throw 'batch-report modified its source JSON when output was directed to the same path.'
    }

    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release') -FirstHash ('d' * 64)
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'source hashes differ' -Label 'source-hash mismatch'

    $windowsReport = New-TestReport -SeedStart 41001 -Targets @('native-release')
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'same seed set' -Label 'seed-set mismatch'

    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release') `
        -ToolchainVersion 'moon 0.2.test (different fixture)'
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'same single MoonBit toolchain version' -Label 'toolchain mismatch'

    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release') `
        -FirstExpectedOutput "wrong`n"
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'Reference expected outputs differ' -Label 'reference-output mismatch'

    $resolvedTemp = [IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath($tempDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTemp.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove test output outside the temporary directory: $resolvedTemp"
    }
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    [pscustomobject]@{
        passed = $true
        comparedSeeds = $summary.seedsCompared
        rejectedHashMismatch = $true
        rejectedSeedMismatch = $true
        rejectedToolchainMismatch = $true
        rejectedExpectedOutputMismatch = $true
        rejectedNonPassingTargetParity = $rejectedNonPassingTargetParity
        failureClusters = $clusters.Count
        batchHtmlCases = $batchReport.count
        batchHtmlRows = $batchHtmlRows
        legacyHtmlHandled = $true
        sourceJsonProtected = $true
        nightlyCoverageGate = $true
    } | ConvertTo-Json
}
catch {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath($testRoot)
        $resolvedTempRoot = [IO.Path]::GetFullPath($tempDirectory).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if ($resolvedTemp.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
    throw
}
