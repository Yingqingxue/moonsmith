$ErrorActionPreference = 'Stop'
$selectionRunner = Join-Path $PSScriptRoot 'compare_semantic_selection.ps1'
$comparisonRunner = Join-Path $PSScriptRoot 'run_live_feedback_campaign_comparison.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('moonsmith-three-arm-live-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $selectionPath = Join-Path $testRoot 'configuration.json'
    $null = & $selectionRunner -SeedStart 300000 -CandidateCount 4 -ExecutionBudget 2 `
        -Depth 0 -Targets @('js') -TimeoutSeconds 30 -OutputPath $selectionPath
    if (-not (Test-Path -LiteralPath $selectionPath)) { throw 'Selection configuration did not write its raw report.' }

    $outputPath = Join-Path $testRoot 'three-arm.json'
    $null = & $comparisonRunner -SelectionReport $selectionPath `
        -SequentialSeedStart 310000 -SemanticGuidedSeedStart 320000 `
        -MoonGrammataSeedMinimum 330000 -MoonGrammataSeedMaximum 330100 `
        -ExecutionBudget 2 -ProposalBatchSize 2 -SequentialProposalOrderSeed 10 `
        -SemanticProposalOrderSeed 20 -MoonGrammataCampaignSeed 778899 -OutputPath $outputPath
    if (-not (Test-Path -LiteralPath $outputPath)) { throw 'Three-arm campaign comparison did not write its summary.' }
    $result = Get-Content -LiteralPath $outputPath -Raw -Encoding utf8 | ConvertFrom-Json
    $expectedChecks = 2
    if ($result.configuration.requestedCasesPerArm -ne 2 -or
        $result.backendCheckBudgetPerArm -ne $expectedChecks -or
        -not $result.matchedActualBackendCheckBudget -or
        $result.sequential.backendExecutionAttempts -ne $expectedChecks -or
        $result.semanticGuided.backendExecutionAttempts -ne $expectedChecks -or
        $result.moonGrammata.callbackCount -ne 2 -or
        $result.moonGrammata.referenceChecks -ne 2 -or
        $result.moonGrammata.backendExecutionAttempts -ne $expectedChecks -or
        $result.harnessChangedDuringRun -or
        $result.wallClockThroughputClaimAllowed -or
        $result.seedRanges.disjoint -ne $true) {
        throw 'Three-arm live campaign did not preserve matched settings, distinct seeds, actual backend budgets, and cautious claims.'
    }
    foreach ($path in $result.rawArtifacts) {
        if (-not (Test-Path -LiteralPath $path)) { throw "Missing preserved raw arm artifact: $path" }
    }
    $liveArtifactRoot = [string]$result.moonGrammata.reportPath + '.artifacts'
    $liveRaw = Get-Content -LiteralPath $result.moonGrammata.reportPath -Raw -Encoding utf8 | ConvertFrom-Json
    $liveCallbackArtifacts = @(Get-ChildItem -LiteralPath $liveArtifactRoot -Directory -Filter 'callback_*')
    if ($result.rawArtifacts -notcontains $liveArtifactRoot -or
        $liveRaw.moonGrammata.liveArtifactDirectory -ne $liveArtifactRoot -or
        $liveRaw.moonGrammata.liveArtifactCallbackCount -ne $result.moonGrammata.callbackCount -or
        $liveCallbackArtifacts.Count -ne $result.moonGrammata.callbackCount) {
        throw 'Three-arm raw artifacts do not expose every synchronous MoonGrammata verifier callback.'
    }
    foreach ($callbackArtifact in $liveCallbackArtifacts) {
        $candidateArtifact = Get-ChildItem -LiteralPath $callbackArtifact.FullName -Directory -Filter 'candidate_*' |
            Select-Object -First 1
        if (-not $candidateArtifact -or
            -not (Test-Path -LiteralPath (Join-Path $candidateArtifact.FullName 'source.mbt')) -or
            -not (Test-Path -LiteralPath (Join-Path $candidateArtifact.FullName 'report.json'))) {
            throw 'A three-arm MoonGrammata callback artifact lacks replayable source or verifier JSON.'
        }
    }
    foreach ($arm in @($result.sequential, $result.semanticGuided)) {
        $controlReport = Get-Content -LiteralPath $arm.reportPath -Raw -Encoding utf8 | ConvertFrom-Json
        foreach ($proposal in $controlReport.proposalOutcomes) {
            if ($proposal.preflightStatus -eq 'checked' -and
                (-not (Test-Path -LiteralPath $proposal.sourcePath) -or
                    -not (Test-Path -LiteralPath $proposal.referenceTracePath) -or
                    -not (Test-Path -LiteralPath $proposal.expectedOutputPath))) {
                throw 'A control-arm generated source or reference trace artifact was not preserved.'
            }
        }
    }

    $staleSelection = Get-Content -LiteralPath $selectionPath -Raw -Encoding utf8 | ConvertFrom-Json
    $staleSelection.harnessDigestEnd = 'stale-test-digest'
    $stalePath = Join-Path $testRoot 'stale-configuration.json'
    [IO.File]::WriteAllText($stalePath, ($staleSelection | ConvertTo-Json -Depth 10), [Text.UTF8Encoding]::new($false))
    $staleRejected = $false
    try {
        $null = & $comparisonRunner -SelectionReport $stalePath `
            -SequentialSeedStart 310000 -SemanticGuidedSeedStart 320000 `
            -MoonGrammataSeedMinimum 330000 -MoonGrammataSeedMaximum 330100 `
            -ExecutionBudget 2 -ProposalBatchSize 2 -SequentialProposalOrderSeed 10 `
            -SemanticProposalOrderSeed 20 -MoonGrammataCampaignSeed 778899 `
            -OutputPath (Join-Path $testRoot 'stale-result.json')
    } catch {
        if ($_.Exception.Message -notlike '*different or changing verifier harness*') { throw }
        $staleRejected = $true
    }
    if (-not $staleRejected -or (Test-Path -LiteralPath (Join-Path $testRoot 'stale-result.json'))) {
        throw 'The three-arm wrapper did not reject an outdated harness configuration before starting experiments.'
    }
    [pscustomobject]@{
        passed = $true
        arms = 3
        sameTargetsDepthAndTimeout = $true
        equalObservedBackendChecks = $true
        disjointIndependentSeedRanges = $true
        onlineMoonGrammataCallbacks = 2
        rawReportsAndCandidateArtifactsPreserved = $true
        harnessDigestVerified = $true
        staleHarnessRejected = $true
        throughputClaimsDisabled = $true
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
