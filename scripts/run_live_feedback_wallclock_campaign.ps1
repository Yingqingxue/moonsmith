param(
    [Parameter(Mandatory)][string]$SelectionReport,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$SequentialSeedStart,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$SemanticGuidedSeedStart,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$MoonGrammataSeedMinimum,
    [Parameter(Mandatory)][ValidateRange(0, 2147483647)][int]$MoonGrammataSeedMaximum,
    [Parameter()][ValidateRange(1, 3600)][int]$WallClockBudgetSecondsPerArm = 60,
    [Parameter()][ValidateRange(1, 20)][int]$ProposalBatchSize = 4,
    [Parameter()][ValidateRange(1, 10000)][int]$MaximumAttemptsPerArm = 1000,
    [Parameter()][ValidateRange(0, 2147483647)][int]$SequentialProposalOrderSeed = 20261020,
    [Parameter()][ValidateRange(0, 2147483647)][int]$SemanticProposalOrderSeed = 20261021,
    [Parameter()][long]$MoonGrammataCampaignSeed = 20261019,
    [Parameter()][ValidateRange(0, 2147483647)][int]$RoundRobinOrderSeed = 20261022,
    [Parameter()][string]$OutputPath = '',
    [Parameter()][switch]$Resume,
    [Parameter()][string]$WorkerOverrideForTests = '',
    [Parameter()][ValidateRange(0, 60000)][int]$MockWorkerDelayMilliseconds = 0
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
$targetTimeout = [int]$selection.timeoutSeconds
if ($targets.Count -eq 0 -or @($targets | Select-Object -Unique).Count -ne $targets.Count) {
    throw 'The selection report must have a nonempty unique target matrix.'
}
if ($MoonGrammataSeedMaximum -lt $MoonGrammataSeedMinimum -or
    ([long]$MoonGrammataSeedMaximum - [long]$MoonGrammataSeedMinimum + 1) -lt $MaximumAttemptsPerArm) {
    throw 'MoonGrammata seed range must cover MaximumAttemptsPerArm.'
}
if ($SequentialProposalOrderSeed -eq $SemanticProposalOrderSeed -or
    [long]$MoonGrammataCampaignSeed -eq [long]$SequentialProposalOrderSeed -or
    [long]$MoonGrammataCampaignSeed -eq [long]$SemanticProposalOrderSeed) {
    throw 'All arm and proposal-order seed streams must be independent.'
}
$sequentialEnd = [long]$SequentialSeedStart + ([long]$MaximumAttemptsPerArm * $ProposalBatchSize)
$guidedEnd = [long]$SemanticGuidedSeedStart + ([long]$MaximumAttemptsPerArm * $ProposalBatchSize)
if ($sequentialEnd -gt [int]::MaxValue -or $guidedEnd -gt [int]::MaxValue) { throw 'Control seed range exceeds Int32.' }
if (([long]$SequentialProposalOrderSeed + $MaximumAttemptsPerArm - 1) -gt [int]::MaxValue -or
    ([long]$SemanticProposalOrderSeed + $MaximumAttemptsPerArm - 1) -gt [int]::MaxValue) {
    throw 'Per-case proposal-order seed range exceeds Int32.'
}
if ($MoonGrammataCampaignSeed -gt ([long]::MaxValue - $MaximumAttemptsPerArm)) { throw 'MoonGrammata campaign seed range exceeds Int64.' }
$ranges = @(
    [pscustomobject]@{ name='sequential'; start=[long]$SequentialSeedStart; endExclusive=$sequentialEnd },
    [pscustomobject]@{ name='semantic-guided'; start=[long]$SemanticGuidedSeedStart; endExclusive=$guidedEnd },
    [pscustomobject]@{ name='moongrammata'; start=[long]$MoonGrammataSeedMinimum; endExclusive=([long]$MoonGrammataSeedMaximum + 1) },
    [pscustomobject]@{ name='sequential-order-seed'; start=[long]$SequentialProposalOrderSeed; endExclusive=([long]$SequentialProposalOrderSeed + $MaximumAttemptsPerArm) },
    [pscustomobject]@{ name='semantic-order-seed'; start=[long]$SemanticProposalOrderSeed; endExclusive=([long]$SemanticProposalOrderSeed + $MaximumAttemptsPerArm) },
    [pscustomobject]@{ name='moongrammata-campaign-seed'; start=[long]$MoonGrammataCampaignSeed; endExclusive=([long]$MoonGrammataCampaignSeed + $MaximumAttemptsPerArm) },
    [pscustomobject]@{ name='round-robin-order-seed'; start=[long]$RoundRobinOrderSeed; endExclusive=([long]$RoundRobinOrderSeed + 1) }
)
for ($i = 0; $i -lt $ranges.Count; $i++) {
    for ($j = $i + 1; $j -lt $ranges.Count; $j++) {
        if ($ranges[$i].start -lt $ranges[$j].endExclusive -and $ranges[$j].start -lt $ranges[$i].endExclusive) {
            throw "Seed ranges overlap: $($ranges[$i].name) and $($ranges[$j].name)."
        }
    }
}
if ($SequentialProposalOrderSeed -eq $RoundRobinOrderSeed -or
    $SemanticProposalOrderSeed -eq $RoundRobinOrderSeed -or
    [long]$MoonGrammataCampaignSeed -eq [long]$RoundRobinOrderSeed) {
    throw 'Round-robin ordering seed must be distinct from the arm seeds.'
}

function Get-WallClockHarnessDigest {
    $parts = foreach ($relative in @(
        'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt', 'cmd/main/main.mbt',
        'scripts/verify_seed.ps1', 'scripts/live_control_policy.ps1', 'scripts/run_live_control_campaign.ps1',
        'scripts/run_live_feedback_campaign_comparison.ps1', 'scripts/run_live_feedback_wallclock_campaign.ps1',
        'scripts/semantic_selection.ps1', 'scripts/compare_semantic_selection.ps1', 'scripts/run_moongrammata_selection.ps1',
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
        'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt',
        'cmd/main/main.mbt', 'scripts/verify_seed.ps1', 'scripts/semantic_selection.ps1',
        'scripts/compare_semantic_selection.ps1'
    )) {
        $path = Join-Path $projectRoot $relative
        "${relative}:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
    }
    $bytes = [Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
    [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
}
$harnessDigestStart = Get-WallClockHarnessDigest
$selectionDigestCurrent = Get-SelectionHarnessDigest
if ([string]$selection.harnessDigestStart -ne [string]$selection.harnessDigestEnd -or
    [string]$selection.harnessDigestEnd -ne $selectionDigestCurrent) {
    throw 'Selection configuration was produced by a stale or changing verifier harness; regenerate it before the wall-clock run.'
}

$outputDirectory = if ($OutputPath) { Split-Path -Parent ([IO.Path]::GetFullPath($OutputPath)) } else { Join-Path $projectRoot '.moonsmith\runs' }
if (-not $outputDirectory) { $outputDirectory = $projectRoot }
New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null
$stem = if ($OutputPath) { [IO.Path]::GetFileNameWithoutExtension($OutputPath) } else { 'live_feedback_wallclock_' + (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff') }
$resolvedOutput = if ($OutputPath) { [IO.Path]::GetFullPath($OutputPath) } else { Join-Path $outputDirectory ($stem + '.json') }
$checkpointPath = $resolvedOutput + '.checkpoint.json'
$poolPath = Join-Path $outputDirectory ($stem + '.configuration.json')
if (-not $Resume -and (Test-Path -LiteralPath $checkpointPath)) { throw "Checkpoint exists; resume it or choose a new output path: $checkpointPath" }
if (-not $Resume -and (Test-Path -LiteralPath $resolvedOutput)) { throw "Output exists; choose a new path: $resolvedOutput" }
if ([IO.Path]::GetFullPath($selectionPath) -ne [IO.Path]::GetFullPath($poolPath) -and -not (Test-Path -LiteralPath $poolPath)) {
    Copy-Item -LiteralPath $selectionPath -Destination $poolPath
}
if ((Get-FileHash -LiteralPath $poolPath -Algorithm SHA256).Hash -ne (Get-FileHash -LiteralPath $selectionPath -Algorithm SHA256).Hash) {
    throw 'The saved campaign configuration path exists with different contents; choose a fresh output stem.'
}

$config = [ordered]@{
    selectionSha256=(Get-FileHash -LiteralPath $selectionPath -Algorithm SHA256).Hash.ToLowerInvariant()
    wallClockBudgetSecondsPerArm=$WallClockBudgetSecondsPerArm; proposalBatchSize=$ProposalBatchSize
    maximumAttemptsPerArm=$MaximumAttemptsPerArm; sequentialSeedStart=$SequentialSeedStart
    semanticGuidedSeedStart=$SemanticGuidedSeedStart; moonGrammataSeedMinimum=$MoonGrammataSeedMinimum
    moonGrammataSeedMaximum=$MoonGrammataSeedMaximum; sequentialProposalOrderSeed=$SequentialProposalOrderSeed
    semanticProposalOrderSeed=$SemanticProposalOrderSeed; moonGrammataCampaignSeed=$MoonGrammataCampaignSeed
    roundRobinOrderSeed=$RoundRobinOrderSeed; targets=$targets; depth=$depth; timeoutSecondsPerTarget=$targetTimeout
    workerOverrideForTests=[bool]$WorkerOverrideForTests
}
$configJson = $config | ConvertTo-Json -Depth 8 -Compress
$configFingerprint = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($configJson))).ToLowerInvariant()

function Save-Checkpoint {
    param([object]$Value)
    $Value.updatedAtUtc = [DateTimeOffset]::UtcNow.ToString('o')
    $json = $Value | ConvertTo-Json -Depth 18
    $temp = $checkpointPath + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($temp, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    [IO.File]::Move($temp,$checkpointPath,$true)
}
function New-ArmState {
    [ordered]@{ elapsedMs=0L; attempts=0; completedCases=0; timedOut=$false; stoppedByAttemptCap=$false; cases=@(); seenPathKinds=@() }
}

if ($Resume) {
    if (-not (Test-Path -LiteralPath $checkpointPath)) { throw "No checkpoint exists to resume: $checkpointPath" }
    $state = Get-Content -LiteralPath $checkpointPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    if ($state.configFingerprint -ne $configFingerprint) { throw 'Resume parameters do not match the saved checkpoint.' }
    if ([string]$state.harnessDigestStart -ne $harnessDigestStart -or
        [string]$state.selectionHarnessDigest -ne $selectionDigestCurrent) {
        throw 'Resume harness inputs do not match the saved checkpoint; start a new campaign instead.'
    }
    if ($state.completed) { throw 'This wall-clock campaign checkpoint is already complete.' }
    $state.resumedAfterInterruption = $true
    if ($state.activeTask) {
        $active = $state.activeTask
        $activeWasRunning = $false
        if ($active.processId -and $active.processStartTimeUtc) {
            try {
                $process = [Diagnostics.Process]::GetProcessById([int]$active.processId)
                $actualStart = $process.StartTime.ToUniversalTime()
                $expectedStart = [DateTimeOffset]::Parse([string]$active.processStartTimeUtc).UtcDateTime
                if ([Math]::Abs(($actualStart - $expectedStart).TotalSeconds) -lt 2) {
                    $activeWasRunning = -not $process.HasExited
                    if ($activeWasRunning) { $process.Kill($true); $process.WaitForExit() }
                }
                $process.Dispose()
            } catch { }
        }
        $armState = $state.arms[[string]$active.arm]
        $armState.attempts = [int]$armState.attempts + 1
        $candidateReport = $null
        if (Test-Path -LiteralPath ([string]$active.reportPath)) {
            try { $candidateReport = Get-Content -LiteralPath ([string]$active.reportPath) -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable } catch { }
        }
        $reportRecovered = $null -ne $candidateReport
        $reportElapsed = if ($reportRecovered) {
            [Math]::Max(0,[long](([IO.File]::GetLastWriteTimeUtc([string]$active.reportPath) - [DateTimeOffset]::Parse([string]$active.startedAtUtc).UtcDateTime).TotalMilliseconds))
        } else { [Math]::Max(0,([long]$WallClockBudgetSecondsPerArm * 1000) - [long]$armState.elapsedMs) }
        $budgetRemaining = [Math]::Max(0,([long]$WallClockBudgetSecondsPerArm * 1000) - [long]$armState.elapsedMs)
        $fitsBudget = $reportRecovered -and $reportElapsed -le $budgetRemaining -and -not $activeWasRunning
        $armState.elapsedMs = [long]$armState.elapsedMs + [long]$reportElapsed
        if ($reportRecovered -and $fitsBudget) {
            $armState.completedCases = [int]$armState.completedCases + 1
            $recoveredFinding = if ($active.arm -eq 'moonGrammata') { @($candidateReport.moonGrammata.liveFindings) } else { @($candidateReport.findings.Keys) }
            $recoveredBackend = if ($active.arm -eq 'moonGrammata') {
                @($candidateReport.moonGrammata.observations | ForEach-Object { $_.backendRuns } | ForEach-Object { "{0}:{1}:{2}" -f $_.target,$_.status,$_.exitCode })
            } else { @($candidateReport.perArmCases | ForEach-Object { $_.backendStatuses }) }
            $recoveredPaths = if ($active.arm -eq 'moonGrammata') {
                @($candidateReport.moonGrammata.observations | ForEach-Object { $_.referencePathKinds } | Sort-Object -Unique)
            } elseif (@($candidateReport.perArmCases).Count -gt 0) {
                @($candidateReport.perArmCases[0].referencePathKinds)
            } else { @() }
            $recoveredSeenPaths = if ($active.arm -ne 'moonGrammata' -and @($candidateReport.perArmCases).Count -gt 0) {
                @($candidateReport.perArmCases[0].seenPathKindsBeforeSelection)
            } else { @() }
            if ($active.arm -eq 'semanticGuided' -and @($candidateReport.perArmCases).Count -gt 0) {
                $armState.seenPathKinds = @(@($armState.seenPathKinds) + $recoveredPaths | Sort-Object -Unique)
            }
            $armState.cases = @($armState.cases) + @([ordered]@{
                attempt=[int]$armState.attempts; completed=$true; timedOut=$false; censored=$false
                status='recovered-complete-report'; elapsedMs=$reportElapsed; reportPath=[string]$active.reportPath
                reportSha256=(Get-FileHash -LiteralPath ([string]$active.reportPath) -Algorithm SHA256).Hash.ToLowerInvariant()
                findings=$recoveredFinding; backendStatuses=$recoveredBackend; referencePathKinds=$recoveredPaths
                seenPathKindsBeforeSelection=$recoveredSeenPaths
                candidateOrCallbackCount=if ($active.arm -eq 'moonGrammata') { [int]$candidateReport.moonGrammata.liveEvaluations } else { [int]$candidateReport.proposalCount }
                backendCheckCount=if ($active.arm -eq 'moonGrammata') { @($candidateReport.moonGrammata.observations | ForEach-Object { $_.backendRuns }).Count } else { [int]$candidateReport.backendChecks }
                report=$candidateReport
            })
        } else {
            $armState.timedOut = $true
            $armState.cases = @($armState.cases) + @([ordered]@{
                attempt=[int]$armState.attempts; completed=$false; timedOut=$true; censored=$true
                status=if ($reportRecovered) { 'interrupted-report-exceeded-budget-or-was-running' } else { 'interrupted-clock-unknown-budget-censored' }
                elapsedMs=$reportElapsed; reportPath=if ($reportRecovered) { [string]$active.reportPath } else { $null }
                stdout='Parent campaign was interrupted; the active attempt was conservatively censored. Completed prior cases remain in the checkpoint.'
                stderr=''
            })
            if (-not $reportRecovered) { $armState.elapsedMs = [long]$WallClockBudgetSecondsPerArm * 1000 }
        }
        $state.activeTask = $null
        $state.resumedAfterInterruption = $true
        Save-Checkpoint $state
    }
} else {
    $state = [ordered]@{
        schemaVersion=1; configFingerprint=$configFingerprint; config=$config
        harnessDigestStart=$harnessDigestStart; selectionHarnessDigest=$selectionDigestCurrent
        checkpointPath=$checkpointPath; summaryPath=$resolvedOutput; startedAtUtc=[DateTimeOffset]::UtcNow.ToString('o')
        completed=$false; activeTask=$null; taskOrder=@(); roundNumber=0; resumedAfterInterruption=$false
        arms=[ordered]@{ sequential=(New-ArmState); semanticGuided=(New-ArmState); moonGrammata=(New-ArmState) }
    }
    Save-Checkpoint $state
}

$powerShell = (Get-Command pwsh -ErrorAction Stop).Source
$runnerControl = Join-Path $PSScriptRoot 'run_live_control_campaign.ps1'
$runnerMoonGrammata = Join-Path $PSScriptRoot 'run_moongrammata_selection.ps1'
$runStopwatch = [Diagnostics.Stopwatch]::StartNew()
$orderOffset = $RoundRobinOrderSeed % 3
$armNames = @('sequential', 'semanticGuided', 'moonGrammata')

function Invoke-WorkerTask {
    param([string]$Arm, [int]$Attempt, [int]$RemainingMs, [string]$ReportPath)
    if ($WorkerOverrideForTests) {
        $worker = (Resolve-Path -LiteralPath $WorkerOverrideForTests -ErrorAction Stop).Path
        $arguments = @('-NoProfile','-File',$worker,'-Arm',$Arm,'-Attempt',[string]$Attempt,
            '-OutputPath',$ReportPath,'-DelayMilliseconds',[string]$MockWorkerDelayMilliseconds)
        if ($Arm -eq 'semanticGuided') {
            $arguments += @('-InitialSeenPathKindsCsv',(@($state.arms[$Arm].seenPathKinds) -join ','))
        }
    } elseif ($Arm -eq 'sequential' -or $Arm -eq 'semanticGuided') {
        $policy = if ($Arm -eq 'sequential') { 'sequential' } else { 'semantic-guided' }
        $seedStart = if ($Arm -eq 'sequential') { [long]$SequentialSeedStart + ([long]($Attempt - 1) * $ProposalBatchSize) } else { [long]$SemanticGuidedSeedStart + ([long]($Attempt - 1) * $ProposalBatchSize) }
        $orderSeed = if ($Arm -eq 'sequential') { [long]$SequentialProposalOrderSeed + $Attempt - 1 } else { [long]$SemanticProposalOrderSeed + $Attempt - 1 }
        $arguments = @('-NoProfile','-File',$runnerControl,'-Policy',$policy,'-SeedStart',[string]$seedStart,
            '-ProposalOrderSeed',[string]$orderSeed,'-ExecutionBudget','1','-ProposalBatchSize',[string]$ProposalBatchSize,
            '-TargetsCsv',($targets -join ','),'-Depth',[string]$depth,'-TimeoutSeconds',[string]$targetTimeout,'-OutputPath',$ReportPath)
        if ($Arm -eq 'semanticGuided') {
            $arguments += @('-InitialSeenPathKindsCsv',(@($state.arms[$Arm].seenPathKinds) -join ','))
        }
    } else {
        $generatedSeed = [long]$MoonGrammataSeedMinimum + $Attempt - 1
        $campaignSeed = [long]$MoonGrammataCampaignSeed + $Attempt - 1
        $arguments = @('-NoProfile','-File',$runnerMoonGrammata,'-InputReport',$poolPath,'-ExecutionBudget','1',
            '-Seed',[string]$campaignSeed,'-OutputPath',$ReportPath,'-LiveGeneratedSeeds',
            '-GeneratedSeedMinimum',[string]$generatedSeed,'-GeneratedSeedMaximum',[string]$generatedSeed)
    }
    $startInfo = [Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $powerShell; $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false; $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true; $startInfo.RedirectStandardError = $true
    foreach ($argument in $arguments) { $startInfo.ArgumentList.Add([string]$argument) }
    $process = [Diagnostics.Process]::new(); $process.StartInfo = $startInfo
    $timer = [Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) { throw "Failed to start $Arm arm worker." }
    $state.activeTask = [ordered]@{
        arm=$Arm; attempt=$Attempt; processId=$process.Id; processStartTimeUtc=$process.StartTime.ToUniversalTime().ToString('o')
        startedAtUtc=[DateTimeOffset]::UtcNow.ToString('o'); reportPath=$ReportPath
    }
    Save-Checkpoint $state
    $stdoutTask = $process.StandardOutput.ReadToEndAsync(); $stderrTask = $process.StandardError.ReadToEndAsync()
    $finished = $process.WaitForExit([Math]::Max(1,$RemainingMs))
    if (-not $finished) { $process.Kill($true); $process.WaitForExit() }
    $timer.Stop(); $elapsed = $timer.ElapsedMilliseconds
    $stdout = $stdoutTask.GetAwaiter().GetResult(); $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($finished) { $process.ExitCode } else { -1 }
    $process.Dispose()
    [pscustomobject]@{ finished=$finished; exitCode=$exitCode; elapsedMs=$elapsed; stdout=$stdout; stderr=$stderr }
}

function Test-ArmHasBudget {
    param([string]$Arm)
    $armState = $state.arms[$Arm]
    (-not $armState.timedOut) -and ([long]$armState.elapsedMs -lt ([long]$WallClockBudgetSecondsPerArm * 1000)) -and
        ([int]$armState.attempts -lt $MaximumAttemptsPerArm)
}

while (@($armNames | Where-Object { Test-ArmHasBudget $_ }).Count -gt 0) {
    $roundOffset = ($orderOffset + [int]$state.roundNumber) % 3
    $roundOrder = for ($offset = 0; $offset -lt 3; $offset++) { $armNames[($offset + $roundOffset) % 3] }
    foreach ($arm in $roundOrder) {
        if (-not (Test-ArmHasBudget $arm)) { continue }
        $armState = $state.arms[$arm]
        $attempt = [int]$armState.attempts + 1
        $remaining = [int][Math]::Max(1, ([long]$WallClockBudgetSecondsPerArm * 1000) - [long]$armState.elapsedMs)
        $reportPath = $resolvedOutput + '.' + $arm + '.attempt-' + $attempt.ToString('D4') + '.json'
        $state.taskOrder = @($state.taskOrder) + @([ordered]@{ round=[int]$state.roundNumber; arm=$arm; attempt=$attempt; scheduledAtUtc=[DateTimeOffset]::UtcNow.ToString('o') })
        $state.activeTask = [ordered]@{ arm=$arm; attempt=$attempt; processId=$null; processStartTimeUtc=$null; startedAtUtc=[DateTimeOffset]::UtcNow.ToString('o'); reportPath=$reportPath }
        Save-Checkpoint $state
        $workerResult = Invoke-WorkerTask -Arm $arm -Attempt $attempt -RemainingMs $remaining -ReportPath $reportPath
        $armState = $state.arms[$arm]
        $armState.elapsedMs = [long]$armState.elapsedMs + [long]$workerResult.elapsedMs
        $armState.attempts = $attempt
        $caseReport = $null; $parseError = $null
        if ($workerResult.finished -and $workerResult.exitCode -eq 0 -and (Test-Path -LiteralPath $reportPath)) {
            try { $caseReport = Get-Content -LiteralPath $reportPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable }
            catch { $parseError = $_.Exception.Message }
        }
        $completed = ($null -ne $caseReport)
        $timedOut = -not $workerResult.finished
        $caseRecord = [ordered]@{
            attempt=$attempt; completed=$completed; timedOut=$timedOut; censored=($timedOut -or -not $completed)
            status=if ($timedOut) { 'wall-clock-budget-censored' } elseif ($completed) { 'complete' } elseif (-not $workerResult.finished) { 'worker-failed' } else { 'worker-failed-or-invalid-report' }
            exitCode=$workerResult.exitCode; elapsedMs=$workerResult.elapsedMs; remainingBudgetMsBefore=$remaining
            reportPath=if (Test-Path -LiteralPath $reportPath) { $reportPath } else { $null }
            stderr=if ($parseError) { $parseError + "`n" + $workerResult.stderr } else { $workerResult.stderr }
            findings=@(); backendStatuses=@(); report=$caseReport
        }
        if ($completed) {
            $caseRecord.reportSha256 = (Get-FileHash -LiteralPath $reportPath -Algorithm SHA256).Hash.ToLowerInvariant()
            $armState.completedCases = [int]$armState.completedCases + 1
            if ($arm -eq 'moonGrammata') {
                $mg = $caseReport.moonGrammata
                $observations = @($mg.observations)
                $caseRecord.findings = @($mg.liveFindings)
                $caseRecord.backendStatuses = @($observations | ForEach-Object { $_.backendRuns } | ForEach-Object { "{0}:{1}:{2}" -f $_.target,$_.status,$_.exitCode })
                $caseRecord.referencePathKinds = @($observations | ForEach-Object { $_.referencePathKinds } | Sort-Object -Unique)
                $caseRecord.candidateOrCallbackCount = [int]$mg.liveEvaluations
                $caseRecord.backendCheckCount = @($observations | ForEach-Object { $_.backendRuns }).Count
            } else {
                $caseRecord.findings = @($caseReport.findings.Keys)
                $caseRecord.backendStatuses = @($caseReport.perArmCases | ForEach-Object { $_.backendStatuses })
                if (@($caseReport.perArmCases).Count -gt 0) {
                    $selected = $caseReport.perArmCases[0]
                    $caseRecord.seenPathKindsBeforeSelection = @($selected.seenPathKindsBeforeSelection)
                    $caseRecord.referencePathKinds = @($selected.referencePathKinds)
                    $caseRecord.candidateOrCallbackCount = [int]$caseReport.proposalCount
                    $caseRecord.backendCheckCount = [int]$caseReport.backendChecks
                    if ($arm -eq 'semanticGuided') {
                        $armState.seenPathKinds = @(@($armState.seenPathKinds) + @($selected.referencePathKinds | ForEach-Object { [string]$_ }) | Sort-Object -Unique)
                    }
                }
            }
        }
        $armState.cases = @($armState.cases) + @($caseRecord)
        if ($timedOut) { $armState.timedOut = $true }
        $state.activeTask = $null
        Save-Checkpoint $state
        if ($timedOut) { break }
    }
    $state.roundNumber = [int]$state.roundNumber + 1
    Save-Checkpoint $state
}

$runStopwatch.Stop()
$campaignWallClockMs = [Math]::Max($runStopwatch.ElapsedMilliseconds,
    [long]([DateTimeOffset]::UtcNow - [DateTimeOffset]::Parse([string]$state.startedAtUtc)).TotalMilliseconds)
$harnessDigestEnd = Get-WallClockHarnessDigest
$armSummaries = [ordered]@{}
foreach ($arm in $armNames) {
    $armState = $state.arms[$arm]
    $pathKinds = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($case in $armState.cases) {
        if (-not $case.completed) { continue }
        foreach ($pathKind in @($case.referencePathKinds)) { [void]$pathKinds.Add([string]$pathKind) }
    }
    $candidateOrCallbackCount = 0
    $backendCheckCount = 0
    foreach ($completedCase in @($armState.cases | Where-Object { $_.completed })) {
        $candidateOrCallbackCount += [int]$completedCase.candidateOrCallbackCount
        $backendCheckCount += [int]$completedCase.backendCheckCount
    }
    $armSummaries[$arm] = [ordered]@{
        wallClockBudgetMs=[long]$WallClockBudgetSecondsPerArm * 1000; activeWallClockMs=[long]$armState.elapsedMs
        attempts=[int]$armState.attempts; completedCases=[int]$armState.completedCases; timedOut=[bool]$armState.timedOut
        stoppedByAttemptCap=([int]$armState.attempts -ge $MaximumAttemptsPerArm -and -not $armState.timedOut)
        distinctReferencePathKinds=$pathKinds.Count
        candidateOrCallbackCount=$candidateOrCallbackCount
        backendCheckCount=$backendCheckCount
        semanticFeedbackPathKindsSeen=@($armState.seenPathKinds)
        findingRecords=@($armState.cases | ForEach-Object { $_.findings })
        backendStatuses=@($armState.cases | ForEach-Object { $_.backendStatuses })
        cases=@($armState.cases)
    }
}
$wallclockMatched = (-not $state.resumedAfterInterruption) -and
    (@($armNames | ForEach-Object { [Math]::Abs([long]$state.arms[$_].elapsedMs - ([long]$WallClockBudgetSecondsPerArm * 1000)) } | Where-Object { $_ -gt 1000 }).Count -eq 0) -and
    (@($armNames | Where-Object { $state.arms[$_].attempts -ge $MaximumAttemptsPerArm -and -not $state.arms[$_].timedOut }).Count -eq 0)
$harnessStable = $harnessDigestStart -eq $harnessDigestEnd -and [string]$selection.harnessDigestStart -eq [string]$selection.harnessDigestEnd -and
    [string]$selection.harnessDigestEnd -eq $selectionDigestCurrent
$result = [ordered]@{
    schemaVersion=1; protocol='Three interleaved online arms receive the same per-arm active wall-clock budget. Each arm task is an isolated one-case process; process startup, candidate generation/preflight, feedback, verification, and output serialization are charged. A task cut off by the remaining budget is censored and is not counted as a completed case.'
    selectionConfigurationPath=$poolPath; selectionConfigurationSha256=(Get-FileHash -LiteralPath $poolPath -Algorithm SHA256).Hash.ToLowerInvariant()
    configuration=[ordered]@{ targets=$targets; depth=$depth; timeoutSecondsPerTarget=$targetTimeout; wallClockBudgetSecondsPerArm=$WallClockBudgetSecondsPerArm; proposalBatchSize=$ProposalBatchSize; maximumAttemptsPerArm=$MaximumAttemptsPerArm }
    orderSeed=$RoundRobinOrderSeed; taskOrder=@($state.taskOrder); arms=$armSummaries
    schedulerWallClockMs=$campaignWallClockMs; schedulerOverheadNotChargedToArmMs=[long]$campaignWallClockMs - (@($armNames | ForEach-Object { [long]$state.arms[$_].elapsedMs } | Measure-Object -Sum).Sum)
    equalWallClockBudgetConfigured=$true; wallClockUsageWithinOneSecondOfBudget=$wallclockMatched
    resumedAfterParentInterruption=[bool]$state.resumedAfterInterruption
    anyCensored=@($armNames | ForEach-Object { $state.arms[$_].cases } | ForEach-Object { $_ } | Where-Object { $_.censored }).Count -gt 0
    harnessDigestStart=$harnessDigestStart; harnessDigestEnd=$harnessDigestEnd; harnessChangedDuringRun=(-not $harnessStable)
    interpretation=if (-not $harnessStable) { 'Invalid: the verifier/generator harness changed during the run.' } elseif ($state.resumedAfterInterruption) { 'Run resumed after interruption. Active time for the interrupted worker is not fully observable; its remaining arm budget was conservatively censored. Keep recovered artifacts, but do not claim a matched realized wall-clock comparison.' } elseif (-not $wallclockMatched) { 'Budget configuration was equal, but observed worker time was not matched within one second (for example, all arms hit the attempt cap, or termination overhead differed). Do not claim a matched realized wall-clock comparison.' } else { 'Exploratory equal-budget online comparison. Compare backend findings and failures first; path diversity is secondary because only one arm explicitly optimizes it. Censored attempts are excluded from completed-case counts. This does not establish general fuzzer effectiveness.' }
    checkpointPath=$checkpointPath; rawCaseReports=@($state.arms.Values | ForEach-Object { $_.cases } | ForEach-Object {
        if ($_.reportPath) { [ordered]@{ path=$_.reportPath; sha256=$_.reportSha256 } }
    } | Where-Object { $_ })
}
$state.completed = $true
$state.activeTask = $null
$state.summary = $result
Save-Checkpoint $state
$json = $result | ConvertTo-Json -Depth 20
$outputTemp = $resolvedOutput + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
[IO.File]::WriteAllText($outputTemp, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
[IO.File]::Move($outputTemp,$resolvedOutput,$true)
$json
