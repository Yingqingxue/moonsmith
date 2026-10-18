param(
    [Parameter(Mandatory)][string]$InputReport,
    [Parameter()][ValidateRange(1, 10000)][int]$ExecutionBudget = 20,
    [Parameter()][long]$Seed = 20261018,
    [Parameter()][string]$OutputPath = '',
    [Parameter()][switch]$LiveVerifySelectedArms,
    [Parameter()][switch]$LiveTarget,
    [Parameter()][switch]$LiveGeneratedSeeds,
    [Parameter()][ValidateRange(0, 2147483647)][int]$GeneratedSeedMinimum = 0,
    [Parameter()][ValidateRange(0, 2147483647)][int]$GeneratedSeedMaximum = 1000000,
    [Parameter()][string]$LiveVerifierScript = ''
)

$ErrorActionPreference = 'Stop'
if (($LiveTarget -or $LiveGeneratedSeeds) -and $LiveVerifySelectedArms) {
    throw 'Choose an online target mode or post-selection LiveVerifySelectedArms; combining them is not a defined experiment.'
}
if ($LiveTarget -and $LiveGeneratedSeeds) { throw 'Choose either LiveTarget or LiveGeneratedSeeds.' }
if ($LiveGeneratedSeeds -and $GeneratedSeedMaximum -lt $GeneratedSeedMinimum) {
    throw 'Generated seed range must be ordered.'
}
$onlineLive = $LiveTarget -or $LiveGeneratedSeeds
$projectRoot = Split-Path -Parent $PSScriptRoot
$inputPath = (Resolve-Path -LiteralPath $InputReport -ErrorAction Stop).Path
$report = Get-Content -LiteralPath $inputPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($report.schemaVersion -ne 1 -or
    (-not $LiveGeneratedSeeds -and $report.candidatePool.Count -lt $ExecutionBudget)) {
    throw 'Input must be a schemaVersion 1 MoonSmith selection report with enough candidates.'
}
if ($report.harnessChangedDuringRun -or -not $report.equalBackendExecutionBudget) {
    throw 'Refusing an incomplete or internally invalid MoonSmith candidate-pool report.'
}

    $pathNames = if ($LiveGeneratedSeeds) {
        @()
    } else {
        @($report.candidatePool | ForEach-Object { $_.paths } | Sort-Object -Unique)
    }
    if (-not $LiveGeneratedSeeds -and $pathNames.Count -eq 0) { throw 'Candidate pool has no reference-path features.' }
$pathIds = @{}
for ($i = 0; $i -lt $pathNames.Count; $i++) { $pathIds[[string]$pathNames[$i]] = $i }
$specifications = foreach ($candidate in $report.candidatePool) {
    $ids = @($candidate.paths | ForEach-Object { $pathIds[[string]$_] })
    $idText = if ($ids.Count -gt 0) { $ids -join ',' } else { '-' }
    "{0}:{1}:{2}" -f $candidate.seed, [int]$candidate.sizeQuartile, $idText
}
$template = Join-Path $projectRoot 'benchmarks\moongrammata_selection'
$tempRoot = Join-Path ([IO.Path]::GetTempPath()) ('moongrammata-selection-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot | Out-Null
try {
    Copy-Item -LiteralPath (Join-Path $template 'moon.mod') -Destination $tempRoot
    $commandPackage = Join-Path $tempRoot 'cmd\main'
    New-Item -ItemType Directory -Path $commandPackage -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $template 'cmd\main\moon.pkg') -Destination $commandPackage
    Copy-Item -LiteralPath (Join-Path $template 'cmd\main\main.mbt') -Destination $commandPackage
    $moon = (Get-Command moon -ErrorAction Stop).Source
    if ($onlineLive) {
        $targets = @($report.configuredTargets | ForEach-Object { [string]$_ })
        if ($targets.Count -eq 0) { throw 'Candidate-pool report has no configured targets.' }
        $depth = [int]$report.depth
        $timeoutSeconds = [int]$report.timeoutSeconds
        $isTestDouble = [bool]$LiveVerifierScript
        $verifyScript = if ($isTestDouble) {
            (Resolve-Path -LiteralPath $LiveVerifierScript -ErrorAction Stop).Path
        } else {
            Join-Path $PSScriptRoot 'verify_seed.ps1'
        }
        if (-not $isTestDouble) {
            $harnessParts = foreach ($relativePath in @(
                'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt',
                'cmd/main/main.mbt', 'scripts/verify_seed.ps1',
                'scripts/semantic_selection.ps1', 'scripts/compare_semantic_selection.ps1'
            )) {
                $path = Join-Path $projectRoot $relativePath
                "${relativePath}:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
            }
            $harnessBytes = [System.Text.Encoding]::UTF8.GetBytes(($harnessParts -join "`n"))
            $currentHarnessDigest = [System.Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData($harnessBytes)
            ).ToLowerInvariant()
            if ($report.harnessChangedDuringRun -or
                -not $report.harnessDigestEnd -or
                [string]$report.harnessDigestEnd -ne $currentHarnessDigest) {
                throw 'Live target requires an unchanged candidate-generation, reference, and verifier harness.'
            }
        }
        if ($LiveGeneratedSeeds) {
            $args = @('run', '--target', 'js', 'cmd/main', '--', 'live-generated',
                [string]$ExecutionBudget, [string]$Seed, '-', $verifyScript,
                ($targets -join ','), [string]$depth, [string]$timeoutSeconds,
                [string]$GeneratedSeedMinimum, [string]$GeneratedSeedMaximum)
        } else {
            $args = @('run', '--target', 'js', 'cmd/main', '--', 'live',
                [string]$ExecutionBudget, [string]$Seed, ($pathNames -join ','),
                $verifyScript, ($targets -join ','), [string]$depth, [string]$timeoutSeconds) + @($specifications)
        }
    } else {
        $args = @('run', '--target', 'js', 'cmd/main', '--', [string]$ExecutionBudget,
            [string]$Seed, ($pathNames -join ',')) + @($specifications)
    }
    Push-Location $tempRoot
    try { $raw = & $moon @args 2>&1 }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw "MoonGrammata benchmark failed: $($raw -join [Environment]::NewLine)" }
    $text = $raw -join [Environment]::NewLine
    $expectedMarker = if ($LiveGeneratedSeeds) {
        'MOONSMITH_LIVE_GENERATED_V1'
    } elseif ($LiveTarget) {
        'MOONSMITH_LIVE_POOL_V1'
    } else {
        'MOONSMITH_FIXED_POOL_V1'
    }
    if (-not $text.Contains($expectedMarker)) {
        throw "MoonGrammata benchmark did not emit its result marker: $text"
    }
    $summary = @{}
    $liveObservationLines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $text -split '\r?\n') {
        if ($line -match '^live_observation=(.*)$') {
            $liveObservationLines.Add([string]$Matches[1])
        } elseif ($line -match '^([a-z_]+)=(.*)$') {
            $summary[$Matches[1]] = $Matches[2]
        }
    }
    $expectedPoolSize = if ($LiveGeneratedSeeds) { 0 } else { $report.candidatePool.Count }
    if ([int]$summary.completed -ne $ExecutionBudget -or
        [int]$summary.candidate_pool -ne $expectedPoolSize) {
        throw 'MoonGrammata campaign did not honor its generator mode and execution budget.'
    }
    $liveObservationRecords = foreach ($record in $liveObservationLines) {
        $fields = $record -split '\|', 7
        if ($fields.Count -ne 7) { throw "Malformed live observation record: $record" }
        $backendRecords = foreach ($backend in ($fields[6] -split ',' | Where-Object { $_ })) {
            $backendFields = $backend -split ':', 4
            if ($backendFields.Count -ne 4) { throw "Malformed backend result in observation: $backend" }
            [pscustomobject]@{
                target = $backendFields[0]
                status = $backendFields[1]
                exitCode = $backendFields[2]
                executionAttempted = [bool]::Parse($backendFields[3])
            }
        }
        [pscustomobject]@{
            seed = [int]$fields[0]
            finding = [string]$fields[1]
            verifierDurationMs = [long]$fields[2]
            sourceLineCount = [int]$fields[3]
            referenceStatus = [string]$fields[4]
            referencePathKinds = @($fields[5] -split ',' | Where-Object { $_ })
            backendRuns = @($backendRecords)
        }
    }
    if ($onlineLive -and $liveObservationRecords.Count -ne $ExecutionBudget) {
        throw 'Live target did not preserve one observation record per callback.'
    }
    $selectedSeeds = @($summary.observed_seeds -split ',' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
    $candidateMap = @{}
    foreach ($candidate in $report.candidatePool) { $candidateMap[[string]$candidate.seed] = $candidate }
    $selectedQuartiles = @{}
    if (-not $LiveGeneratedSeeds) {
        foreach ($selectedSeed in $selectedSeeds) {
            $quartile = [string]$candidateMap[[string]$selectedSeed].sizeQuartile
            if (-not $quartile) { $quartile = 'unstratified' }
            if (-not $selectedQuartiles.ContainsKey($quartile)) { $selectedQuartiles[$quartile] = 0 }
            $selectedQuartiles[$quartile]++
        }
    }

    $liveVerification = $null
    if ($LiveVerifySelectedArms) {
        $verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
        $powerShell = (Get-Command pwsh -ErrorAction Stop).Source
        $targets = @($report.configuredTargets | ForEach-Object { [string]$_ })
        if ($targets.Count -eq 0) { throw 'Candidate-pool report has no configured targets.' }
        $depth = [int]$report.depth
        $timeoutSeconds = [int]$report.timeoutSeconds
        $harnessParts = foreach ($relativePath in @(
            'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt',
            'cmd/main/main.mbt', 'scripts/verify_seed.ps1',
            'scripts/semantic_selection.ps1', 'scripts/compare_semantic_selection.ps1'
        )) {
            $path = Join-Path $projectRoot $relativePath
            "${relativePath}:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
        }
        $harnessBytes = [System.Text.Encoding]::UTF8.GetBytes(($harnessParts -join "`n"))
        $currentHarnessDigest = [System.Convert]::ToHexString(
            [System.Security.Cryptography.SHA256]::HashData($harnessBytes)
        ).ToLowerInvariant()
        if ($report.harnessChangedDuringRun -or
            -not $report.harnessDigestEnd -or
            [string]$report.harnessDigestEnd -ne $currentHarnessDigest) {
            throw 'Live verification requires an unchanged candidate-generation, reference, and verifier harness.'
        }
        $candidatesBySeed = @{}
        foreach ($candidate in $report.candidatePool) {
            $candidatesBySeed[[string]$candidate.seed] = $candidate
        }

        function Invoke-LiveVerificationArm {
            param([string]$Name, [int[]]$Seeds)
            $timer = [System.Diagnostics.Stopwatch]::StartNew()
            $cases = [System.Collections.Generic.List[object]]::new()
            foreach ($caseSeed in $Seeds) {
                $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
                $startInfo.FileName = $powerShell
                $startInfo.WorkingDirectory = $projectRoot
                $startInfo.UseShellExecute = $false
                $startInfo.CreateNoWindow = $true
                $startInfo.RedirectStandardOutput = $true
                $startInfo.RedirectStandardError = $true
                $targetLiteral = ($targets | ForEach-Object {
                    "'$(($_ -replace "'", "''"))'"
                }) -join ','
                $verifyCommand = "& '$(($verifyScript -replace "'", "''"))' -Seed $caseSeed -Depth $depth -Targets @($targetLiteral) -TimeoutSeconds $timeoutSeconds -NoPersist"
                foreach ($argument in @(
                    '-NoProfile', '-Command', $verifyCommand
                )) {
                    $startInfo.ArgumentList.Add($argument)
                }
                $process = [System.Diagnostics.Process]::new()
                $process.StartInfo = $startInfo
                try {
                    if (-not $process.Start()) { throw "Could not start live verifier for seed $caseSeed." }
                    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
                    $stderrTask = $process.StandardError.ReadToEndAsync()
                    $waitSeconds = [Math]::Max(120, 3 * $timeoutSeconds + 60)
                    if (-not $process.WaitForExit($waitSeconds * 1000)) {
                        $process.Kill($true)
                        $process.WaitForExit()
                        throw "Live verifier timed out for seed $caseSeed after $waitSeconds seconds."
                    }
                    $stdout = $stdoutTask.GetAwaiter().GetResult()
                    $stderr = $stderrTask.GetAwaiter().GetResult()
                    if ($process.ExitCode -notin @(0, 1)) {
                        throw "Live verifier failed for seed ${caseSeed} (exit $($process.ExitCode)): $stderr"
                    }
                    $verification = $stdout | ConvertFrom-Json
                    if ([int]$verification.seed -ne $caseSeed -or
                        -not $verification.referenceChecked -or
                        @($verification.runs).Count -ne $targets.Count) {
                        throw "Live verifier returned incomplete data for seed $caseSeed."
                    }
                    $candidate = $candidatesBySeed[[string]$caseSeed]
                    $livePaths = @($verification.referenceTrace.visited | Sort-Object -Unique)
                    $frozenPaths = @($candidate.paths | Sort-Object -Unique)
                    $cases.Add([pscustomobject]@{
                        seed = $caseSeed
                        finding = [string]$verification.finding
                        signature = $verification.signature
                        referencePathKinds = $livePaths
                        frozenPoolReferencePathKinds = $frozenPaths
                        liveTraceMatchesFrozenPool = ($livePaths -join "`n") -ceq ($frozenPaths -join "`n")
                        backendRuns = @($verification.runs | ForEach-Object {
                            [pscustomobject]@{
                                target = [string]$_.target
                                status = [string]$_.status
                                executionAttempted = [bool]$_.executionAttempted
                                exitCode = $_.exitCode
                            }
                        })
                    })
                }
                finally { $process.Dispose() }
            }
            $timer.Stop()
            $distinctPaths = [System.Collections.Generic.HashSet[string]]::new()
            $findings = @{}
            $backendExecutions = 0
            foreach ($case in $cases) {
                if (-not $findings.ContainsKey($case.finding)) { $findings[$case.finding] = 0 }
                $findings[$case.finding]++
                foreach ($path in $case.referencePathKinds) { [void]$distinctPaths.Add([string]$path) }
                $backendExecutions += @($case.backendRuns | Where-Object executionAttempted).Count
            }
            $staleSeeds = @($cases | Where-Object { -not $_.liveTraceMatchesFrozenPool } |
                ForEach-Object { [string]$_.seed })
            if ($staleSeeds.Count -gt 0) {
                throw "Live reference traces do not match the frozen candidate metadata for seeds: $($staleSeeds -join ',')."
            }
            [pscustomobject]@{
                name = $Name
                selectedSeeds = @($Seeds)
                caseCount = $cases.Count
                distinctLiveReferencePathKinds = $distinctPaths.Count
                backendExecutions = $backendExecutions
                findings = $findings
                durationMs = $timer.ElapsedMilliseconds
                cases = $cases.ToArray()
            }
        }

        $baselineSeeds = @($report.baseline.cases | ForEach-Object { [int]$_.seed })
        $semanticGuidedSeeds = @($report.guided.cases | ForEach-Object { [int]$_.seed })
        if ($baselineSeeds.Count -ne $ExecutionBudget -or
            $semanticGuidedSeeds.Count -ne $ExecutionBudget) {
            throw 'Live verification requires the input report arms to use the configured case budget.'
        }
        $liveCommonQuotas = @{}
        $hasSizeQuartiles = @($report.candidatePool | Where-Object {
            $null -eq $_.sizeQuartile -or [string]$_.sizeQuartile -eq ''
        }).Count -eq 0
        if ($hasSizeQuartiles) {
            foreach ($quartile in $selectedQuartiles.Keys) {
                $baselineCount = @($baselineSeeds | Where-Object {
                    [string]$candidatesBySeed[[string]$_].sizeQuartile -eq [string]$quartile
                }).Count
                $guidedCount = @($semanticGuidedSeeds | Where-Object {
                    [string]$candidatesBySeed[[string]$_].sizeQuartile -eq [string]$quartile
                }).Count
                $campaignCount = [int]$selectedQuartiles[[string]$quartile]
                $liveCommonQuotas[[string]$quartile] = [Math]::Min(
                    $campaignCount, [Math]::Min($baselineCount, $guidedCount)
                )
            }
        } else {
            $liveCommonQuotas['unstratified'] = [Math]::Min(
                $selectedSeeds.Count, [Math]::Min($baselineSeeds.Count, $semanticGuidedSeeds.Count)
            )
        }
        $liveCommonBudget = [int](($liveCommonQuotas.Values | Measure-Object -Sum).Sum)
        if ($liveCommonBudget -le 0) {
            $quotaDebug = $liveCommonQuotas | ConvertTo-Json -Compress -ErrorAction SilentlyContinue
            $campaignDebug = $selectedQuartiles | ConvertTo-Json -Compress -ErrorAction SilentlyContinue
            throw "No size-quartile-matched unique candidates are available for live verification (hasQuartiles=$hasSizeQuartiles; quotas=$quotaDebug; campaign=$campaignDebug)."
        }

        function Select-LiveSeedsBySizeProfile {
            param([int[]]$Seeds)
            $matched = [System.Collections.Generic.List[int]]::new()
            foreach ($quartile in ($liveCommonQuotas.Keys | Sort-Object)) {
                $quota = [int]$liveCommonQuotas[$quartile]
                $eligible = if ($quartile -eq 'unstratified') {
                    @($Seeds | Select-Object -First $quota)
                } else {
                    @($Seeds | Where-Object {
                        [string]$candidatesBySeed[[string]$_].sizeQuartile -eq [string]$quartile
                    } | Select-Object -First $quota)
                }
                foreach ($seedValue in $eligible) { $matched.Add([int]$seedValue) }
            }
            return $matched.ToArray()
        }
        $baselineLiveSeeds = @(Select-LiveSeedsBySizeProfile -Seeds $baselineSeeds)
        $semanticGuidedLiveSeeds = @(Select-LiveSeedsBySizeProfile -Seeds $semanticGuidedSeeds)
        $moonGrammataLiveSeeds = @(Select-LiveSeedsBySizeProfile -Seeds $selectedSeeds)
        if ($baselineLiveSeeds.Count -ne $liveCommonBudget -or
            $semanticGuidedLiveSeeds.Count -ne $liveCommonBudget -or
            $moonGrammataLiveSeeds.Count -ne $liveCommonBudget) {
            throw 'Live-verification arms could not be matched to the same unique-candidate size profile.'
        }
        $liveVerification = [pscustomobject]@{
            protocol = 'post-selection blind execution on the common unique-candidate subset: every arm is regenerated from seed and evaluated by the same current MoonSmith verifier, with identical configured targets, target timeout, case count, and source-size-quartile profile'
            selectedCaseBudget = $liveCommonBudget
            sizeQuartileCounts = $liveCommonQuotas
            sourceSizeQuartilesMatched = $hasSizeQuartiles
            targetBudgetPerArm = $targets.Count * $liveCommonBudget
            targets = $targets
            depth = $depth
            timeoutSecondsPerTarget = $timeoutSeconds
            sequential = Invoke-LiveVerificationArm -Name 'sequential' -Seeds $baselineLiveSeeds
            semanticGuided = Invoke-LiveVerificationArm -Name 'semantic-guided' -Seeds $semanticGuidedLiveSeeds
            moonGrammata = Invoke-LiveVerificationArm -Name 'moongrammata-selected' -Seeds $moonGrammataLiveSeeds
        }
        if ($liveVerification.sequential.backendExecutions -ne $liveVerification.targetBudgetPerArm -or
            $liveVerification.semanticGuided.backendExecutions -ne $liveVerification.targetBudgetPerArm -or
            $liveVerification.moonGrammata.backendExecutions -ne $liveVerification.targetBudgetPerArm) {
            throw 'Live-verification arms did not complete the same backend-execution budget.'
        }
    }

    $selectedPaths = [System.Collections.Generic.HashSet[string]]::new()
    if ($onlineLive) {
        foreach ($path in ([string]$summary.live_reference_paths -split ',' | Where-Object { $_ })) {
            [void]$selectedPaths.Add([string]$path)
        }
    } else {
        foreach ($selectedSeed in $selectedSeeds) {
            if (-not $candidateMap.ContainsKey([string]$selectedSeed)) {
                throw "MoonGrammata generated an ID outside the fixed candidate pool: $selectedSeed"
            }
            $candidate = $candidateMap[[string]$selectedSeed]
            foreach ($path in $candidate.paths) { [void]$selectedPaths.Add([string]$path) }
        }
    }
    $modeName = if ($LiveGeneratedSeeds) {
        'MoonGrammata integer-seed grammar with synchronous live MoonSmith verifier feedback'
    } elseif ($LiveTarget) {
        'MoonGrammata campaign with synchronous live MoonSmith verifier feedback over fixed seed pool'
    } else {
        'Unstratified MoonGrammata campaign on MoonSmith fixed pool'
    }
    $feedbackSource = if ($LiveGeneratedSeeds) {
        'synchronous per-Target callback on newly generated or mutated integer seeds; reference trace, finding, backend outcome, source-size bucket, and verifier cost'
    } elseif ($LiveTarget) {
        'synchronous per-Target callback: regenerated MoonSmith source, reference trace, and configured backend outcomes'
    } else {
        'cached candidate-pool report'
    }
    $candidateBody = [pscustomobject]@{
        name = $modeName
        feedbackSource = $feedbackSource
        generatorMode = if ($LiveGeneratedSeeds) { 'integer-seed-range' } elseif ($LiveTarget) { 'fixed-pool-identifiers' } else { 'fixed-pool-identifiers-cached-feedback' }
        generatedSeedMinimum = if ($LiveGeneratedSeeds) { $GeneratedSeedMinimum } else { $null }
        generatedSeedMaximum = if ($LiveGeneratedSeeds) { $GeneratedSeedMaximum } else { $null }
        liveEvaluations = if ($onlineLive) { [int]$summary.live_callback_evaluations } else { 0 }
        liveFailures = if ($onlineLive) { [int]$summary.live_callback_failures } else { 0 }
        liveGeneratorLimitObservations = if ($onlineLive) { [int]$summary.live_generator_limits } else { 0 }
        liveReferenceChecks = if ($onlineLive) { [int]$summary.live_reference_checks } else { 0 }
        liveBackendExecutions = if ($onlineLive) { [int]$summary.live_backend_executions } else { 0 }
        observations = if ($onlineLive) { @($liveObservationRecords) } else { @() }
        liveLastError = if ($onlineLive) { [string]$summary.live_error } else { '' }
        liveVerifierDurationMs = if ($onlineLive) { [long]$summary.live_verifier_duration_ms } else { 0 }
        liveReferencePathKinds = if ($onlineLive) { @($summary.live_reference_paths -split ',' | Where-Object { $_ }) } else { @() }
        liveFindings = if ($onlineLive) { @($summary.live_findings -split ',' | Where-Object { $_ } | Sort-Object) } else { @() }
        liveBackendOutcomes = if ($onlineLive) { @($summary.live_backend_outcomes -split ',' | Where-Object { $_ } | Sort-Object) } else { @() }
        liveSourceSizeBuckets = if ($onlineLive) { @($summary.live_source_size_buckets -split ',' | Where-Object { $_ } | Sort-Object) } else { @() }
        verifierKind = if (-not $onlineLive) { 'none' } elseif ($isTestDouble) { 'test-double' } else { 'scripts/verify_seed.ps1' }
        poolSize = if ($LiveGeneratedSeeds) { 0 } else { $report.candidatePool.Count }
        seed = $Seed
        requestedExecutions = [int]$summary.requested
        completedExecutions = [int]$summary.completed
        targetExecutionOrder = @($summary.target_execution_order -split ',' | Where-Object { $_ } | ForEach-Object { [int]$_ })
        uniqueCandidatesObserved = [int]$summary.unique_observed
        selectedSeeds = $selectedSeeds
        distinctReferencePathKinds = $selectedPaths.Count
        sourceSizeQuartileCounts = if ($LiveGeneratedSeeds) { @{} } else { $selectedQuartiles }
        uniqueFeedbackFeatures = [int]$summary.unique_features
        uniqueFeedbackSignatures = [int]$summary.unique_signatures
        mutationFailures = [int]$summary.mutation_failures
        corpusEntries = [int]$summary.corpus_entries
    }
    function Measure-PathKindsBySizeProfile {
        param([object[]]$Cases, [hashtable]$CountsByQuartile, [hashtable]$CandidatesBySeed)
        $set = [System.Collections.Generic.HashSet[string]]::new()
        $measuredCounts = @{}
        foreach ($quartile in $CountsByQuartile.Keys) {
            $count = [int]$CountsByQuartile[$quartile]
            $inQuartile = @($Cases | Where-Object {
                $candidateQuartile = [string]$CandidatesBySeed[[string]$_.seed].sizeQuartile
                if (-not $candidateQuartile) { $candidateQuartile = 'unstratified' }
                $candidateQuartile -eq [string]$quartile
            } | Select-Object -First $count)
            $measuredCounts[[string]$quartile] = $inQuartile.Count
            foreach ($case in $inQuartile) {
                foreach ($path in $case.referencePathKinds) { [void]$set.Add([string]$path) }
            }
        }
        return [pscustomobject]@{ distinctPathKinds = $set.Count; quartileCounts = $measuredCounts }
    }
    $baselineQuartileCounts = @{}
    foreach ($case in $report.baseline.cases) {
        $quartile = [string]$candidateMap[[string]$case.seed].sizeQuartile
        if (-not $quartile) { $quartile = 'unstratified' }
        if (-not $baselineQuartileCounts.ContainsKey($quartile)) { $baselineQuartileCounts[$quartile] = 0 }
        $baselineQuartileCounts[$quartile]++
    }
    $moonGrammataCases = @()
    if (-not $LiveGeneratedSeeds) {
        $moonGrammataCases = foreach ($selectedSeed in $selectedSeeds) {
            [pscustomobject]@{
                seed = $selectedSeed
                referencePathKinds = @($candidateMap[[string]$selectedSeed].paths)
            }
        }
    }
    $commonQuotas = @{}
    if (-not $LiveGeneratedSeeds) {
      foreach ($quartile in $baselineQuartileCounts.Keys) {
            $gCount = if ($selectedQuartiles.ContainsKey([string]$quartile)) {
                [int]$selectedQuartiles[[string]$quartile]
            } else { 0 }
        $bCount = @($report.baseline.cases | Where-Object {
                $candidateQuartile = [string]$candidateMap[[string]$_.seed].sizeQuartile
                if (-not $candidateQuartile) { $candidateQuartile = 'unstratified' }
                $candidateQuartile -eq [string]$quartile
        }).Count
        $sCount = @($report.guided.cases | Where-Object {
                $candidateQuartile = [string]$candidateMap[[string]$_.seed].sizeQuartile
                if (-not $candidateQuartile) { $candidateQuartile = 'unstratified' }
                $candidateQuartile -eq [string]$quartile
        }).Count
        $commonQuotas[[string]$quartile] = [Math]::Min($gCount, [Math]::Min($bCount, $sCount))
      }
    }
    $commonUniqueBudget = ($commonQuotas.Values | Measure-Object -Sum).Sum
    $moonGrammataComparable = Measure-PathKindsBySizeProfile -Cases $moonGrammataCases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $moonSmithBaselineComparable = Measure-PathKindsBySizeProfile -Cases $report.baseline.cases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $moonSmithGuidedComparable = Measure-PathKindsBySizeProfile -Cases $report.guided.cases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $comparableBudget = if ($onlineLive) { $null } else { $commonUniqueBudget }
    $baselineComparablePaths = if ($onlineLive) { $null } else { $moonSmithBaselineComparable.distinctPathKinds }
    $guidedComparablePaths = if ($onlineLive) { $null } else { $moonSmithGuidedComparable.distinctPathKinds }
    $moonGrammataComparablePaths = if ($onlineLive) { $null } else { $moonGrammataComparable.distinctPathKinds }
    $baselineComparableQuotas = if ($onlineLive) { $null } else { $moonSmithBaselineComparable.quartileCounts }
    $guidedComparableQuotas = if ($onlineLive) { $null } else { $moonSmithGuidedComparable.quartileCounts }
    $moonGrammataComparableQuotas = if ($onlineLive) { $null } else { $moonGrammataComparable.quartileCounts }
    $interpretation = if ($LiveGeneratedSeeds) {
        'Live integer-seed grammar prototype: MoonGrammata generates and mutates seed IDs from the declared numeric range; each Target callback regenerates the MoonSmith program for that seed and synchronously returns verifier findings before scheduling continues. No precomputed candidate outcomes are fed to the target. The run has no matched offline control and does not establish effectiveness or throughput superiority.'
    } elseif ($LiveTarget) {
        'Online-feedback wiring prototype: each MoonGrammata Target callback synchronously invokes the configured verifier and returns that execution reference-path, finding, and backend-outcome features before the campaign continues. Feedback is live rather than cached, but candidates remain identifiers from a fixed seed pool and the comparison arms still select offline. This does not establish a fair end-to-end effectiveness or throughput win; effectiveness claims require matched cost, timeout, and seed studies.'
    } elseif ($LiveVerifySelectedArms) {
        'Two-stage fixed-pool experiment: MoonGrammata selection still consumes cached MoonSmith reference-path feedback; afterward, a size-quartile-matched common unique-candidate subset from all three arms is regenerated and blindly run through the same current MoonSmith verifier on identical configured targets and equal backend-execution budgets. This measures selected-candidate outcomes, not online feedback effectiveness, throughput superiority, or general fuzzer effectiveness. Duplicate campaign observations are excluded from the unique-candidate arm; prescreen and selection costs remain additional.'
    } else {
        'Exploratory fixed-pool selection comparison only. The MoonGrammata campaign uses cached MoonSmith reference-path features and does not execute compilers or the live reference evaluator. Path coverage is also reported on an intersection subset with identical source-size quartile counts; duplicate campaign evaluations mean this subset may be smaller than the requested execution budget. This is not an end-to-end fuzzer effectiveness comparison.'
    }
    $result = [pscustomobject]@{
        schemaVersion = 1
        poolSource = if ($LiveGeneratedSeeds) { $null } else { Resolve-Path -Relative $inputPath }
        configurationReport = (Resolve-Path -Relative $inputPath)
        poolCandidateCount = if ($LiveGeneratedSeeds) { 0 } else { $report.candidatePool.Count }
        poolReferencePathKinds = if ($LiveGeneratedSeeds) { 0 } else { $pathNames.Count }
        moonGrammata = $candidateBody
        moonSmith = [pscustomobject]@{
            baselineSelectedSeeds = if ($onlineLive) { $null } else { @($report.baseline.cases | ForEach-Object { [int]$_.seed }) }
            baselineDistinctReferencePathKinds = if ($onlineLive) { $null } else { [int]$report.baseline.metrics.distinctReferencePaths }
            semanticGuidedSelectedSeeds = if ($onlineLive) { $null } else { @($report.guided.cases | ForEach-Object { [int]$_.seed }) }
            semanticGuidedDistinctReferencePathKinds = if ($onlineLive) { $null } else { [int]$report.guided.metrics.distinctReferencePaths }
            prescreenDurationMs = if ($onlineLive) { $null } else { [int]$report.prescreenDurationMs }
            selectedExecutionBudget = if ($onlineLive) { $null } else { [int]$report.executionBudgetCasesPerArm }
            backendExecutionsPerArm = if ($onlineLive) { $null } else { [int]$report.expectedBackendExecutionsPerArm }
            sizeQuartilesMatched = if ($onlineLive) { $null } else { [bool]$report.sourceSizeQuartilesMatched }
            commonUniqueCandidateBudget = $comparableBudget
            commonUniqueCandidateCountsByQuartile = $commonQuotas
            baselinePathKindsAtCommonUniqueBudget = $baselineComparablePaths
            semanticGuidedPathKindsAtCommonUniqueBudget = $guidedComparablePaths
            moonGrammataPathKindsAtCommonUniqueBudget = $moonGrammataComparablePaths
            baselineMatchedQuartileCounts = $baselineComparableQuotas
            semanticGuidedMatchedQuartileCounts = $guidedComparableQuotas
            moonGrammataMatchedQuartileCounts = $moonGrammataComparableQuotas
        }
        liveVerification = $liveVerification
        interpretation = $interpretation
        moonGrammataRevision = 'd9cf3512b636fd45e941f30010d3fceb7cc2e4fc'
        moonGrammataVersion = '0.1.1'
        moonGrammataApi = if ($LiveGeneratedSeeds) {
            'GrammarBuilder::integer + CampaignConfig + run_campaign; isolated benchmark dependency'
        } else {
            'GrammarBuilder::dictionary + CampaignConfig + run_campaign; isolated benchmark dependency'
        }
    }
    $json = $result | ConvertTo-Json -Depth 8
    if ($OutputPath) {
        $destination = [IO.Path]::GetFullPath($OutputPath)
        $destinationDirectory = Split-Path -Parent $destination
        if ($destinationDirectory) { New-Item -ItemType Directory -Path $destinationDirectory -Force | Out-Null }
        [IO.File]::WriteAllText($destination, $json + [Environment]::NewLine, [Text.UTF8Encoding]::new($false))
    }
    $json
}
finally {
    Remove-Item -LiteralPath $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
}
