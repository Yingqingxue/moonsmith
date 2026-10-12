$ErrorActionPreference = 'Stop'
$scriptPath = Join-Path $PSScriptRoot 'compare_batch_reports.ps1'
$testRoot = Join-Path $env:TEMP ('moonsmith-batch-report-test-' + [guid]::NewGuid().ToString('N'))
$linuxDirectory = Join-Path $testRoot 'linux'
$windowsDirectory = Join-Path $testRoot 'windows'
New-Item -ItemType Directory -Path $linuxDirectory, $windowsDirectory -Force | Out-Null

function New-TestReport {
    param(
        [int]$SeedStart,
        [string[]]$Targets,
        [string]$Finding = 'consistent',
        [string]$FirstHash = ('a' * 64),
        [string]$FirstExpectedOutput = "42`n",
        [string]$ToolchainVersion = 'moon 0.1.test (fixture)'
    )

    $cases = @(
        [ordered]@{
            seed = $SeedStart
            bodySha256 = $FirstHash
            finding = $Finding
            expectedOutput = $FirstExpectedOutput
            referenceChecked = $true
        },
        [ordered]@{
            seed = $SeedStart + 1
            bodySha256 = ('b' * 64)
            finding = 'consistent'
            expectedOutput = "43`n"
            referenceChecked = $true
        }
    )
    [ordered]@{
        schemaVersion = 7
        seedStart = $SeedStart
        count = 2
        depth = 4
        targets = $Targets
        toolchainVersion = $ToolchainVersion
        harnessDigestStart = ('c' * 64)
        harnessDigestEnd = ('c' * 64)
        counts = [ordered]@{
            consistent = 2
            'generator-limit' = 0
            'harness-error' = 0
        }
        unexpectedCount = 0
        cases = $cases
    }
}

function Assert-ComparisonRejected {
    param(
        [string]$ExpectedMessage,
        [string]$Label
    )

    try {
        $null = & $scriptPath -LinuxReportDirectory $linuxDirectory `
            -WindowsReportDirectory $windowsDirectory
    }
    catch {
        if ($_.Exception.Message -match $ExpectedMessage) {
            return
        }
        throw "$Label failed for the wrong reason: $($_.Exception.Message)"
    }
    throw "$Label was not rejected."
}

try {
    $linuxReport = New-TestReport -SeedStart 41000 -Targets @('js', 'wasm', 'wasm-gc')
    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release')
    $linuxReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $linuxDirectory 'batch_linux.json') -Encoding utf8
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8

    $outputPath = Join-Path $testRoot 'summary.json'
    $output = & $scriptPath -LinuxReportDirectory $linuxDirectory `
        -WindowsReportDirectory $windowsDirectory -OutputPath $outputPath
    $summary = $output | ConvertFrom-Json
    if ($summary.seedsCompared -ne 2 -or
        $summary.matchingSourceHashes -ne 2 -or
        $summary.matchingExpectedOutputs -ne 2 -or
        $summary.distinctProgramBodies -ne 2 -or
        $summary.linuxExecutions -ne 6 -or
        $summary.windowsExecutions -ne 2 -or
        $summary.consistentOnBothPlatforms -ne 2 -or
        -not (Test-Path -LiteralPath $outputPath -PathType Leaf)) {
        throw 'valid paired reports produced an incorrect comparison summary.'
    }

    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release') -FirstHash ('d' * 64)
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'source hashes differ' -Label 'source-hash mismatch'

    $windowsReport = New-TestReport -SeedStart 41001 -Targets @('native-release')
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'same seed set' -Label 'seed-set mismatch'

    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release') `
        -ToolchainVersion 'moon 0.2.test (different fixture)'
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'same single MoonBit toolchain version' -Label 'toolchain mismatch'

    $windowsReport = New-TestReport -SeedStart 41000 -Targets @('native-release') `
        -FirstExpectedOutput "wrong`n"
    $windowsReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $windowsDirectory 'batch_windows.json') -Encoding utf8
    Assert-ComparisonRejected -ExpectedMessage 'Reference expected outputs differ' -Label 'reference-output mismatch'

    $resolvedTemp = [IO.Path]::GetFullPath($testRoot)
    $resolvedTempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if (-not $resolvedTemp.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove test output outside the temporary directory: $resolvedTemp"
    }
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
    [pscustomobject]@{
        passed = $true
        comparedSeeds = $summary.seedsCompared
        rejectedHashMismatch = $true
        rejectedSeedMismatch = $true
        rejectedToolchainMismatch = $true
        rejectedExpectedOutputMismatch = $true
    } | ConvertTo-Json
}
catch {
    if (Test-Path -LiteralPath $testRoot) {
        $resolvedTemp = [IO.Path]::GetFullPath($testRoot)
        $resolvedTempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
        if ($resolvedTemp.StartsWith($resolvedTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
            Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
        }
    }
    throw
}
