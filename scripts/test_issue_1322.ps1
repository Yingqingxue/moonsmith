$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$moonExe = (Get-Command moon -ErrorAction Stop).Source
$repro = 'regressions/issue_1322_native_valtype_enum_array/repro.mbt'
$expectedOutput = "0`nx"

function Invoke-MoonRun {
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,

        [Parameter(Mandatory)]
        [int]$TimeoutSeconds
    )

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
    if (-not $process.Start()) {
        throw "Failed to start MoonBit: $moonExe"
    }

    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $timedOut = -not $process.WaitForExit($TimeoutSeconds * 1000)
    if ($timedOut) {
        $process.Kill($true)
        $process.WaitForExit()
    }

    $stdout = $stdoutTask.GetAwaiter().GetResult()
    $stderr = $stderrTask.GetAwaiter().GetResult()
    $exitCode = if ($timedOut) { -1 } else { $process.ExitCode }
    $process.Dispose()

    [pscustomobject]@{
        exitCode = $exitCode
        timedOut = $timedOut
        stdout = $stdout
        stderr = $stderr
        output = (($stdout + $stderr) -replace "`r`n", "`n").Trim()
    }
}

function Assert-ExpectedOutput {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [object]$Result
    )

    if ($Result.timedOut -or $Result.exitCode -ne 0 -or
        $Result.output -ne $expectedOutput) {
        throw "$Name did not produce the expected two-line output. Exit=$($Result.exitCode); timedOut=$($Result.timedOut); output=$($Result.output)"
    }
}

$wasmGc = Invoke-MoonRun -Arguments @('run', $repro, '--target', 'wasm-gc') -TimeoutSeconds 180
Assert-ExpectedOutput -Name 'wasm-gc' -Result $wasmGc

$nativeCompiler = Get-Command cl, clang-cl, gcc, clang, cc `
    -ErrorAction SilentlyContinue | Select-Object -First 1
$nativeDebugClassification = 'unavailable-no-c-compiler'
$nativeReleaseClassification = 'unavailable-no-c-compiler'
$nativeDebug = $null
$nativeRelease = $null

if ($null -ne $nativeCompiler) {
    $nativeDebug = Invoke-MoonRun -Arguments @('run', $repro, '--target', 'native') -TimeoutSeconds 180
    $nativeRelease = Invoke-MoonRun -Arguments @('run', $repro, '--target', 'native', '--release') -TimeoutSeconds 180
    Assert-ExpectedOutput -Name 'native release' -Result $nativeRelease
    $nativeReleaseClassification = 'expected-output'

    if (-not $nativeDebug.timedOut -and $nativeDebug.exitCode -eq 0 -and
        $nativeDebug.output -eq $expectedOutput) {
        $nativeDebugClassification = 'not-reproduced-on-this-runner'
    } elseif (-not $nativeDebug.timedOut -and
        $nativeDebug.output -match 'Machine_error\(kind=unsupported; who="Machine_of_clam_lower\.lower_array_make"; message="uninitialized non-null GC ref arrays are not lowered"') {
        $nativeDebugClassification = 'upstream-issue-signature-reproduced'
    } else {
        throw "Native debug produced neither the expected output nor the known #1322 diagnostic. Exit=$($nativeDebug.exitCode); timedOut=$($nativeDebug.timedOut); output=$($nativeDebug.output)"
    }
}

$result = [pscustomobject]@{
    upstreamIssue = 1322
    sourceIssue = 'https://github.com/moonbitlang/moonbit-docs/issues/1322'
    toolchain = (& moon version | Select-Object -First 1)
    runnerPlatform = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } elseif ($IsMacOS) { 'macos' } else { 'unknown' }
    nativeCompiler = if ($nativeCompiler) { $nativeCompiler.Name } else { $null }
    nativeDebugClassification = $nativeDebugClassification
    nativeDebugExitCode = if ($nativeDebug) { $nativeDebug.exitCode } else { $null }
    nativeReleaseClassification = $nativeReleaseClassification
    nativeReleaseExitCode = if ($nativeRelease) { $nativeRelease.exitCode } else { $null }
    wasmGcExitCode = $wasmGc.exitCode
    expectedOutput = @('0', 'x')
    outputSource = 'External upstream reproducer; not discovered by MoonSmith.'
}

$evidenceDirectory = Join-Path $projectRoot '.moonsmith'
New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
$evidencePath = Join-Path $evidenceDirectory 'issue_1322.json'
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $evidencePath -Encoding utf8
$result
