param(
    [Parameter()][int]$SeedStart = 0,
    [Parameter()][ValidateRange(2, 10000)][int]$CandidateCount = 40,
    [Parameter()][ValidateRange(1, 10000)][int]$ExecutionBudget = 10,
    [Parameter()][ValidateRange(0, 12)][int]$Depth = 4,
    [Parameter()][ValidateSet('js', 'wasm', 'wasm-gc', 'native', 'native-release')]
    [string[]]$Targets = @('js', 'wasm', 'wasm-gc'),
    [Parameter()][ValidateRange(1, 300)][int]$TimeoutSeconds = 30,
    [Parameter()][switch]$GuidedFirst,
    [Parameter()][switch]$SizeMatched,
    [Parameter()][string]$OutputPath = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'semantic_selection.ps1')
if ($ExecutionBudget -gt $CandidateCount) { throw 'ExecutionBudget exceeds CandidateCount.' }
if (([long]$SeedStart + [long]$CandidateCount - 1) -gt [int]::MaxValue) {
    throw 'Candidate range exceeds the 32-bit signed Int maximum.'
}
if ($Targets.Count -eq 0 -or @($Targets | Select-Object -Unique).Count -ne $Targets.Count) {
    throw 'Targets must be a nonempty set without duplicates.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
$runDirectory = Join-Path $projectRoot '.moonsmith\runs'
if (-not $OutputPath) {
    $runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff')
    $OutputPath = Join-Path $runDirectory "selection_$runId.json"
}
$moonExe = (Get-Command moon -ErrorAction Stop).Source
$toolchainVersion = (& $moonExe version | Select-Object -First 1)
$gitHead = (& git -C $projectRoot rev-parse HEAD).Trim()
$gitDirty = @(& git -C $projectRoot status --porcelain).Count -gt 0

function Get-SelectionHarnessDigest {
    $parts = foreach ($relativePath in @(
        'moon.mod', 'moon.pkg', 'moonsmith.mbt', 'reference.mbt', 'oracle.mbt',
        'cmd/main/main.mbt', 'scripts/verify_seed.ps1',
        'scripts/semantic_selection.ps1', 'scripts/compare_semantic_selection.ps1'
    )) {
        $path = Join-Path $projectRoot $relativePath
        "${relativePath}:$((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash)"
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($parts -join "`n"))
    [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}
$harnessDigestStart = Get-SelectionHarnessDigest

function Invoke-MoonCli {
    param([int]$Seed, [string[]]$Arguments, [string]$Purpose)
    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $moonExe
    $startInfo.WorkingDirectory = $projectRoot
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) {
        $startInfo.ArgumentList.Add($argument)
    }
    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    try {
        if (-not $process.Start()) { throw "Failed to start $Purpose for seed $Seed." }
        $stdoutTask = $process.StandardOutput.ReadToEndAsync()
        $stderrTask = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $process.Kill($true)
            $process.WaitForExit()
            throw "$Purpose timed out for seed $Seed after $TimeoutSeconds seconds."
        }
        $stdout = $stdoutTask.GetAwaiter().GetResult()
        $stderr = $stderrTask.GetAwaiter().GetResult()
        if ($process.ExitCode -ne 0) {
            throw "$Purpose failed for seed ${Seed}: $stderr"
        }
        return $stdout
    }
    finally { $process.Dispose() }
}

function Invoke-ReferenceTrace {
    param([int]$Seed)
    $output = Invoke-MoonCli -Seed $Seed -Purpose 'Reference prescreen' -Arguments @(
        'run', '--target', 'js', 'cmd/main', [string]$Seed, [string]$Depth, '--trace'
    )
    return $output | ConvertFrom-Json
}

function Get-GeneratedSourceLineCount {
    param([int]$Seed)
    $source = Invoke-MoonCli -Seed $Seed -Purpose 'Source-size prescreen' -Arguments @(
        'run', '--target', 'js', 'cmd/main', [string]$Seed, [string]$Depth
    )
    return [regex]::Matches($source, "`n").Count
}

$prescreenTimer = [System.Diagnostics.Stopwatch]::StartNew()
$candidates = [System.Collections.Generic.List[object]]::new()
for ($offset = 0; $offset -lt $CandidateCount; $offset++) {
    $seed = [int]([long]$SeedStart + $offset)
    $trace = Invoke-ReferenceTrace -Seed $seed
    $sourceLineCount = Get-GeneratedSourceLineCount -Seed $seed
    $candidates.Add([pscustomobject]@{
        seed = $seed
        paths = @($trace.visited | Sort-Object -Unique)
        sourceLineCount = $sourceLineCount
    })
}
$prescreenTimer.Stop()
$baselineSeeds = @($candidates | Select-Object -First $ExecutionBudget | ForEach-Object { $_.seed })
$null = Set-MoonSmithSourceSizeQuartiles -Candidates $candidates.ToArray()
$baselineCandidates = @($candidates | Where-Object { $baselineSeeds -contains $_.seed })
$sizeQuotas = if ($SizeMatched) {
    Get-MoonSmithSizeQuotas -Candidates $baselineCandidates
} else { $null }
$guided = @(Select-MoonSmithSemanticSeeds -Candidates $candidates.ToArray() `
    -Budget $ExecutionBudget -SizeQuotas $sizeQuotas)
$guidedSeeds = @($guided | ForEach-Object { $_.seed })
$baselineSizeCounts = Get-MoonSmithSeedSizeCounts -Seeds $baselineSeeds -Candidates $candidates.ToArray()
$guidedSizeCounts = Get-MoonSmithSeedSizeCounts -Seeds $guidedSeeds -Candidates $candidates.ToArray()
$sourceSizeQuartilesMatched = $true
foreach ($quartile in @($baselineSizeCounts.Keys + $guidedSizeCounts.Keys | Sort-Object -Unique)) {
    $baselineCount = if ($baselineSizeCounts.ContainsKey($quartile)) { $baselineSizeCounts[$quartile] } else { 0 }
    $guidedCount = if ($guidedSizeCounts.ContainsKey($quartile)) { $guidedSizeCounts[$quartile] } else { 0 }
    if ($baselineCount -ne $guidedCount) { $sourceSizeQuartilesMatched = $false }
}

function Invoke-SelectionArm {
    param([string]$Name, [int[]]$Seeds)
    $timer = [System.Diagnostics.Stopwatch]::StartNew()
    $reports = [System.Collections.Generic.List[object]]::new()
    foreach ($seed in $Seeds) {
        $raw = & $verifyScript -Seed $seed -Depth $Depth -Targets $Targets `
            -TimeoutSeconds $TimeoutSeconds
        $report = $raw | ConvertFrom-Json
        $bodyHash = $null
        if ($report.casePath -and (Test-Path -LiteralPath $report.casePath)) {
            $source = Get-Content -LiteralPath $report.casePath -Raw -Encoding utf8
            $firstNewline = $source.IndexOf("`n")
            $body = if ($firstNewline -ge 0) { $source.Substring($firstNewline + 1) } else { $source }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            $bodyHash = [System.Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData($bytes)
            ).ToLowerInvariant()
        }
        $report | Add-Member -NotePropertyName bodySha256 -NotePropertyValue $bodyHash
        $reports.Add($report)
    }
    $timer.Stop()
    [pscustomobject]@{
        name = $Name
        seeds = $Seeds
        durationMs = $timer.ElapsedMilliseconds
        metrics = Get-MoonSmithSelectionMetrics -Reports $reports.ToArray()
        cases = @($reports | ForEach-Object {
            [pscustomobject]@{
                seed = $_.seed
                finding = $_.finding
                caseId = $_.caseId
                savedTo = $_.savedTo
                signature = $_.signature
                referenceChecked = $_.referenceChecked
                bodySha256 = $_.bodySha256
                sourceLineCount = $_.sourceLineCount
                referencePathKinds = @($_.referenceTrace.visited | Sort-Object -Unique)
                backendStatuses = @($_.runs | ForEach-Object { "$( $_.target ):$( $_.status )" })
            }
        })
    }
}

if ($GuidedFirst) {
    $guidedArm = Invoke-SelectionArm -Name semantic-guided -Seeds $guidedSeeds
    $baseline = Invoke-SelectionArm -Name sequential -Seeds $baselineSeeds
} else {
    $baseline = Invoke-SelectionArm -Name sequential -Seeds $baselineSeeds
    $guidedArm = Invoke-SelectionArm -Name semantic-guided -Seeds $guidedSeeds
}
$expectedAttempts = $ExecutionBudget * $Targets.Count
$equalBackendBudget = $baseline.metrics.backendExecutions -eq $expectedAttempts -and
    $guidedArm.metrics.backendExecutions -eq $expectedAttempts
$unexpectedFindings = @($baseline.cases + $guidedArm.cases |
    Where-Object finding -ne 'consistent').Count
$harnessDigestEnd = Get-SelectionHarnessDigest
$report = [pscustomobject]@{
    schemaVersion = 1
    method = if ($SizeMatched) {
        'greedy inverse-pool-frequency reference-path novelty, constrained to the sequential arm source-size quartile counts'
    } else {
        'greedy inverse-pool-frequency reference-path novelty with deterministic seed tie-break'
    }
    referenceTraceSource = 'MoonBit reference interpreter; not backend runtime coverage'
    seedStart = $SeedStart
    candidateCount = $CandidateCount
    executionBudgetCasesPerArm = $ExecutionBudget
    configuredTargets = $Targets
    expectedBackendExecutionsPerArm = $expectedAttempts
    equalBackendExecutionBudget = $equalBackendBudget
    unexpectedFindingCount = $unexpectedFindings
    depth = $Depth
    timeoutSeconds = $TimeoutSeconds
    toolchainVersion = $toolchainVersion
    gitHead = $gitHead
    gitDirty = $gitDirty
    harnessDigestStart = $harnessDigestStart
    harnessDigestEnd = $harnessDigestEnd
    harnessChangedDuringRun = $harnessDigestStart -ne $harnessDigestEnd
    prescreenDurationMs = $prescreenTimer.ElapsedMilliseconds
    candidatePool = @($candidates)
    baseline = $baseline
    guided = $guidedArm
    overlapSeedCount = @($baselineSeeds | Where-Object { $guidedSeeds -contains $_ }).Count
    baselineSourceSizeQuartileCounts = $baselineSizeCounts
    guidedSourceSizeQuartileCounts = $guidedSizeCounts
    sourceSizeQuartilesMatched = $sourceSizeQuartilesMatched
    executionOrder = if ($GuidedFirst) { @('guided', 'baseline') } else { @('baseline', 'guided') }
    caution = 'Compare path diversity only when equalBackendExecutionBudget is true; prescreen cost is additional, and one cohort cannot establish effectiveness. Native debug has known upstream #1322 ICE and should not be treated as a newly discovered finding.'
}
$outputDirectory = Split-Path -Parent $OutputPath
if ($outputDirectory) { New-Item -ItemType Directory -Force -Path $outputDirectory | Out-Null }
$json = $report | ConvertTo-Json -Depth 8
Set-Content -LiteralPath $OutputPath -Value $json -Encoding utf8
$json
if (-not $equalBackendBudget) { exit 2 }
if ($report.harnessChangedDuringRun) { exit 3 }
if ($unexpectedFindings -gt 0) { exit 1 }
