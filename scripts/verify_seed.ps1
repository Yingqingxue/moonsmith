param(
    [Parameter()]
    [int]$Seed = 42,

    [Parameter()]
    [ValidateRange(0, 12)]
    [int]$Depth = 4,

    [Parameter()]
    [ValidateSet('js', 'wasm', 'wasm-gc', 'native')]
    [string[]]$Targets = @('js', 'wasm', 'wasm-gc'),

    [Parameter()]
    [string]$InjectOutputMismatchTarget = '',

    [Parameter()]
    [string]$InjectOnlyWhenSourceContains = '',

    [Parameter()]
    [string]$InjectCommonWrongOutput = '',

    [Parameter()]
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 10,

    [Parameter()]
    [string]$SourcePath = '',

    [Parameter()]
    [string]$ExpectedOutput = '',

    [Parameter()]
    [switch]$NoPersist
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$moonExe = (Get-Command moon -ErrorAction Stop).Source
$caseDirectory = Join-Path $projectRoot '.moonsmith\generated'
$casePath = if ($SourcePath) {
    (Resolve-Path -LiteralPath $SourcePath -ErrorAction Stop).Path
} else {
    Join-Path $caseDirectory ("seed_{0}_depth_{1}.mbt" -f $Seed, $Depth)
}
$referenceTrace = $null

function Invoke-CapturedProcess {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = $FilePath
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
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $process.Start()) {
        throw "Failed to start process: $FilePath"
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }
    $stopwatch.Stop()

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    $process.Dispose()

    [pscustomobject]@{
        exitCode   = $exitCode
        timedOut   = $timedOut
        stdout     = $stdout
        stderr     = $stderr
        durationMs = $stopwatch.ElapsedMilliseconds
    }
}

New-Item -ItemType Directory -Force -Path $caseDirectory | Out-Null

if (-not $SourcePath) {
    $generation = Invoke-CapturedProcess -FilePath $moonExe `
        -Arguments @('run', '--target', 'js', 'cmd/main', [string]$Seed, [string]$Depth) `
        -TimeoutSeconds $TimeoutSeconds
    if ($generation.timedOut) {
        throw "MoonSmith generator timed out for seed $Seed at depth $Depth."
    }
    if ($generation.exitCode -ne 0) {
        throw "MoonSmith failed to generate seed $Seed at depth $Depth.`n$($generation.stderr)"
    }

    $source = $generation.stdout.TrimEnd() + "`n"
    Set-Content -LiteralPath $casePath -Value $source -Encoding utf8 -NoNewline

    $referenceRun = Invoke-CapturedProcess -FilePath $moonExe `
        -Arguments @('run', '--target', 'js', 'cmd/main', [string]$Seed, [string]$Depth, '--expected') `
        -TimeoutSeconds $TimeoutSeconds
    if ($referenceRun.timedOut -or $referenceRun.exitCode -ne 0) {
        throw "Reference evaluation failed for seed $Seed at depth $Depth.`n$($referenceRun.stderr)"
    }
    $ExpectedOutput = $referenceRun.stdout

    $traceRun = Invoke-CapturedProcess -FilePath $moonExe `
        -Arguments @('run', '--target', 'js', 'cmd/main', [string]$Seed, [string]$Depth, '--trace') `
        -TimeoutSeconds $TimeoutSeconds
    if ($traceRun.timedOut -or $traceRun.exitCode -ne 0) {
        throw "Reference path trace failed for seed $Seed at depth $Depth.`n$($traceRun.stderr)"
    }
    $referenceTrace = $traceRun.stdout | ConvertFrom-Json
}

$runs = foreach ($target in $Targets) {
    $missingNativeCompiler = $target -eq 'native' -and
        $null -eq (Get-Command cc, gcc, clang -ErrorAction SilentlyContinue | Select-Object -First 1)

    if ($missingNativeCompiler) {
        $status = 'unavailable'
        $exitCode = -1
        $output = ''
        $errorOutput = 'native backend unavailable: no system C compiler found (cc, gcc, or clang)'
        $durationMs = 0
    }
    else {
        $build = Invoke-CapturedProcess -FilePath $moonExe `
            -Arguments @('run', '--target', $target, $casePath, '--build-only', '--deny-warn') `
            -TimeoutSeconds $TimeoutSeconds
    }

    if (-not $missingNativeCompiler -and $build.timedOut) {
        $status = 'timed-out'
        $exitCode = -1
        $output = ''
        $errorOutput = "build timed out after $TimeoutSeconds seconds"
        $durationMs = $build.durationMs
    }
    elseif (-not $missingNativeCompiler -and $build.exitCode -ne 0) {
        $status = 'compile-failed'
        $exitCode = $build.exitCode
        $output = ''
        $errorOutput = ($build.stderr + "`n" + $build.stdout).Trim()
        $durationMs = $build.durationMs
    }
    elseif (-not $missingNativeCompiler) {
        $execution = Invoke-CapturedProcess -FilePath $moonExe `
            -Arguments @('run', '--target', $target, $casePath, '--deny-warn') `
            -TimeoutSeconds $TimeoutSeconds
        $durationMs = $build.durationMs + $execution.durationMs
        if ($execution.timedOut) {
            $status = 'timed-out'
            $exitCode = -1
            $output = ''
            $errorOutput = "execution timed out after $TimeoutSeconds seconds"
        }
        elseif ($execution.exitCode -eq 0) {
            $status = 'succeeded'
            $exitCode = 0
            $output = $execution.stdout
            $errorOutput = $execution.stderr
        }
        else {
            $status = 'runtime-failed'
            $exitCode = $execution.exitCode
            $output = ''
            $errorOutput = ($execution.stderr + "`n" + $execution.stdout).Trim()
        }
    }

    [pscustomobject]@{
        target     = $target
        status     = $status
        exitCode   = $exitCode
        output     = $output
        error      = $errorOutput
        durationMs = $durationMs
    }
}

$injection = $null
$sourceForInjection = if ($InjectOnlyWhenSourceContains) {
    Get-Content -LiteralPath $casePath -Raw -Encoding utf8
} else {
    ''
}
if ($InjectOutputMismatchTarget -and
    (-not $InjectOnlyWhenSourceContains -or
        $sourceForInjection.Contains($InjectOnlyWhenSourceContains))) {
    $injectedRun = $runs | Where-Object target -eq $InjectOutputMismatchTarget
    if ($null -eq $injectedRun) {
        throw "Injection target '$InjectOutputMismatchTarget' is not in the target matrix."
    }
    $injectedRun.output = $injectedRun.output + "`n[moonsmith-injected-mismatch]"
    $injection = [pscustomobject]@{
        kind   = 'output-mismatch'
        target = $InjectOutputMismatchTarget
        sourceTrigger = $InjectOnlyWhenSourceContains
    }
}
if ($InjectCommonWrongOutput) {
    if ($null -ne $injection) {
        throw 'Only one fault injection mode may be selected.'
    }
    foreach ($run in $runs) {
        if ($run.status -eq 'succeeded') {
            $run.output = $InjectCommonWrongOutput + "`n"
        }
    }
    $injection = [pscustomobject]@{
        kind = 'common-wrong-output'
        target = 'all-successful'
    }
}

$oracleArgs = [System.Collections.Generic.List[string]]::new()
$oracleArgs.Add($(if ($ExpectedOutput) { 'some' } else { 'none' }))
$oracleArgs.Add([string]$ExpectedOutput)
foreach ($run in $runs) {
    $oracleArgs.Add([string]$run.target)
    $oracleArgs.Add([string]$run.status)
    $oracleArgs.Add([string]$run.exitCode)
    $oracleArgs.Add([string]$run.output)
    $oracleArgs.Add([string]$run.error)
    $oracleArgs.Add([string]$projectRoot)
    $oracleArgs.Add([string]$casePath)
}

$oracleCommandArgs = [System.Collections.Generic.List[string]]::new()
$oracleCommandArgs.Add('run')
$oracleCommandArgs.Add('--target')
$oracleCommandArgs.Add('js')
$oracleCommandArgs.Add('cmd/oracle')
foreach ($argument in $oracleArgs) {
    $oracleCommandArgs.Add($argument)
}
$oracleRun = Invoke-CapturedProcess -FilePath $moonExe `
    -Arguments $oracleCommandArgs.ToArray() -TimeoutSeconds $TimeoutSeconds
if ($oracleRun.timedOut) {
    throw "MoonBit oracle timed out after $TimeoutSeconds seconds."
}
if ($oracleRun.exitCode -ne 0) {
    throw "MoonBit oracle failed.`n$($oracleRun.stderr)"
}
$oracle = $oracleRun.stdout | ConvertFrom-Json

$caseId = $null
$savedTo = $null
if ($oracle.kind -ne 'consistent') {
    $signatureBytes = [System.Text.Encoding]::UTF8.GetBytes([string]$oracle.signature)
    $signatureHash = [System.Security.Cryptography.SHA256]::HashData($signatureBytes)
    $caseId = [System.Convert]::ToHexString($signatureHash).Substring(0, 16).ToLowerInvariant()
    $collection = if ($null -ne $injection) {
        'injected'
    }
    elseif ($oracle.kind -eq 'environment-failure') {
        'environment'
    }
    else {
        'corpus'
    }
    $savedTo = Join-Path $projectRoot ".moonsmith\$collection\$caseId"
}
if ($NoPersist) {
    $savedTo = $null
}

$report = [pscustomobject]@{
    schemaVersion = 3
    caseId        = $caseId
    seed          = $Seed
    depth         = $Depth
    casePath      = $casePath
    finding       = $oracle.kind
    signature     = $oracle.signature
    reductionKey  = $oracle.reductionKey
    referenceChecked = $oracle.referenceChecked
    expectedOutput = $oracle.expectedOutput
    referenceTrace = $referenceTrace
    injection     = $injection
    timeoutSeconds = $TimeoutSeconds
    toolchainVersion = (& $moonExe version | Select-Object -First 1)
    hostOS = [System.Runtime.InteropServices.RuntimeInformation]::OSDescription
    powerShellVersion = $PSVersionTable.PSVersion.ToString()
    sourceSha256 = (Get-FileHash -LiteralPath $casePath -Algorithm SHA256).Hash.ToLowerInvariant()
    savedTo       = $savedTo
    runs          = @($runs)
}

$reportJson = $report | ConvertTo-Json -Depth 5
if ($null -ne $savedTo -and -not (Test-Path -LiteralPath $savedTo)) {
    New-Item -ItemType Directory -Force -Path $savedTo | Out-Null
    Copy-Item -LiteralPath $casePath -Destination (Join-Path $savedTo 'source.mbt')
    Set-Content -LiteralPath (Join-Path $savedTo 'report.json') `
        -Value $reportJson -Encoding utf8
}

$reportJson

if ($oracle.kind -ne 'consistent') {
    exit 1
}
