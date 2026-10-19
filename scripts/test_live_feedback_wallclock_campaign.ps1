$ErrorActionPreference = 'Stop'
$selectionRunner = Join-Path $PSScriptRoot 'compare_semantic_selection.ps1'
$campaignRunner = Join-Path $PSScriptRoot 'run_live_feedback_wallclock_campaign.ps1'
$mockWorker = Join-Path $PSScriptRoot 'testdata\mock_wallclock_arm_worker.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ('moonsmith-wallclock-campaign-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $selectionPath = Join-Path $testRoot 'configuration.json'
    $null = & $selectionRunner -SeedStart 410000 -CandidateCount 4 -ExecutionBudget 2 `
        -Depth 0 -Targets @('js') -TimeoutSeconds 30 -OutputPath $selectionPath
    if (-not (Test-Path -LiteralPath $selectionPath)) { throw 'Selection configuration did not write its raw report.' }

    $balancedPath = Join-Path $testRoot 'balanced.json'
    $null = & $campaignRunner -SelectionReport $selectionPath `
        -SequentialSeedStart 420000 -SemanticGuidedSeedStart 430000 `
        -MoonGrammataSeedMinimum 440000 -MoonGrammataSeedMaximum 440001 `
        -WallClockBudgetSecondsPerArm 2 -ProposalBatchSize 2 -MaximumAttemptsPerArm 2 `
        -SequentialProposalOrderSeed 10 -SemanticProposalOrderSeed 20 -MoonGrammataCampaignSeed 30 `
        -RoundRobinOrderSeed 40 -OutputPath $balancedPath -WorkerOverrideForTests $mockWorker `
        -MockWorkerDelayMilliseconds 25
    $balanced = Get-Content -LiteralPath $balancedPath -Raw -Encoding utf8 | ConvertFrom-Json
    $checkpointPath = $balancedPath + '.checkpoint.json'
    $checkpoint = Get-Content -LiteralPath $checkpointPath -Raw -Encoding utf8 | ConvertFrom-Json
    if (-not $balanced.equalWallClockBudgetConfigured -or $balanced.configuration.wallClockBudgetSecondsPerArm -ne 2 -or
        $balanced.taskOrder.Count -ne 6 -or $balanced.arms.sequential.completedCases -ne 2 -or
        $balanced.arms.semanticGuided.completedCases -ne 2 -or $balanced.arms.moonGrammata.completedCases -ne 2 -or
        $balanced.arms.sequential.candidateOrCallbackCount -ne 4 -or
        $balanced.arms.semanticGuided.candidateOrCallbackCount -ne 4 -or
        $balanced.arms.moonGrammata.candidateOrCallbackCount -ne 2 -or
        $balanced.arms.sequential.backendCheckCount -ne 2 -or
        $balanced.arms.semanticGuided.backendCheckCount -ne 2 -or
        $balanced.arms.moonGrammata.backendCheckCount -ne 2 -or
        -not $checkpoint.completed -or $balanced.rawCaseReports.Count -ne 6) {
        throw 'Round-robin scheduler did not preserve reports or accurately aggregate candidates, callbacks, and backend checks.'
    }
    foreach ($round in 0,1) {
        $roundOrder = @($balanced.taskOrder | Where-Object round -eq $round | ForEach-Object { $_.arm })
        if ($roundOrder.Count -ne 3 -or @($roundOrder | Select-Object -Unique).Count -ne 3) {
            throw "Scheduler round $round must run each active arm exactly once before rotating."
        }
    }
    $firstOrder = @($balanced.taskOrder | Where-Object round -eq 0 | ForEach-Object { $_.arm })
    $secondOrder = @($balanced.taskOrder | Where-Object round -eq 1 | ForEach-Object { $_.arm })
    if ($firstOrder[0] -eq $secondOrder[0]) { throw 'The arm that runs first must rotate between rounds.' }
    $firstSemanticPaths = @($balanced.arms.semanticGuided.cases[0].report.perArmCases[0].referencePathKinds)
    $secondSemanticSeen = @($balanced.arms.semanticGuided.cases[1].report.perArmCases[0].seenPathKindsBeforeSelection)
    if ($firstSemanticPaths.Count -eq 0 -or
        @($firstSemanticPaths | Where-Object { $secondSemanticSeen -contains $_ }).Count -ne $firstSemanticPaths.Count) {
        throw 'Semantic-guided novelty state must carry the prior selected candidate paths across isolated child processes.'
    }

    $timeoutPath = Join-Path $testRoot 'censored.json'
    $null = & $campaignRunner -SelectionReport $selectionPath `
        -SequentialSeedStart 450000 -SemanticGuidedSeedStart 460000 `
        -MoonGrammataSeedMinimum 470000 -MoonGrammataSeedMaximum 470004 `
        -WallClockBudgetSecondsPerArm 1 -ProposalBatchSize 1 -MaximumAttemptsPerArm 5 `
        -SequentialProposalOrderSeed 11 -SemanticProposalOrderSeed 21 -MoonGrammataCampaignSeed 31 `
        -RoundRobinOrderSeed 41 -OutputPath $timeoutPath -WorkerOverrideForTests $mockWorker `
        -MockWorkerDelayMilliseconds 5000
    $censored = Get-Content -LiteralPath $timeoutPath -Raw -Encoding utf8 | ConvertFrom-Json
    if (-not $censored.anyCensored -or
        -not $censored.arms.sequential.timedOut -or -not $censored.arms.semanticGuided.timedOut -or
        -not $censored.arms.moonGrammata.timedOut -or
        @($censored.taskOrder | Where-Object { $_.arm -eq 'sequential' }).Count -ne 1 -or
        @($censored.taskOrder | Where-Object { $_.arm -eq 'semanticGuided' }).Count -ne 1 -or
        @($censored.taskOrder | Where-Object { $_.arm -eq 'moonGrammata' }).Count -ne 1) {
        throw 'A worker that exceeds its arm wall-clock budget must be killed, censored, and not restarted as a new sample.'
    }
    foreach ($reportArtifact in $censored.rawCaseReports) {
        if (-not (Test-Path -LiteralPath $reportArtifact.path) -or
            (Get-FileHash -LiteralPath $reportArtifact.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $reportArtifact.sha256) {
            throw "Missing or changed preserved case-level report: $($reportArtifact.path)"
        }
    }

    $resumeMismatchRejected = $false
    try {
        $null = & $campaignRunner -SelectionReport $selectionPath `
            -SequentialSeedStart 450000 -SemanticGuidedSeedStart 460000 `
            -MoonGrammataSeedMinimum 470000 -MoonGrammataSeedMaximum 470004 `
            -WallClockBudgetSecondsPerArm 2 -ProposalBatchSize 1 -MaximumAttemptsPerArm 5 `
            -SequentialProposalOrderSeed 11 -SemanticProposalOrderSeed 21 -MoonGrammataCampaignSeed 31 `
            -RoundRobinOrderSeed 41 -OutputPath $timeoutPath -WorkerOverrideForTests $mockWorker `
            -MockWorkerDelayMilliseconds 5000 -Resume
    } catch {
        if ($_.Exception.Message -notlike '*Resume parameters do not match*') { throw }
        $resumeMismatchRejected = $true
    }
    if (-not $resumeMismatchRejected) { throw 'Resume must reject a checkpoint whose wall-clock budget differs.' }

    $interruptedPath = Join-Path $testRoot 'interrupted.json'
    $powershellExe = (Get-Command pwsh -ErrorAction Stop).Source
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $powershellExe; $startInfo.WorkingDirectory = (Split-Path -Parent $PSScriptRoot)
    $startInfo.UseShellExecute = $false; $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true; $startInfo.RedirectStandardError = $true
    $arguments = @('-NoProfile','-File',$campaignRunner,'-SelectionReport',$selectionPath,
        '-SequentialSeedStart','480000','-SemanticGuidedSeedStart','490000',
        '-MoonGrammataSeedMinimum','500000','-MoonGrammataSeedMaximum','500001',
        '-WallClockBudgetSecondsPerArm','2','-ProposalBatchSize','1','-MaximumAttemptsPerArm','2',
        '-SequentialProposalOrderSeed','61','-SemanticProposalOrderSeed','71','-MoonGrammataCampaignSeed','81',
        '-RoundRobinOrderSeed','91','-OutputPath',$interruptedPath,'-WorkerOverrideForTests',$mockWorker,
        '-MockWorkerDelayMilliseconds','5000')
    foreach ($argument in $arguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $parentProcess = [Diagnostics.Process]::new(); $parentProcess.StartInfo = $startInfo
    if (-not $parentProcess.Start()) { throw 'Could not start the resumability test process.' }
    $parentStdout = $parentProcess.StandardOutput.ReadToEndAsync(); $parentStderr = $parentProcess.StandardError.ReadToEndAsync()
    $interruptCheckpoint = $interruptedPath + '.checkpoint.json'
    $activeObserved = $false
    for ($wait = 0; $wait -lt 100; $wait++) {
        Start-Sleep -Milliseconds 50
        if (Test-Path -LiteralPath $interruptCheckpoint) {
            try {
                $pending = Get-Content -LiteralPath $interruptCheckpoint -Raw -Encoding utf8 | ConvertFrom-Json
                if ($pending.activeTask.processId) { $activeObserved = $true; break }
            } catch { }
        }
        if ($parentProcess.HasExited) { break }
    }
    if (-not $activeObserved) { if (-not $parentProcess.HasExited) { $parentProcess.Kill($true) }; throw 'Campaign did not durably checkpoint an active worker.' }
    $interruptedArm = [string]$pending.activeTask.arm
    $parentProcess.Kill()
    $parentProcess.WaitForExit()
    $null = $parentStdout.GetAwaiter().GetResult(); $null = $parentStderr.GetAwaiter().GetResult()
    $parentProcess.Dispose()
    $checkpointOriginal = Get-Content -LiteralPath $interruptCheckpoint -Raw -Encoding utf8
    $staleHarnessCheckpoint = $checkpointOriginal | ConvertFrom-Json -AsHashtable
    $staleHarnessCheckpoint.harnessDigestStart = 'intentionally-stale'
    [IO.File]::WriteAllText($interruptCheckpoint,
        ($staleHarnessCheckpoint | ConvertTo-Json -Depth 18) + [Environment]::NewLine,
        [Text.UTF8Encoding]::new($false))
    $resumeHarnessMismatchRejected = $false
    try {
        $null = & $campaignRunner -SelectionReport $selectionPath `
            -SequentialSeedStart 480000 -SemanticGuidedSeedStart 490000 `
            -MoonGrammataSeedMinimum 500000 -MoonGrammataSeedMaximum 500001 `
            -WallClockBudgetSecondsPerArm 2 -ProposalBatchSize 1 -MaximumAttemptsPerArm 2 `
            -SequentialProposalOrderSeed 61 -SemanticProposalOrderSeed 71 -MoonGrammataCampaignSeed 81 `
            -RoundRobinOrderSeed 91 -OutputPath $interruptedPath -WorkerOverrideForTests $mockWorker `
            -MockWorkerDelayMilliseconds 5000 -Resume
    } catch {
        if ($_.Exception.Message -notlike '*Resume harness inputs do not match*') { throw }
        $resumeHarnessMismatchRejected = $true
    }
    if (-not $resumeHarnessMismatchRejected) { throw 'Resume must reject a checkpoint produced by a different harness digest.' }
    [IO.File]::WriteAllText($interruptCheckpoint,$checkpointOriginal,[Text.UTF8Encoding]::new($false))
    $null = & $campaignRunner -SelectionReport $selectionPath `
        -SequentialSeedStart 480000 -SemanticGuidedSeedStart 490000 `
        -MoonGrammataSeedMinimum 500000 -MoonGrammataSeedMaximum 500001 `
        -WallClockBudgetSecondsPerArm 2 -ProposalBatchSize 1 -MaximumAttemptsPerArm 2 `
        -SequentialProposalOrderSeed 61 -SemanticProposalOrderSeed 71 -MoonGrammataCampaignSeed 81 `
        -RoundRobinOrderSeed 91 -OutputPath $interruptedPath -WorkerOverrideForTests $mockWorker `
        -MockWorkerDelayMilliseconds 5000 -Resume
    $resumed = Get-Content -LiteralPath $interruptedPath -Raw -Encoding utf8 | ConvertFrom-Json
    $resumedArm = $resumed.arms.PSObject.Properties[$interruptedArm].Value
    if (-not $resumed.resumedAfterParentInterruption -or -not $resumed.anyCensored -or
        $resumed.wallClockUsageWithinOneSecondOfBudget -or
        $resumed.interpretation -notlike '*resumed after interruption*' -or
        -not $resumedArm.timedOut) {
        throw 'Resume did not preserve earlier checkpoints and conservatively censor the interrupted in-flight task.'
    }

    [pscustomobject]@{
        passed=$true; arms=3; roundRobinInterleaving=$true; processStartupAndWorkCharged=$true
        equalPerArmBudgetConfigured=$true; timeoutRecordedAsCensored=$true; censoredAttemptNotRetried=$true
        perCaseRawReportsPreserved=$true; atomicCheckpointWritten=$true; mismatchedResumeRejected=$true
        interruptedWorkerConservativelyCensored=$true; priorCompletedCasesRecoverable=$true; orderRotatesByRound=$true
        semanticFeedbackStateCarriedAcrossCases=$true; staleHarnessResumeRejected=$true
        testWorkerOnly=$true
    } | ConvertTo-Json -Compress
}
finally {
    Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
