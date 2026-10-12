param(
    [Parameter(Mandatory)]
    [string]$BaselineVersion,

    [Parameter(Mandatory)]
    [string]$CandidateVersion,

    [Parameter(Mandatory)]
    [string]$ArtifactDirectory
)

$ErrorActionPreference = 'Stop'
$versions = @(
    @{ label = 'baseline'; value = $BaselineVersion },
    @{ label = 'candidate'; value = $CandidateVersion }
)
foreach ($entry in $versions) {
    if ($entry.value -notmatch '^\d+\.\d+\.\d+$') {
        throw "Expected a dated MoonBit release like 0.1.20260920; got '$($entry.value)'"
    }
}
if ($BaselineVersion -eq $CandidateVersion) {
    throw 'BaselineVersion and CandidateVersion must differ for a comparison.'
}

New-Item -ItemType Directory -Force -Path $ArtifactDirectory | Out-Null
$reports = @{}
foreach ($entry in $versions) {
    $moonHome = Join-Path $env:RUNNER_TEMP "moonbit-$($entry.label)"
    $env:MOON_HOME = $moonHome
    $env:MOONBIT_INSTALL_VERSION = $entry.value
    if ($IsWindows) {
        irm https://cli.moonbitlang.com/install/powershell.ps1 | iex
        $moonBin = Join-Path $moonHome 'bin'
        $env:PATH = "$moonBin;$env:PATH"
    } else {
        & bash -c 'curl -fsSL https://cli.moonbitlang.com/install/unix.sh | bash'
        if ($LASTEXITCODE -ne 0) {
            throw "Official MoonBit installer failed for $($entry.value)"
        }
        $moonBin = Join-Path $moonHome 'bin'
        $env:PATH = "$moonBin$([IO.Path]::PathSeparator)$env:PATH"
    }

    $moon = Get-Command moon -ErrorAction Stop
    Write-Output "Testing $($entry.label): $($entry.value) using $($moon.Source)"
    $toolchainDetails = moon version --all 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw 'moon version --all failed' }
    if ($toolchainDetails -notmatch "(?m)^moon $([regex]::Escape($entry.value))(\s|$)") {
        throw "Requested MoonBit $($entry.value), but installed toolchain reported: $toolchainDetails"
    }
    Write-Output $toolchainDetails

    moon clean
    if ($LASTEXITCODE -ne 0) { throw "moon clean failed under $($entry.value)" }
    pwsh -NoProfile -File scripts/test_issue_1322.ps1
    if ($LASTEXITCODE -ne 0) {
        throw "Issue 1322 regression failed under $($entry.value)"
    }
    $sourceReport = Join-Path $PWD '.moonsmith/issue_1322.json'
    $savedReport = Join-Path $ArtifactDirectory "issue_1322_$($entry.label).json"
    Copy-Item -LiteralPath $sourceReport -Destination $savedReport
    $reports[$entry.label] = Get-Content -LiteralPath $savedReport -Raw | ConvertFrom-Json
}

$comparison = [pscustomobject]@{
    platform = if ($IsWindows) { 'windows' } else { 'linux' }
    baseline = [pscustomobject]@{
        toolchain = $reports.baseline.toolchain
        nativeCompiler = $reports.baseline.nativeCompiler
        nativeCompilerVersion = $reports.baseline.nativeCompilerVersion
        nativeDebugClassification = $reports.baseline.nativeDebugClassification
        nativeReleaseClassification = $reports.baseline.nativeReleaseClassification
        wasmGcExitCode = $reports.baseline.wasmGcExitCode
    }
    candidate = [pscustomobject]@{
        toolchain = $reports.candidate.toolchain
        nativeCompiler = $reports.candidate.nativeCompiler
        nativeCompilerVersion = $reports.candidate.nativeCompilerVersion
        nativeDebugClassification = $reports.candidate.nativeDebugClassification
        nativeReleaseClassification = $reports.candidate.nativeReleaseClassification
        wasmGcExitCode = $reports.candidate.wasmGcExitCode
    }
    nativeCompilerVersionsMatch = (
        $reports.baseline.nativeCompilerVersion -eq $reports.candidate.nativeCompilerVersion
    )
    note = 'Same hosted runner per platform; this comparison does not pin runner images or isolate every dependency.'
}
$comparison | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $ArtifactDirectory 'comparison.json') -Encoding utf8
$comparison | ConvertTo-Json -Depth 6
