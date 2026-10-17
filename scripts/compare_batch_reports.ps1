param(
    [Parameter(Mandatory = $true)]
    [string]$LinuxReportDirectory,

    [Parameter(Mandatory = $true)]
    [string]$WindowsReportDirectory,

    [Parameter()]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Read-BatchReportSet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Directory,

        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedTargets,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (-not (Test-Path -LiteralPath $Directory -PathType Container)) {
        throw "$Label report directory does not exist: $Directory"
    }

    $files = @(Get-ChildItem -LiteralPath $Directory -Filter 'batch_*.json' -File)
    if ($files.Count -eq 0) {
        throw "$Label report directory contains no batch_*.json files."
    }

    $casesBySeed = @{}
    $toolchains = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::Ordinal
    )
    $expectedTargetList = @($ExpectedTargets | Sort-Object)

    foreach ($file in $files) {
        $report = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        if ($report.schemaVersion -notin @(7, 8, 9, 10, 11)) {
            throw "$Label report '$($file.Name)' has unsupported schemaVersion '$($report.schemaVersion)'."
        }
        if ($report.count -lt 1 -or $report.seedStart -lt 0) {
            throw "$Label report '$($file.Name)' has an invalid seed range."
        }

        $actualTargets = @($report.targets | Sort-Object)
        if (($actualTargets -join ',') -ne ($expectedTargetList -join ',')) {
            throw "$Label report '$($file.Name)' targets '$($actualTargets -join ',')'; expected '$($expectedTargetList -join ',')'."
        }
        if ($report.harnessDigestStart -ne $report.harnessDigestEnd) {
            throw "$Label harness changed while report '$($file.Name)' was generated."
        }
        $unexpectedFindingCount = $report.count - $report.counts.consistent -
            $report.counts.'generator-limit'
        if ($report.counts.consistent -gt $report.count -or
            $report.counts.'generator-limit' -gt $report.count -
                $report.counts.consistent -or
            $report.unexpectedCount -ne ($report.count - $report.counts.consistent) -or
            $unexpectedFindingCount -ne 0 -or
            $report.counts.'harness-error' -ne 0) {
            throw "$Label report '$($file.Name)' contains inconsistent, unexpected, or harness-error cases."
        }
        if ($null -ne $report.PSObject.Properties['unexpectedFindingCount'] -and
            $report.unexpectedFindingCount -ne $unexpectedFindingCount) {
            throw "$Label report '$($file.Name)' has an incorrect unexpectedFindingCount."
        }
        if ($report.cases.Count -ne $report.count) {
            throw "$Label report '$($file.Name)' has $($report.cases.Count) cases but declares $($report.count)."
        }
        if ([string]::IsNullOrWhiteSpace([string]$report.toolchainVersion)) {
            throw "$Label report '$($file.Name)' is missing toolchainVersion."
        }
        [void]$toolchains.Add([string]$report.toolchainVersion)

        $caseConsistentCount = 0
        $caseGeneratorLimitCount = 0
        for ($index = 0; $index -lt $report.cases.Count; $index++) {
            $case = $report.cases[$index]
            $seed = [int]$case.seed
            $expectedSeed = [int]$report.seedStart + $index
            if ($seed -ne $expectedSeed) {
                throw "$Label report '$($file.Name)' has seed $seed at offset $index; expected $expectedSeed."
            }
            $key = [string]$seed
            if ($casesBySeed.ContainsKey($key)) {
                throw "$Label reports contain duplicate seed $seed."
            }
            if ($case.finding -eq 'generator-limit') {
                $caseGeneratorLimitCount++
                $limitErrorPattern = '^Generated source exceeds the safe ' +
                    [regex]::Escape([string]$case.sourceLineLimit) + '-line limit;'
                if ($case.referenceChecked -or $null -ne $case.targetParity -or
                    $null -eq $case.sourceLineCount -or
                    $null -eq $case.sourceLineLimit -or
                    $case.sourceLineLimit -le 0 -or
                    $case.sourceLineCount -le $case.sourceLineLimit -or
                    [string]$case.error -notmatch $limitErrorPattern) {
                    throw "$Label seed $seed has an invalid generator-limit exclusion."
                }
            } elseif ($case.finding -ne 'consistent' -or -not $case.referenceChecked) {
                throw "$Label seed $seed was neither reference-checked as consistent nor safely excluded by the generator-size limit."
            } else {
                $caseConsistentCount++
                if ($null -ne $case.sourceLineCount -and
                    $null -ne $case.sourceLineLimit -and
                    $case.sourceLineCount -gt $case.sourceLineLimit) {
                    throw "$Label seed $seed was marked consistent despite exceeding its generator-size limit."
                }
                if ($report.schemaVersion -ge 11 -and $report.targets.Count -gt 1 -and
                    $case.targetParity.status -ne 'pass') {
                    throw "$Label seed $seed does not have a passing Target Parity result."
                }
            }
            if ([string]$case.bodySha256 -notmatch '^[0-9a-f]{64}$') {
                throw "$Label seed $seed has an invalid bodySha256."
            }

            $casesBySeed[$key] = [pscustomobject]@{
                seed = $seed
                bodySha256 = [string]$case.bodySha256
                finding = [string]$case.finding
                expectedOutput = [string]$case.expectedOutput
                targetParityStatus = [string]$case.targetParity.status
                sourceLineCount = $case.sourceLineCount
                sourceLineLimit = $case.sourceLineLimit
            }
        }
        if ($caseConsistentCount -ne $report.counts.consistent -or
            $caseGeneratorLimitCount -ne $report.counts.'generator-limit') {
            throw "$Label report '$($file.Name)' finding totals do not match its per-case records."
        }
    }

    [pscustomobject]@{
        Files = $files
        CasesBySeed = $casesBySeed
        Toolchains = @($toolchains | Sort-Object)
        Targets = $expectedTargetList
    }
}

$linux = Read-BatchReportSet -Directory $LinuxReportDirectory `
    -ExpectedTargets @('js', 'wasm', 'wasm-gc') -Label 'Linux'
$windows = Read-BatchReportSet -Directory $WindowsReportDirectory `
    -ExpectedTargets @('native-release') -Label 'Windows'

if ($linux.Toolchains.Count -ne 1 -or $windows.Toolchains.Count -ne 1 -or
    $linux.Toolchains[0] -ne $windows.Toolchains[0]) {
    throw "Linux and Windows must use the same single MoonBit toolchain version. Linux='$($linux.Toolchains -join ',')'; Windows='$($windows.Toolchains -join ',')'."
}

$linuxSeeds = @($linux.CasesBySeed.Keys | Sort-Object { [int]$_ })
$windowsSeeds = @($windows.CasesBySeed.Keys | Sort-Object { [int]$_ })
if (($linuxSeeds -join ',') -ne ($windowsSeeds -join ',')) {
    throw 'Linux and Windows reports do not cover exactly the same seed set.'
}

$hashMismatches = [System.Collections.Generic.List[int]]::new()
$outputMismatches = [System.Collections.Generic.List[int]]::new()
$findingMismatches = [System.Collections.Generic.List[int]]::new()
$limitMismatches = [System.Collections.Generic.List[int]]::new()
foreach ($seedKey in $linuxSeeds) {
    if ($linux.CasesBySeed[$seedKey].finding -ne $windows.CasesBySeed[$seedKey].finding) {
        $findingMismatches.Add([int]$seedKey)
        continue
    }
    if ($linux.CasesBySeed[$seedKey].bodySha256 -ne
        $windows.CasesBySeed[$seedKey].bodySha256) {
        $hashMismatches.Add([int]$seedKey)
    }
    if ($linux.CasesBySeed[$seedKey].finding -eq 'generator-limit') {
        if ($linux.CasesBySeed[$seedKey].sourceLineCount -ne
                $windows.CasesBySeed[$seedKey].sourceLineCount -or
            $linux.CasesBySeed[$seedKey].sourceLineLimit -ne
                $windows.CasesBySeed[$seedKey].sourceLineLimit) {
            $limitMismatches.Add([int]$seedKey)
        }
    } elseif ($linux.CasesBySeed[$seedKey].expectedOutput -cne
        $windows.CasesBySeed[$seedKey].expectedOutput) {
        $outputMismatches.Add([int]$seedKey)
    }
    if ($linux.Targets.Count -gt 1 -and $windows.Targets.Count -gt 1 -and
        $linux.CasesBySeed[$seedKey].targetParityStatus -cne
        $windows.CasesBySeed[$seedKey].targetParityStatus) {
        throw "Target Parity statuses differ between platforms for seed $seedKey."
    }
}
if ($findingMismatches.Count -gt 0) {
    throw "Generation eligibility differs between platforms for seeds: $($findingMismatches -join ', ')."
}
if ($hashMismatches.Count -gt 0) {
    throw "Generated source hashes differ for seeds: $($hashMismatches -join ', ')."
}
if ($limitMismatches.Count -gt 0) {
    throw "Generator size-limit results differ between platforms for seeds: $($limitMismatches -join ', ')."
}
if ($outputMismatches.Count -gt 0) {
    throw "Reference expected outputs differ for seeds: $($outputMismatches -join ', ')."
}

$distinctBodies = @(
    $linux.CasesBySeed.Values |
        ForEach-Object { $_.bodySha256 } |
        Sort-Object -Unique
).Count
$consistentSeeds = @($linuxSeeds | Where-Object {
    $linux.CasesBySeed[$_].finding -eq 'consistent'
})
$generatorLimitedSeeds = $linuxSeeds.Count - $consistentSeeds.Count
$summary = [ordered]@{
    schemaVersion = 1
    seedStart = [int]$linuxSeeds[0]
    seedEnd = [int]$linuxSeeds[-1]
    seedsCompared = $linuxSeeds.Count
    executableSeedsCompared = $consistentSeeds.Count
    generatorLimitedSeeds = $generatorLimitedSeeds
    unexpectedFindings = 0
    distinctProgramBodies = $distinctBodies
    matchingSourceHashes = $linuxSeeds.Count
    matchingExpectedOutputs = $consistentSeeds.Count
    linuxTargets = $linux.Targets
    linuxExecutions = $consistentSeeds.Count * $linux.Targets.Count
    windowsTargets = $windows.Targets
    windowsExecutions = $consistentSeeds.Count * $windows.Targets.Count
    consistentOnBothPlatforms = $consistentSeeds.Count
    toolchainVersion = $linux.Toolchains[0]
    linuxReportFiles = @($linux.Files | ForEach-Object { $_.Name })
    windowsReportFiles = @($windows.Files | ForEach-Object { $_.Name })
}

$summaryJson = $summary | ConvertTo-Json -Depth 6
if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    $absoluteOutputPath = [IO.Path]::GetFullPath($OutputPath)
    $outputDirectory = Split-Path -Parent $absoluteOutputPath
    if (-not [string]::IsNullOrWhiteSpace($outputDirectory)) {
        New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
    }
    [IO.File]::WriteAllText(
        $absoluteOutputPath,
        $summaryJson,
        [System.Text.UTF8Encoding]::new($false)
    )
}

Write-Output $summaryJson
