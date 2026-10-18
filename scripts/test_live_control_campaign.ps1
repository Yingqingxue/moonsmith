$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$runner = Join-Path $PSScriptRoot 'run_live_control_campaign.ps1'
$selector = Join-Path $PSScriptRoot 'live_control_policy.ps1'
. $selector

$emptySeen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
$selectionCandidates = @(
    [pscustomobject]@{ seed=9; proposalOrdinal=0; preflightStatus='checked'; sourceLineCount=5; sourceSizeBand='lt50'; referencePathKinds=@('known') },
    [pscustomobject]@{ seed=10; proposalOrdinal=1; preflightStatus='checked'; sourceLineCount=6; sourceSizeBand='lt50'; referencePathKinds=@('novel-a','novel-b') },
    [pscustomobject]@{ seed=11; proposalOrdinal=2; preflightStatus='checked'; sourceLineCount=7; sourceSizeBand='200to499'; referencePathKinds=@('novel-x','novel-y','novel-z') }
)
$sequential = Select-LiveControlCandidate -Candidates $selectionCandidates -Policy sequential -SeenPathKinds $emptySeen
$guided = Select-LiveControlCandidate -Candidates $selectionCandidates -Policy semantic-guided -SeenPathKinds $emptySeen
if ($sequential.candidate.seed -ne 9 -or $guided.candidate.seed -ne 10) {
    throw 'Live policy selector did not apply the sequential/size-banded novelty rules.'
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('moonsmith-live-controls-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $runs = foreach ($arm in @(
        [pscustomobject]@{ policy='sequential'; start=310000; orderSeed=1111 },
        [pscustomobject]@{ policy='semantic-guided'; start=320000; orderSeed=2222 }
    )) {
        $reportPath = Join-Path $testRoot ($arm.policy + '.json')
        $raw = & $runner -Policy $arm.policy -SeedStart $arm.start -ProposalOrderSeed $arm.orderSeed -ExecutionBudget 2 `
            -ProposalBatchSize 2 -Targets @('js') -Depth 0 -TimeoutSeconds 30 -OutputPath $reportPath
        if (-not (Test-Path -LiteralPath $reportPath)) { throw "Live control arm $($arm.policy) did not write its report." }
        $report = Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json
        if ($report.proposalCount -ne 4 -or $report.selectedCount -ne 2 -or
            $report.backendChecks -ne 2 -or $report.candidateProposalWorkIsChargedToCampaign -ne $true -or
            @($report.perArmCases[0].referencePathKinds).Count -eq 0 -or
            [string]$report.perArmCases[0].finding -eq '' -or
            $report.candidateSourcesAndReferenceTracesPreserved -ne $true -or
            -not (Test-Path -LiteralPath $report.artifactDirectory)) {
            throw "Live control arm $($arm.policy) omitted the expected online evidence or budget accounting."
        }
        foreach ($proposal in $report.proposalOutcomes | Where-Object { $_.preflightStatus -eq 'checked' }) {
            if (-not (Test-Path -LiteralPath $proposal.sourcePath) -or
                -not (Test-Path -LiteralPath $proposal.referenceTracePath) -or
                -not (Test-Path -LiteralPath $proposal.expectedOutputPath)) {
                throw "Live control arm $($arm.policy) did not preserve candidate artifacts."
            }
        }
        $report
    }
    if (@($runs[0].perArmCases[0].proposalWindowSeeds | Where-Object { $_ -ge 320000 }).Count -gt 0 -or
        @($runs[1].perArmCases[0].proposalWindowSeeds | Where-Object { $_ -lt 320000 }).Count -gt 0 -or
        (($runs[0].configuredTargets -join ',') -ne ($runs[1].configuredTargets -join ','))) {
        throw 'The control arms did not use independent seed ranges and a matched backend configuration.'
    }
    if ($runs[0].proposalOrderSeed -ne 1111 -or $runs[1].proposalOrderSeed -ne 2222 -or
        $runs[0].perArmCases[0].seed -ne $runs[0].perArmCases[0].proposalWindowSeeds[0] -or
        $runs[0].perArmCases[1].seed -ne $runs[0].perArmCases[1].proposalWindowSeeds[0] -or
        @($runs[1].perArmCases[1].newlyCoveredPathKinds).Count -eq 0) {
        throw 'The semantic-guided control did not use prior live feedback while sequential remained ordered.'
    }
    [pscustomobject]@{
        passed = $true
        sequentialPolicyApplied = $true
        semanticNoveltyPolicyApplied = $true
        liveGenerationReferenceTraceAndVerification = $true
        independentSeedRanges = $true
        matchedBackendCheckBudget = $true
        proposalCostsReported = $true
        selectedSourceReferenceArtifactsPreserved = $true
        priorRoundFeedbackChangesNextProposalChoice = $true
        backendFailuresCountAsChecks = $true
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
