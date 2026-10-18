param(
    [Parameter(Mandatory)][string]$InputReport,
    [Parameter()][ValidateRange(1, 10000)][int]$ExecutionBudget = 20,
    [Parameter()][long]$Seed = 20261018,
    [Parameter()][string]$OutputPath = '',
    [Parameter()][switch]$LiveVerifySelectedArms
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$inputPath = (Resolve-Path -LiteralPath $InputReport -ErrorAction Stop).Path
$report = Get-Content -LiteralPath $inputPath -Raw -Encoding utf8 | ConvertFrom-Json
if ($report.schemaVersion -ne 1 -or $report.candidatePool.Count -lt $ExecutionBudget) {
    throw 'Input must be a schemaVersion 1 MoonSmith selection report with enough candidates.'
}
if ($report.harnessChangedDuringRun -or -not $report.equalBackendExecutionBudget) {
    throw 'Refusing an incomplete or internally invalid MoonSmith candidate-pool report.'
}

$pathNames = @($report.candidatePool | ForEach-Object { $_.paths } | Sort-Object -Unique)
if ($pathNames.Count -eq 0) { throw 'Candidate pool has no reference-path features.' }
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
    $args = @('run', '--target', 'js', 'cmd/main', '--', [string]$ExecutionBudget, [string]$Seed,
        ($pathNames -join ',')) + @($specifications)
    Push-Location $tempRoot
    try { $raw = & $moon @args 2>&1 }
    finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) { throw "MoonGrammata benchmark failed: $($raw -join [Environment]::NewLine)" }
    $text = $raw -join [Environment]::NewLine
    if (-not $text.Contains('MOONSMITH_FIXED_POOL_V1')) {
        throw "MoonGrammata benchmark did not emit its result marker: $text"
    }
    $summary = @{}
    foreach ($line in $text -split '\r?\n') {
        if ($line -match '^([a-z_]+)=(.*)$') { $summary[$Matches[1]] = $Matches[2] }
    }
    if ([int]$summary.completed -ne $ExecutionBudget -or
        [int]$summary.candidate_pool -ne $report.candidatePool.Count) {
        throw 'MoonGrammata campaign did not honor the fixed pool and execution budget.'
    }
    $selectedSeeds = @($summary.observed_seeds -split ',' | Where-Object { $_ -ne '' } | ForEach-Object { [int]$_ })
    $candidateMap = @{}
    foreach ($candidate in $report.candidatePool) { $candidateMap[[string]$candidate.seed] = $candidate }
    $selectedQuartiles = @{}
    foreach ($selectedSeed in $selectedSeeds) {
        $quartile = [string]$candidateMap[[string]$selectedSeed].sizeQuartile
        if (-not $quartile) { $quartile = 'unstratified' }
        if (-not $selectedQuartiles.ContainsKey($quartile)) { $selectedQuartiles[$quartile] = 0 }
        $selectedQuartiles[$quartile]++
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
    foreach ($selectedSeed in $selectedSeeds) {
        if (-not $candidateMap.ContainsKey([string]$selectedSeed)) {
            throw "MoonGrammata generated an ID outside the fixed candidate pool: $selectedSeed"
        }
        $candidate = $candidateMap[[string]$selectedSeed]
        foreach ($path in $candidate.paths) { [void]$selectedPaths.Add([string]$path) }
    }
    $candidateBody = [pscustomobject]@{
        name = 'Unstratified MoonGrammata campaign on MoonSmith fixed pool'
        poolSize = $report.candidatePool.Count
        seed = $Seed
        requestedExecutions = [int]$summary.requested
        completedExecutions = [int]$summary.completed
        uniqueCandidatesObserved = [int]$summary.unique_observed
        selectedSeeds = $selectedSeeds
        distinctReferencePathKinds = $selectedPaths.Count
        sourceSizeQuartileCounts = $selectedQuartiles
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
    $moonGrammataCases = foreach ($selectedSeed in $selectedSeeds) {
        [pscustomobject]@{
            seed = $selectedSeed
            referencePathKinds = @($candidateMap[[string]$selectedSeed].paths)
        }
    }
    $commonQuotas = @{}
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
    $commonUniqueBudget = ($commonQuotas.Values | Measure-Object -Sum).Sum
    $moonGrammataComparable = Measure-PathKindsBySizeProfile -Cases $moonGrammataCases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $moonSmithBaselineComparable = Measure-PathKindsBySizeProfile -Cases $report.baseline.cases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $moonSmithGuidedComparable = Measure-PathKindsBySizeProfile -Cases $report.guided.cases `
        -CountsByQuartile $commonQuotas -CandidatesBySeed $candidateMap
    $result = [pscustomobject]@{
        schemaVersion = 1
        poolSource = (Resolve-Path -Relative $inputPath)
        poolCandidateCount = $report.candidatePool.Count
        poolReferencePathKinds = $pathNames.Count
        moonGrammata = $candidateBody
        moonSmith = [pscustomobject]@{
            baselineSelectedSeeds = @($report.baseline.cases | ForEach-Object { [int]$_.seed })
            baselineDistinctReferencePathKinds = [int]$report.baseline.metrics.distinctReferencePaths
            semanticGuidedSelectedSeeds = @($report.guided.cases | ForEach-Object { [int]$_.seed })
            semanticGuidedDistinctReferencePathKinds = [int]$report.guided.metrics.distinctReferencePaths
            prescreenDurationMs = [int]$report.prescreenDurationMs
            selectedExecutionBudget = [int]$report.executionBudgetCasesPerArm
            backendExecutionsPerArm = [int]$report.expectedBackendExecutionsPerArm
            sizeQuartilesMatched = [bool]$report.sourceSizeQuartilesMatched
            commonUniqueCandidateBudget = $commonUniqueBudget
            commonUniqueCandidateCountsByQuartile = $commonQuotas
            baselinePathKindsAtCommonUniqueBudget = $moonSmithBaselineComparable.distinctPathKinds
            semanticGuidedPathKindsAtCommonUniqueBudget = $moonSmithGuidedComparable.distinctPathKinds
            moonGrammataPathKindsAtCommonUniqueBudget = $moonGrammataComparable.distinctPathKinds
            baselineMatchedQuartileCounts = $moonSmithBaselineComparable.quartileCounts
            semanticGuidedMatchedQuartileCounts = $moonSmithGuidedComparable.quartileCounts
            moonGrammataMatchedQuartileCounts = $moonGrammataComparable.quartileCounts
        }
        liveVerification = $liveVerification
        interpretation = if ($LiveVerifySelectedArms) {
            'Two-stage fixed-pool experiment: MoonGrammata selection still consumes cached MoonSmith reference-path feedback; afterward, a size-quartile-matched common unique-candidate subset from all three arms is regenerated and blindly run through the same current MoonSmith verifier on identical configured targets and equal backend-execution budgets. This measures selected-candidate outcomes, not online feedback effectiveness, throughput superiority, or general fuzzer effectiveness. Duplicate campaign observations are excluded from the unique-candidate arm; prescreen and selection costs remain additional.'
        } else {
            'Exploratory fixed-pool selection comparison only. The MoonGrammata campaign uses cached MoonSmith reference-path features and does not execute compilers or the live reference evaluator. Path coverage is also reported on an intersection subset with identical source-size quartile counts; duplicate campaign evaluations mean this subset may be smaller than the requested execution budget. This is not an end-to-end fuzzer effectiveness comparison.'
        }
        moonGrammataRevision = 'd9cf3512b636fd45e941f30010d3fceb7cc2e4fc'
        moonGrammataVersion = '0.1.1'
        moonGrammataApi = 'GrammarBuilder::dictionary + CampaignConfig + run_campaign; isolated benchmark dependency'
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
