param(
    [Parameter(Mandatory)][string]$SelectionReport,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$SequentialSeedStart,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$SemanticGuidedSeedStart,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$MoonGrammataSeedMinimum,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$MoonGrammataSeedMaximum,
    [Parameter()][ValidateRange(1, 1000)][int]$ExecutionBudget = 6,
    [Parameter()][ValidateRange(1, 20)][int]$ProposalBatchSize = 4,
    [Parameter()][ValidateRange(0, 2147483647)][int]$SequentialProposalOrderSeed = 20261020,
    [Parameter()][ValidateRange(0, 2147483647)][int]$SemanticProposalOrderSeed = 20261021,
    [Parameter()][long]$MoonGrammataCampaignSeed = 20261019,
    [Parameter()][string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$selectionPath = (Resolve-Path -LiteralPath $SelectionReport -ErrorAction Stop).Path
$selection = Get-Content -LiteralPath $selectionPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($selection.schemaVersion -ne 1 -or $selection.harnessChangedDuringRun -or -not $selection.harnessDigestEnd) {
    throw 'A complete selection configuration report from the current, unchanged harness is required.'
}
$targets = @($selection.configuredTargets | ForEach-Object { [string]$_ })
$depth = [int]$selection.depth
$timeout = [int]$selection.timeoutSeconds
if ($targets.Count -eq 0 -or @($targets | Select-Object -Unique).Count -ne $targets.Count) { throw 'The selection report must have a nonempty unique target matrix.' }
if ($MoonGrammataSeedMaximum -lt $MoonGrammataSeedMinimum -or
    ([long]$MoonGrammataSeedMaximum - [long]$MoonGrammataSeedMinimum + 1) -lt $ExecutionBudget) {
    throw 'MoonGrammata seed range must be ordered and large enough for the requested callback budget.'
}
if ($SequentialProposalOrderSeed -eq $SemanticProposalOrderSeed) {
    throw 'Sequential and semantic-guided controls require separate proposal-order seeds.'
}
if ([long]$MoonGrammataCampaignSeed -eq [long]$SequentialProposalOrderSeed -or
    [long]$MoonGrammataCampaignSeed -eq [long]$SemanticProposalOrderSeed) {
    throw 'MoonGrammata campaign seed must be distinct from both control proposal-order seeds.'
}
$sequentialEnd = [long]$SequentialSeedStart + ([long]$ExecutionBudget * $ProposalBatchSize)
$guidedEnd = [long]$SemanticGuidedSeedStart + ([long]$ExecutionBudget * $ProposalBatchSize)
if ($sequentialEnd -gt [int]::MaxValue -or $guidedEnd -gt [int]::MaxValue) { throw 'Control seed range exceeds Int32.' }
$ranges = @(
    [pscustomobject]@{ name='sequential'; start=[long]$SequentialSeedStart; endExclusive=$sequentialEnd },
    [pscustomobject]@{ name='semantic-guided'; start=[long]$SemanticGuidedSeedStart; endExclusive=$guidedEnd },
    [pscustomobject]@{ name='moongrammata'; start=[long]$MoonGrammataSeedMinimum; endExclusive=([long]$MoonGrammataSeedMaximum + 1) }
)
for ($i = 0; $i -lt $ranges.Count; $i++) {
    for ($j = $i + 1; $j -lt $ranges.Count; $j++) {
        if ($ranges[$i].start -lt $ranges[$j].endExclusive -and $ranges[$j].start -lt $ranges[$i].endExclusive) {
            throw "Seed ranges overlap: $($ranges[$i].name) and $($ranges[$j].name)."
        }
    }
}

function Get-ComparisonHarnessDigest {
    $parts = foreach ($relative in @(
        'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt', 'cmd/main/main.mbt',
        'scripts/verify_seed.ps1', 'scripts/live_control_policy.ps1', 'scripts/run_live_control_campaign.ps1',
        'scripts/run_live_feedback_campaign_comparison.ps1', 'scripts/semantic_selection.ps1',
        'scripts/compare_semantic_selection.ps1', 'scripts/run_moongrammata_selection.ps1',
        'benchmarks/moongrammata_selection/cmd/main/main.mbt'
    )) {
        $path = Join-Path $projectRoot $relative
        "${relative}:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
function Get-SelectionHarnessDigest {
    $parts = foreach ($relative in @(
        'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt', 'cmd/main/main.mbt',
        'scripts/verify_seed.ps1', 'scripts/semantic_selection.ps1', 'scripts/compare_semantic_selection.ps1'
    )) {
        $path = Join-Path $projectRoot $relative
        "${relative}:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
$harnessDigestStart = Get-ComparisonHarnessDigest
$selectionDigestCurrent = Get-SelectionHarnessDigest
if ([string]$selection.harnessDigestStart -ne [string]$selection.harnessDigestEnd -or
    [string]$selection.harnessDigestEnd -ne $selectionDigestCurrent) {
    throw 'Selection configuration was created by a different or changing verifier harness; regenerate it before the three-arm run.'
}

$outputDirectory = if ($OutputPath) { Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath)) } else { Join-Path $projectRoot '.moonsmith\runs' }
if (-not $outputDirectory) { $outputDirectory = $projectRoot }
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$stem = if ($OutputPath) { [IO.Path]::GetFileNameWithoutExtension($OutputPath) } else { 'live_feedback_campaign_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') }
$sequentialPath = Join-Path $outputDirectory ($stem + '.sequential.json')
$guidedPath = Join-Path $outputDirectory ($stem + '.semantic-guided.json')
$moonGrammataPath = Join-Path $outputDirectory ($stem + '.moongrammata.json')
$poolPath = Join-Path $outputDirectory ($stem + '.configuration.json')
if ([IO.Path]::GetFullPath($selectionPath) -ne [IO.Path]::GetFullPath($poolPath)) {
    Copy-Item -LiteralPath $selectionPath -Destination $poolPath -Force
}

$controlRunner = Join-Path $PSScriptRoot 'run_live_control_campaign.ps1'
$null = & $controlRunner -Policy sequential -SeedStart $SequentialSeedStart -ProposalOrderSeed $SequentialProposalOrderSeed -ExecutionBudget $ExecutionBudget `
    -ProposalBatchSize $ProposalBatchSize -Targets $targets -Depth $depth -TimeoutSeconds $timeout -OutputPath $sequentialPath
if (-not (Test-Path -LiteralPath $sequentialPath)) { throw 'Sequential control did not write its raw result.' }
$null = & $controlRunner -Policy semantic-guided -SeedStart $SemanticGuidedSeedStart -ProposalOrderSeed $SemanticProposalOrderSeed -ExecutionBudget $ExecutionBudget `
    -ProposalBatchSize $ProposalBatchSize -Targets $targets -Depth $depth -TimeoutSeconds $timeout -OutputPath $guidedPath
if (-not (Test-Path -LiteralPath $guidedPath)) { throw 'Semantic-guided control did not write its raw result.' }

$moonGrammataRunner = Join-Path $PSScriptRoot 'run_moongrammata_selection.ps1'
$null = & $moonGrammataRunner -InputReport $poolPath -ExecutionBudget $ExecutionBudget `
    -Seed $MoonGrammataCampaignSeed -OutputPath $moonGrammataPath -LiveGeneratedSeeds `
    -GeneratedSeedMinimum $MoonGrammataSeedMinimum -GeneratedSeedMaximum $MoonGrammataSeedMaximum
if (-not (Test-Path -LiteralPath $moonGrammataPath)) { throw 'MoonGrammata live campaign did not write its raw result.' }

$sequential = Get-Content -LiteralPath $sequentialPath -Raw -Encoding utf8 | ConvertFrom-Json
$guided = Get-Content -LiteralPath $guidedPath -Raw -Encoding utf8 | ConvertFrom-Json
$moonGrammata = Get-Content -LiteralPath $moonGrammataPath -Raw -Encoding utf8 | ConvertFrom-Json
$live = $moonGrammata.moonGrammata
$expectedChecks = $ExecutionBudget * $targets.Count
$moonGrammataChecks = @($live.observations.backendRuns).Count
$targetStatusCounts = @{}
foreach ($observation in $live.observations) {
    foreach ($run in $observation.backendRuns) {
        $key = "{0}:{1}:{2}" -f $run.target, $run.status, $run.exitCode
        if (-not $targetStatusCounts.ContainsKey($key)) { $targetStatusCounts[$key] = 0 }
        $targetStatusCounts[$key]++
    }
}
$harnessDigestEnd = Get-ComparisonHarnessDigest
$harnessStable = $harnessDigestStart -eq $harnessDigestEnd -and
    [string]$selection.harnessDigestEnd -eq [string]$selection.harnessDigestStart -and
    [string]$selection.harnessDigestEnd -eq $selectionDigestCurrent
$result = [pscustomobject]@{
    schemaVersion = 1
    protocol = 'Three online campaigns with the same depth, target matrix, per-target timeout, requested case budget, and proposal-count budget for the two controls. Each arm uses a disjoint seed range and does not share verifier outcomes. Sequential and semantic-guided controls synchronously preflight fresh proposals; MoonGrammata synchronously verifies each generated/mutated integer seed inside its Target callback.'
    sourceConfigurationReport = $poolPath
    sourceConfigurationSha256 = (Get-FileHash -LiteralPath $poolPath -Algorithm SHA256).Hash.ToLowerInvariant()
    configuration = [pscustomobject]@{ targets=$targets; depth=$depth; timeoutSecondsPerTarget=$timeout; requestedCasesPerArm=$ExecutionBudget }
    backendCheckBudgetPerArm = $expectedChecks
    actualBackendChecks = [pscustomobject]@{ sequential=$sequential.backendChecks; semanticGuided=$guided.backendChecks; moonGrammata=$moonGrammataChecks }
    matchedActualBackendCheckBudget = ($sequential.backendChecks -eq $expectedChecks -and $guided.backendChecks -eq $expectedChecks -and $moonGrammataChecks -eq $expectedChecks)
    seedRanges = [pscustomobject]@{
        sequential = [pscustomobject]@{ start=$SequentialSeedStart; endExclusive=$sequentialEnd }
        semanticGuided = [pscustomobject]@{ start=$SemanticGuidedSeedStart; endExclusive=$guidedEnd }
        moonGrammata = [pscustomobject]@{ minimum=$MoonGrammataSeedMinimum; maximum=$MoonGrammataSeedMaximum; campaignSeed=$MoonGrammataCampaignSeed }
        proposalOrderSeeds = [pscustomobject]@{ sequential=$SequentialProposalOrderSeed; semanticGuided=$SemanticProposalOrderSeed }
        orderSeedsDistinctFromMoonGrammataCampaignSeed = $true
        disjoint = $true
    }
    sequential = [pscustomobject]@{
        reportPath=$sequentialPath; distinctReferencePathKinds=$sequential.distinctSelectedReferencePathKinds
        findings=$sequential.findings; backendExecutionAttempts=$sequential.backendExecutionAttempts
        proposalCount=$sequential.proposalCount; proposalGenerationDurationMs=$sequential.proposalGenerationDurationMs
        proposalReferenceEvaluationDurationMs=$sequential.proposalReferenceEvaluationDurationMs
        proposalReferenceTraceDurationMs=$sequential.proposalReferenceTraceDurationMs
        verifierWallClockMs=$sequential.selectedCandidateVerifierWallClockMs
        campaignWallClockMs=$sequential.campaignWallClockMs; cases=$sequential.perArmCases
    }
    semanticGuided = [pscustomobject]@{
        reportPath=$guidedPath; distinctReferencePathKinds=$guided.distinctSelectedReferencePathKinds
        findings=$guided.findings; backendExecutionAttempts=$guided.backendExecutionAttempts
        proposalCount=$guided.proposalCount; proposalGenerationDurationMs=$guided.proposalGenerationDurationMs
        proposalReferenceEvaluationDurationMs=$guided.proposalReferenceEvaluationDurationMs
        proposalReferenceTraceDurationMs=$guided.proposalReferenceTraceDurationMs
        verifierWallClockMs=$guided.selectedCandidateVerifierWallClockMs
        campaignWallClockMs=$guided.campaignWallClockMs; cases=$guided.perArmCases
    }
    moonGrammata = [pscustomobject]@{
        reportPath=$moonGrammataPath; generatorMode=$live.generatorMode
        selectedSeeds=@($live.selectedSeeds); uniqueSelectedSeeds=$live.uniqueCandidatesObserved
        callbackCount=$live.liveEvaluations; referenceChecks=$live.liveReferenceChecks
        generatorLimitObservations=$live.liveGeneratorLimitObservations
        distinctReferencePathKinds=$live.distinctReferencePathKinds; findings=@($live.liveFindings)
        backendStatuses=$targetStatusCounts; backendExecutionAttempts=$live.liveBackendExecutions
        generationDurationMs=$live.liveGenerationDurationMs
        referenceEvaluationDurationMs=$live.liveReferenceEvaluationDurationMs
        referenceTraceDurationMs=$live.liveReferenceTraceDurationMs
        backendBuildAndExecutionDurationMs=$live.liveBackendBuildAndExecutionDurationMs
        verifierWallClockMs=$live.liveVerifierDurationMs; campaignWallClockMs=$live.liveCampaignWallClockMs
        observations=@($live.observations)
    }
    harnessDigestStart=$harnessDigestStart; harnessDigestEnd=$harnessDigestEnd
    selectionHarnessDigestExpected=$selection.harnessDigestEnd
    selectionHarnessDigestCurrent=$selectionDigestCurrent
    harnessChangedDuringRun=(-not $harnessStable)
    wallClockThroughputClaimAllowed=$false
    interpretation = if (-not $harnessStable) {
        'Invalid comparison: harness changed during this run or the configuration report was produced by a different harness revision.'
    } elseif ($moonGrammataChecks -ne $expectedChecks) {
        'Backend-check budgets did not match because one or more MoonGrammata callbacks did not reach every configured backend (for example, generator-limit outcomes). Preserve the raw report, but do not treat the arms as matched.'
    } else {
        'Exploratory online feedback comparison only. The controls use fresh candidate preflight traces and sequential feedback across rounds; MoonGrammata receives synchronous per-callback feedback. The seed ranges are disjoint and random behavior is not paired. Preflight work and wall-clock are reported; this does not establish general fuzzer effectiveness or throughput superiority.'
    }
    rawArtifacts = @($sequentialPath, $guidedPath, $moonGrammataPath, ($moonGrammataPath + '.artifacts'), $poolPath)
}
$json = $result | ConvertTo-Json -Depth 14
if ($OutputPath) {
    $resolved = [IO.Path]::GetFullPath($OutputPath)
    [IO.File]::WriteAllText($resolved, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
}
$json
