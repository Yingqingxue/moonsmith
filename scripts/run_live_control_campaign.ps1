param(
    [Parameter(Mandatory)][ValidateSet('sequential', 'semantic-guided')][string]$Policy,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$SeedStart,
    [Parameter()][ValidateRange(0, 2147483647)][int]$ProposalOrderSeed = 0,
    [Parameter()][ValidateRange(1, 1000)][int]$ExecutionBudget = 6,
    [Parameter()][ValidateRange(1, 20)][int]$ProposalBatchSize = 4,
    [Parameter()][ValidateSet('js', 'wasm', 'wasm-gc', 'native', 'native-release')][string[]]$Targets = @('js', 'wasm', 'wasm-gc'),
    [Parameter()][string]$TargetsCsv = '',
    [Parameter()][string]$InitialSeenPathKindsCsv = '',
    [Parameter()][ValidateRange(0, 12)][int]$Depth = 2,
    [Parameter()][ValidateRange(1, 300)][int]$TimeoutSeconds = 30,
    [Parameter()][string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
if ($TargetsCsv) {
    if ($PSBoundParameters.ContainsKey('Targets')) { throw 'Specify either Targets or TargetsCsv, not both.' }
    $Targets = @($TargetsCsv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}
foreach ($target in $Targets) {
    if ($target -notin @('js', 'wasm', 'wasm-gc', 'native', 'native-release')) { throw "Unsupported target: $target" }
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$moonExe = (Get-Command moon -ErrorAction Stop).Source
$powerShell = (Get-Command pwsh -ErrorAction Stop).Source
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
$policyScript = Join-Path $PSScriptRoot 'live_control_policy.ps1'
. $policyScript
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('moonsmith-live-control-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
$campaignTimer = [Diagnostics.Stopwatch]::StartNew()
$seenPathKinds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
foreach ($pathKind in @($InitialSeenPathKindsCsv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })) {
    [void]$seenPathKinds.Add([string]$pathKind)
}
$seedStream = [int[]]@($SeedStart..([int]([long]$SeedStart + ([long]$ExecutionBudget * $ProposalBatchSize) - 1)))
$seedOrderRandom = [Random]::new($ProposalOrderSeed)
for ($shuffleIndex = $seedStream.Length - 1; $shuffleIndex -gt 0; $shuffleIndex--) {
    $swapIndex = $seedOrderRandom.Next($shuffleIndex + 1)
    $swapValue = $seedStream[$shuffleIndex]
    $seedStream[$shuffleIndex] = $seedStream[$swapIndex]
    $seedStream[$swapIndex] = $swapValue
}
$proposals = [Collections.Generic.List[object]]::new()
$cases = [Collections.Generic.List[object]]::new()
$generationMs = 0L
$referenceEvaluationMs = 0L
$referenceTraceMs = 0L
$verifyWallMs = 0L
$generatorLimits = 0
$totalBackendChecks = 0
$backendExecutionAttempts = 0
$sourceLimit = 16300
if ([long]$SeedStart + ([long]$ExecutionBudget * [long]$ProposalBatchSize) -gt [int]::MaxValue) {
    throw 'Proposal seed window exceeds the supported Int32 seed range.'
}

function Invoke-CapturedProcess {
    param([string]$FilePath, [string[]]$Arguments, [int]$LimitSeconds)
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) { throw "Failed to start process: $FilePath" }
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($LimitSeconds * 1000)
    if ($timedOut) { $process.Kill($true); $process.WaitForExit() }
    $timer.Stop()
    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    $process.Dispose()
    [pscustomobject]@{ exitCode=$exitCode; timedOut=$timedOut; stdout=$stdout; stderr=$stderr; durationMs=$timer.ElapsedMilliseconds }
}

function Invoke-MoonProbe {
    param([int]$CandidateSeed, [string[]]$ExtraArguments)
    $arguments = @('run', '--target', 'js', 'cmd/main', [string]$CandidateSeed, [string]$Depth) + $ExtraArguments
    Invoke-CapturedProcess -FilePath $moonExe -Arguments $arguments -LimitSeconds $TimeoutSeconds
}

try {
    for ($slot = 0; $slot -lt $ExecutionBudget; $slot++) {
        $window = [Collections.Generic.List[object]]::new()
        for ($ordinal = 0; $ordinal -lt $ProposalBatchSize; $ordinal++) {
            $candidateSeed = $seedStream[($slot * $ProposalBatchSize) + $ordinal]
            $generated = Invoke-MoonProbe -CandidateSeed $candidateSeed -ExtraArguments @()
            $generationMs += $generated.durationMs
            $proposal = [ordered]@{
                seed = $candidateSeed; proposalOrdinal = $ordinal; preflightStatus = 'checked'
                generationDurationMs = $generated.durationMs; referenceEvaluationDurationMs = 0L
                referenceTraceDurationMs = 0L; sourceLineCount = 0; sourceSizeBand = ''
                referencePathKinds = @(); preflightError = $null
            }
            if ($generated.timedOut -or $generated.exitCode -ne 0) {
                $proposal.preflightStatus = if ($generated.timedOut) { 'generation-timeout' } else { 'generation-failed' }
                $proposal.preflightError = ($generated.stderr + "`n" + $generated.stdout).Trim()
                $proposals.Add([pscustomobject]$proposal)
                $window.Add([pscustomobject]$proposal)
                continue
            }

            $source = $generated.stdout.TrimEnd("`r", "`n") + "`n"
            $sourcePath = Join-Path $testRoot "candidate_${candidateSeed}.mbt"
            [IO.File]::WriteAllText($sourcePath, $source, [Text.UTF8Encoding]::new($false))
            $proposal.sourcePath = $sourcePath
            $sourceLineCount = [regex]::Matches($source, "`n").Count
            $proposal.sourceLineCount = $sourceLineCount
            $proposal.sourceSizeBand = Get-LiveControlSizeBand -SourceLineCount $sourceLineCount
            if ($sourceLineCount -gt $sourceLimit) {
                $proposal.preflightStatus = 'generator-limit'
                $generatorLimits++
                $proposals.Add([pscustomobject]$proposal)
                $window.Add([pscustomobject]$proposal)
                continue
            }

            $tracePath = Join-Path $testRoot "candidate_${candidateSeed}.trace.json"
            $expectedPath = Join-Path $testRoot "candidate_${candidateSeed}.expected.txt"
            $expected = Invoke-MoonProbe -CandidateSeed $candidateSeed -ExtraArguments @('--expected')
            $referenceEvaluationMs += $expected.durationMs
            $proposal.referenceEvaluationDurationMs = $expected.durationMs
            if ($expected.timedOut -or $expected.exitCode -ne 0) {
                $proposal.preflightStatus = if ($expected.timedOut) { 'reference-timeout' } else { 'reference-failed' }
                $proposal.preflightError = ($expected.stderr + "`n" + $expected.stdout).Trim()
                $proposals.Add([pscustomobject]$proposal)
                $window.Add([pscustomobject]$proposal)
                continue
            }
            $trace = Invoke-MoonProbe -CandidateSeed $candidateSeed -ExtraArguments @('--trace')
            $referenceTraceMs += $trace.durationMs
            $proposal.referenceTraceDurationMs = $trace.durationMs
            if ($trace.timedOut -or $trace.exitCode -ne 0) {
                $proposal.preflightStatus = if ($trace.timedOut) { 'trace-timeout' } else { 'trace-failed' }
                $proposal.preflightError = ($trace.stderr + "`n" + $trace.stdout).Trim()
                $proposals.Add([pscustomobject]$proposal)
                $window.Add([pscustomobject]$proposal)
                continue
            }
            $traceObject = $trace.stdout | ConvertFrom-Json
            if ($null -eq $traceObject.visited) { throw "Trace for seed $candidateSeed omitted visited paths." }
            $proposal.referencePathKinds = @($traceObject.visited | ForEach-Object { [string]$_ } | Sort-Object -Unique)
            $proposal.expectedOutput = $expected.stdout
            [IO.File]::WriteAllText($expectedPath, $expected.stdout, [Text.UTF8Encoding]::new($false))
            $proposal.expectedOutputPath = $expectedPath
            $proposal.sourcePath = $sourcePath
            $proposal.referenceTracePath = $tracePath
            [IO.File]::WriteAllText($tracePath, ($traceObject | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
            $proposals.Add([pscustomobject]$proposal)
            $window.Add([pscustomobject]$proposal)
        }

        $seenBeforeSelection = @($seenPathKinds | Sort-Object)
        $decision = Select-LiveControlCandidate -Candidates $window.ToArray() -Policy $Policy -SeenPathKinds $seenPathKinds
        $selected = $decision.candidate
        $newSelectedPathKinds = @($selected.referencePathKinds | Where-Object { -not $seenPathKinds.Contains([string]$_) } | Sort-Object -Unique)
        $verifyArgs = @('-NoProfile', '-File', $verifyScript, '-Seed', [string]$selected.seed,
            '-Depth', [string]$Depth, '-TimeoutSeconds', [string]$TimeoutSeconds,
            '-SourcePath', [string]$selected.sourcePath, '-ExpectedOutputPath', [string]$selected.expectedOutputPath,
            '-ReferenceTracePath', [string]$selected.referenceTracePath, '-NoPersist', '-TargetsCsv', ($Targets -join ',') )
        $verificationTimer = [Diagnostics.Stopwatch]::StartNew()
        $verification = Invoke-CapturedProcess -FilePath $powerShell -Arguments $verifyArgs -LimitSeconds ([Math]::Max(60, ($TimeoutSeconds * $Targets.Count) + 30))
        $verificationTimer.Stop()
        $verifyWallMs += $verificationTimer.ElapsedMilliseconds
        if ($verification.exitCode -notin @(0, 1)) {
            throw "Verifier process failed for selected seed $($selected.seed): $($verification.stderr) $($verification.stdout)"
        }
        $report = $verification.stdout | ConvertFrom-Json
        if ([string]$report.sourceSha256 -ne (Get-FileHash -LiteralPath $selected.sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()) {
            throw "Verifier source hash did not match the preflight candidate for seed $($selected.seed)."
        }
        $verifiedPathKinds = @($report.referenceTrace.visited | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $proposalPathKinds = @($selected.referencePathKinds | ForEach-Object { [string]$_ } | Sort-Object -Unique)
        $traceMatches = ($verifiedPathKinds -join "`n") -ceq ($proposalPathKinds -join "`n")
        $expectedOutputMatches = [string]$report.expectedOutput -ceq [string]$selected.expectedOutput
        if (-not $report.referenceChecked -or -not $expectedOutputMatches -or -not $traceMatches) {
            throw "Verifier evidence mismatch for seed $($selected.seed): referenceChecked=$($report.referenceChecked), expectedMatches=$expectedOutputMatches, traceMatches=$traceMatches, verifierPaths='$($verifiedPathKinds -join ',')', probePaths='$($proposalPathKinds -join ',')', expectedLength=$([string]$selected.expectedOutput).Length, verifiedLength=$([string]$report.expectedOutput).Length."
        }
        $backendRuns = @($report.runs)
        if ($backendRuns.Count -ne $Targets.Count) { throw "Verifier did not record one backend check per target for seed $($selected.seed)." }
        $totalBackendChecks += $backendRuns.Count
        $backendExecutionAttempts += @($backendRuns | Where-Object { $_.executionAttempted }).Count
        $case = [pscustomobject]@{
            round = $slot; policy = $Policy; seed = [int]$selected.seed
            proposalOrderSeed = $ProposalOrderSeed
            proposalWindowSeeds = @($window | ForEach-Object { [int]$_.seed })
            proposalWindowStatuses = @($window | ForEach-Object { "{0}:{1}" -f $_.seed, $_.preflightStatus })
            selectionRule = $decision.selectionRule; noveltyScore = $decision.noveltyScore
            novelPathKindCount = $decision.novelPathKindCount
            sourceLineCount = $selected.sourceLineCount
            sourceSizeBand = $selected.sourceSizeBand
            sourceSha256 = [string]$report.sourceSha256
            referencePathKinds = @($selected.referencePathKinds)
            seenPathKindsBeforeSelection = $seenBeforeSelection
            newlyCoveredPathKinds = $newSelectedPathKinds
            referenceChecked = [bool]$report.referenceChecked
            finding = [string]$report.finding
            backendStatuses = @($backendRuns | ForEach-Object { "{0}:{1}:{2}" -f $_.target, $_.status, $_.exitCode })
            backendRuns = $backendRuns
            verifierWallClockMs = $verificationTimer.ElapsedMilliseconds
        }
        $cases.Add($case)
        foreach ($pathKind in $selected.referencePathKinds) { [void]$seenPathKinds.Add([string]$pathKind) }
    }
    $campaignTimer.Stop()
    if ($totalBackendChecks -ne ($ExecutionBudget * $Targets.Count)) {
        throw "Backend check budget mismatch: $totalBackendChecks vs $($ExecutionBudget * $Targets.Count)."
    }
    $findingCounts = @{}
    foreach ($case in $cases) {
        if (-not $findingCounts.ContainsKey($case.finding)) { $findingCounts[$case.finding] = 0 }
        $findingCounts[$case.finding]++
    }
    $artifactDirectory = $null
    $artifactDirectoryForReport = $null
    if ($OutputPath) {
        $resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
        $artifactDirectory = $resolvedOutput + '.artifacts'
        New-Item -ItemType Directory -Force -Path $artifactDirectory | Out-Null
        foreach ($artifact in Get-ChildItem -LiteralPath $testRoot -File) {
            Copy-Item -LiteralPath $artifact.FullName -Destination (Join-Path $artifactDirectory $artifact.Name) -Force
        }
        foreach ($proposal in $proposals) {
            if ($proposal.sourcePath) { $proposal.sourcePath = Join-Path $artifactDirectory ([IO.Path]::GetFileName($proposal.sourcePath)) }
            if ($proposal.referenceTracePath) { $proposal.referenceTracePath = Join-Path $artifactDirectory ([IO.Path]::GetFileName($proposal.referenceTracePath)) }
            if ($proposal.expectedOutputPath) { $proposal.expectedOutputPath = Join-Path $artifactDirectory ([IO.Path]::GetFileName($proposal.expectedOutputPath)) }
        }
        $artifactDirectoryForReport = $artifactDirectory
    }
    $result = [pscustomobject]@{
        schemaVersion = 1; arm = $Policy; selectionImplementation = 'live-control-policy-v1'
        selectionRule = if ($Policy -eq 'sequential') { 'first valid candidate in each ascending seed window' } else { 'maximum unseen reference-path kinds per source line within first valid candidate size band; ties by count then ascending seed' }
        seedStart = $SeedStart; seedEndExclusive = $SeedStart + ($ExecutionBudget * $ProposalBatchSize)
        proposalOrderSeed = $ProposalOrderSeed
        initialSeenPathKinds = @($InitialSeenPathKindsCsv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Sort-Object -Unique)
        executionBudget = $ExecutionBudget; proposalBatchSize = $ProposalBatchSize
        proposalCount = $proposals.Count; selectedCount = $cases.Count
        configuredTargets = @($Targets); depth = $Depth; timeoutSecondsPerTarget = $TimeoutSeconds
        backendChecks = $totalBackendChecks; backendExecutionAttempts = $backendExecutionAttempts
        distinctSelectedReferencePathKinds = $seenPathKinds.Count; findings = $findingCounts
        generatorLimitProposals = $generatorLimits
        proposalGenerationDurationMs = $generationMs
        proposalReferenceEvaluationDurationMs = $referenceEvaluationMs
        proposalReferenceTraceDurationMs = $referenceTraceMs
        selectedCandidateVerifierWallClockMs = $verifyWallMs
        campaignWallClockMs = $campaignTimer.ElapsedMilliseconds
        candidateProposalWorkIsChargedToCampaign = $true
        artifactDirectory = $artifactDirectoryForReport
        candidateSourcesAndReferenceTracesPreserved = [bool]$artifactDirectory
        semanticFeedbackUsesOnlyPreviouslySelectedReferencePaths = ($Policy -eq 'semantic-guided')
        selectedSourceSizeBandCounts = @($cases | Group-Object sourceSizeBand | ForEach-Object { [pscustomobject]@{ band=$_.Name; count=$_.Count } })
        perArmCases = @($cases); proposalOutcomes = @($proposals)
        toolchainVersion = (& $moonExe version | Select-Object -First 1)
        caveat = 'Equal proposal count, backend-check budget, target matrix, depth, and per-target timeout are enforced per arm. Candidate preflight generation/reference/trace runs add cost and are reported. The proposal order is deterministically shuffled from the recorded per-arm seed; arms use disjoint candidate seed windows and separate order seeds, and share no candidate or backend results. No equal wall-clock throughput claim is implied.'
    }
    $json = $result | ConvertTo-Json -Depth 12
    if ($OutputPath) {
        $resolvedOutput = [IO.Path]::GetFullPath($OutputPath)
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $resolvedOutput) | Out-Null
        [IO.File]::WriteAllText($resolvedOutput, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    }
    $json
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
