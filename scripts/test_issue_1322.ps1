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

function Normalize-ProgramOutput {
    param([AllowNull()][string]$Value)

    if ($null -eq $Value) {
        return ''
    }
    return ($Value -replace "`r`n", "`n" -replace "`r", "`n").Trim()
}

$wasmGc = Invoke-MoonRun -Arguments @('run', $repro, '--target', 'wasm-gc') -TimeoutSeconds 180
Assert-ExpectedOutput -Name 'wasm-gc' -Result $wasmGc

$nativeCompiler = Get-Command cl, clang-cl, gcc, clang, cc `
    -ErrorAction SilentlyContinue | Select-Object -First 1
$nativeCompilerVersion = $null
if ($nativeCompiler) {
    $versionLines = if ($nativeCompiler.Name -match '^cl(\.exe)?$') {
        @(& $nativeCompiler.Source '/?' 2>&1 | ForEach-Object { $_.ToString() })
    } else {
        @(& $nativeCompiler.Source '--version' 2>&1 | ForEach-Object { $_.ToString() })
    }
    $nativeCompilerVersion = ($versionLines | Select-Object -First 12) -join "`n"
    if ($nativeCompilerVersion.Length -gt 2048) {
        $nativeCompilerVersion = $nativeCompilerVersion.Substring(0, 2048)
    }
    $versionPattern = if ($nativeCompiler.Name -match '^cl(\.exe)?$') {
        'Microsoft.*(Compiler|C/C\+\+)'
    } else {
        '(?i)(gcc|clang|compiler|version|\bcc\s*\()'
    }
    if ($nativeCompilerVersion -notmatch $versionPattern) {
        throw "Could not capture a recognizable version string from native compiler '$($nativeCompiler.Name)': $nativeCompilerVersion"
    }
}
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

$verifyScript = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'verify_seed.ps1'))
$sourcePath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $repro))
$verifyForCommand = $verifyScript.Replace("'", "''")
$sourceForCommand = $sourcePath.Replace("'", "''")
$expectedForOracle = "$expectedOutput`n"
$expectedBase64 = [System.Convert]::ToBase64String(
    [System.Text.Encoding]::UTF8.GetBytes($expectedForOracle)
)
$oracleCommand = "`$expected = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String('$expectedBase64')); & '$verifyForCommand' -Seed 0 -Depth 0 -Targets @('native','native-release','wasm-gc') -TimeoutSeconds 180 -SourcePath '$sourceForCommand' -ExpectedOutput `$expected -NoPersist"
$oracleRaw = & pwsh -NoProfile -Command $oracleCommand
$oracleExitCode = $LASTEXITCODE
if ($oracleExitCode -notin @(0, 1)) {
    throw "MoonSmith's differential verifier exited unexpectedly: $oracleExitCode"
}
$oracleReport = $oracleRaw | ConvertFrom-Json
if ($oracleReport.sourceLineCount -le 0 -or $null -ne $oracleReport.sourceLineLimit) {
    throw 'The source-path verification report did not record its line count without claiming the generated-source limit.'
}
$oracleNativeRun = $oracleReport.runs | Where-Object target -eq 'native' | Select-Object -First 1
$oracleNativeReleaseRun = $oracleReport.runs | Where-Object target -eq 'native-release' | Select-Object -First 1
$oracleWasmGcRun = $oracleReport.runs | Where-Object target -eq 'wasm-gc' | Select-Object -First 1
if ($null -eq $oracleNativeRun -or $null -eq $oracleNativeReleaseRun -or $null -eq $oracleWasmGcRun -or
    $oracleWasmGcRun.status -ne 'succeeded' -or
    (Normalize-ProgramOutput $oracleWasmGcRun.output) -ne $expectedOutput) {
    throw "MoonSmith's differential verifier did not retain the expected Wasm-GC control. Status=$($oracleWasmGcRun.status); output=[$(Normalize-ProgramOutput $oracleWasmGcRun.output)]"
}
if ($null -eq $nativeCompiler) {
    if ($oracleNativeRun.status -ne 'unavailable' -or
        $oracleNativeReleaseRun.status -ne 'unavailable') {
        throw 'MoonSmith did not classify both native modes as unavailable without a C compiler.'
    }
} elseif ($nativeDebugClassification -eq 'upstream-issue-signature-reproduced') {
    if ($oracleNativeRun.status -ne 'compile-failed' -or
        $oracleNativeRun.error -notmatch 'uninitialized non-null GC ref arrays are not lowered' -or
        $oracleNativeReleaseRun.status -ne 'succeeded' -or
        (Normalize-ProgramOutput $oracleNativeReleaseRun.output) -ne $expectedOutput) {
        throw "MoonSmith's verifier did not classify the known native debug failure as a compile failure."
    }
} elseif ($oracleNativeRun.status -ne 'succeeded' -or
    (Normalize-ProgramOutput $oracleNativeRun.output) -ne $expectedOutput -or
    $oracleNativeReleaseRun.status -ne 'succeeded' -or
    (Normalize-ProgramOutput $oracleNativeReleaseRun.output) -ne $expectedOutput) {
    throw "MoonSmith's verifier did not retain expected output in both native modes. Debug=$($oracleNativeRun.status):[$(Normalize-ProgramOutput $oracleNativeRun.output)]; Release=$($oracleNativeReleaseRun.status):[$(Normalize-ProgramOutput $oracleNativeReleaseRun.output)]"
}

# Exercise the upstream trigger and a two-element growth extension through
# MoonSmith's generated AST, reference evaluator, and generic verifier. The
# checked-in source fixture above remains the exact upstream reproducer.
$generatedTargets = @('js', 'wasm', 'wasm-gc')
if ($null -ne $nativeCompiler) {
    $generatedTargets += 'native'
    $generatedTargets += 'native-release'
}
$global:LASTEXITCODE = 0
$generatedRaw = & $verifyScript -Seed 4 -Depth 3 `
    -Targets $generatedTargets -TimeoutSeconds 180 -NoPersist
$generatedExitCode = $LASTEXITCODE
$generated = $generatedRaw | ConvertFrom-Json
$generatedSource = Get-Content -LiteralPath $generated.casePath -Raw -Encoding utf8
foreach ($fragment in @(
    '#valtype',
    'let values : Array[MoonSmithEntry] = []',
    'values.push({ id: i, kind: MoonSmithEntryKind::Ref("x") })',
    'values.push({ id: i + 1, kind: MoonSmithEntryKind::Ref("x") })',
    'match values[0].kind',
    'values[1].id'
)) {
    if (-not $generatedSource.Contains($fragment)) {
        throw "Generated #1322 probe is missing required trigger fragment: $fragment"
    }
}
if (-not $generated.referenceChecked -or
    $generated.referenceTrace.visited -notcontains 'valtype-enum-array-empty-init' -or
    $generated.referenceTrace.visited -notcontains 'valtype-enum-array-push' -or
    $generated.referenceTrace.visited -notcontains 'valtype-enum-array-growth-push' -or
    $generated.referenceTrace.visited -notcontains 'valtype-enum-array-index' -or
    $generated.referenceTrace.visited -notcontains 'valtype-enum-array-index-after-growth') {
    throw 'Generated #1322 extension did not traverse the reference model for empty-init, both pushes, and both indexed reads.'
}

$generatedControls = @($generated.runs | Where-Object target -in @('js', 'wasm', 'wasm-gc', 'native-release'))
if ($generatedControls.Count -ne $generatedTargets.Count - 1 -and $null -ne $nativeCompiler) {
    throw 'Generated #1322 probe did not run every required non-debug control target.'
}
if ($null -eq $nativeCompiler -and $generatedControls.Count -ne 3) {
    throw 'Generated #1322 probe did not run all available non-native targets.'
}
foreach ($control in $generatedControls) {
    if ($control.status -ne 'succeeded' -or
        (Normalize-ProgramOutput $control.output) -ne (Normalize-ProgramOutput $generated.expectedOutput)) {
        throw "Generated #1322 control $($control.target) disagreed with the reference output. Status=$($control.status); output=[$($control.output)]"
    }
}
$generatedNativeDebug = $generated.runs | Where-Object target -eq 'native' | Select-Object -First 1
$generatedNativeDebugClassification = 'unavailable-no-c-compiler'
if ($null -ne $generatedNativeDebug) {
    if ($generatedNativeDebug.status -eq 'compile-failed' -and
        $generatedNativeDebug.error -match 'Machine_error\(kind=unsupported; who="Machine_of_clam_lower\.lower_array_make"; message="uninitialized non-null GC ref arrays are not lowered"') {
        $generatedNativeDebugClassification = 'upstream-issue-signature-reproduced-in-generated-program'
    } elseif ($generatedNativeDebug.status -eq 'succeeded' -and
        (Normalize-ProgramOutput $generatedNativeDebug.output) -eq (Normalize-ProgramOutput $generated.expectedOutput)) {
        $generatedNativeDebugClassification = 'not-reproduced-in-generated-program'
    } else {
        throw "Generated #1322 native debug did not match the known issue signature or reference output. Status=$($generatedNativeDebug.status); error=$($generatedNativeDebug.error)"
    }
}
if ($generatedExitCode -notin @(0, 1) -or
    ($generated.finding -eq 'consistent' -and $generatedExitCode -ne 0) -or
    ($generated.finding -ne 'consistent' -and
        ($generated.finding -ne 'compile-failure' -or
            $generatedNativeDebugClassification -ne 'upstream-issue-signature-reproduced-in-generated-program' -or
            $generatedExitCode -ne 1))) {
    throw "Generated #1322 probe produced an unexpected verifier classification. Finding=$($generated.finding); exit=$generatedExitCode; nativeDebug=$generatedNativeDebugClassification"
}

$result = [pscustomobject]@{
    upstreamIssue = 1322
    sourceIssue = 'https://github.com/moonbitlang/moonbit-docs/issues/1322'
    toolchain = (& moon version | Select-Object -First 1)
    runnerPlatform = if ($IsWindows) { 'windows' } elseif ($IsLinux) { 'linux' } elseif ($IsMacOS) { 'macos' } else { 'unknown' }
    nativeCompiler = if ($nativeCompiler) { $nativeCompiler.Name } else { $null }
    nativeCompilerVersion = $nativeCompilerVersion
    nativeDebugClassification = $nativeDebugClassification
    nativeDebugExitCode = if ($nativeDebug) { $nativeDebug.exitCode } else { $null }
    nativeReleaseClassification = $nativeReleaseClassification
    nativeReleaseExitCode = if ($nativeRelease) { $nativeRelease.exitCode } else { $null }
    wasmGcExitCode = $wasmGc.exitCode
    moonSmithOracleFinding = $oracleReport.finding
    moonSmithOracleExpectedOutputChecked = $oracleReport.referenceChecked
    moonSmithOracleNativeStatus = $oracleNativeRun.status
    moonSmithOracleNativeReleaseStatus = $oracleNativeReleaseRun.status
    moonSmithOracleWasmGcStatus = $oracleWasmGcRun.status
    moonSmithOracleExpectedOutputSource = 'Explicitly recorded by upstream issue #1322; not produced by the MoonSmith reference evaluator.'
    generatedProbeFinding = $generated.finding
    generatedProbeReferenceChecked = $generated.referenceChecked
    generatedProbeExpectedOutput = $generated.expectedOutput
    generatedProbeTargets = @($generated.runs | ForEach-Object target)
    generatedProbeNativeDebugClassification = $generatedNativeDebugClassification
    expectedOutput = @('0', 'x')
    outputSource = 'External upstream reproducer; not discovered by MoonSmith.'
}

$evidenceDirectory = Join-Path $projectRoot '.moonsmith'
New-Item -ItemType Directory -Force -Path $evidenceDirectory | Out-Null
$evidencePath = Join-Path $evidenceDirectory 'issue_1322.json'
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $evidencePath -Encoding utf8
$result
