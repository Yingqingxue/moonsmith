param(
    [Parameter()]
    [int]$SeedStart = 0,

    [Parameter()]
    [ValidateRange(1, 10000)]
    [int]$Count = 100,

    [Parameter()]
    [ValidateRange(0, 12)]
    [int]$Depth = 4,

    [Parameter()]
    [ValidateSet('js', 'wasm', 'wasm-gc', 'native', 'native-release')]
    [string[]]$Targets = @('js', 'wasm', 'wasm-gc'),

    [Parameter()]
    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 10
)

$ErrorActionPreference = 'Stop'
if (([long]$SeedStart + [long]$Count - 1) -gt [int]::MaxValue) {
    throw 'Seed range exceeds the 32-bit signed Int maximum; reduce -Count or lower -SeedStart.'
}
$projectRoot = Split-Path -Parent $PSScriptRoot
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'
$runDirectory = Join-Path $projectRoot '.moonsmith\runs'
$runId = (Get-Date).ToUniversalTime().ToString('yyyyMMdd_HHmmss_fff')
$summaryPath = Join-Path $runDirectory ("batch_{0}.json" -f $runId)
$startedAt = [System.Diagnostics.Stopwatch]::StartNew()

function Get-HarnessDigest {
    $relativePaths = @(
        'moon.mod', 'moon.pkg',
        'moonsmith.mbt', 'oracle.mbt', 'reducer.mbt', 'reference.mbt',
        'cmd\main\main.mbt', 'cmd\main\moon.pkg',
        'cmd\oracle\main.mbt', 'cmd\oracle\moon.pkg',
        'scripts\verify_seed.ps1', 'scripts\run_batch.ps1'
    )
    $entries = foreach ($relativePath in $relativePaths) {
        $absolutePath = Join-Path $projectRoot $relativePath
        $fileHash = (Get-FileHash -LiteralPath $absolutePath -Algorithm SHA256).Hash
        "${relativePath}:${fileHash}"
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes(($entries -join "`n"))
    [System.Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    ).ToLowerInvariant()
}

$harnessDigestStart = Get-HarnessDigest
$toolchainVersion = (& moon version | Select-Object -First 1)

$counts = [ordered]@{
    consistent        = 0
    'compile-failure' = 0
    'runtime-failure' = 0
    timeout           = 0
    'output-mismatch' = 0
    'reference-mismatch' = 0
    'mixed-failure'   = 0
    'environment-failure' = 0
    'no-results'      = 0
    'generator-limit'  = 0
    'harness-error'   = 0
}
$cases = [System.Collections.Generic.List[object]]::new()
$referencePathCaseCounts = [ordered]@{}

for ($offset = 0; $offset -lt $Count; $offset++) {
    $seed = $SeedStart + $offset
    try {
        $raw = & $verifyScript -Seed $seed -Depth $Depth -Targets $Targets `
            -TimeoutSeconds $TimeoutSeconds
        $caseExitCode = if ($null -eq $LASTEXITCODE) { 0 } else { $LASTEXITCODE }
        $report = $raw | ConvertFrom-Json
        $finding = [string]$report.finding
        if (-not $counts.Contains($finding)) {
            $finding = 'harness-error'
        }
        $counts[$finding]++
        $durationMs = ($report.runs | Measure-Object -Property durationMs -Sum).Sum
        $bodyHash = $null
        $sourceConstructCounts = $null
        $referencePathKinds = @()
        if ($report.referenceTrace -and $report.referenceTrace.visited) {
            $referencePathKinds = @($report.referenceTrace.visited | Select-Object -Unique)
            foreach ($pathKind in $referencePathKinds) {
                if (-not $referencePathCaseCounts.Contains($pathKind)) {
                    $referencePathCaseCounts[$pathKind] = 0
                }
                $referencePathCaseCounts[$pathKind]++
            }
        }
        if ($report.casePath -and (Test-Path -LiteralPath $report.casePath)) {
            $source = Get-Content -LiteralPath $report.casePath -Raw
            $firstNewline = $source.IndexOf("`n")
            $body = if ($firstNewline -ge 0) { $source.Substring($firstNewline + 1) } else { $source }
            $bodyBytes = [System.Text.Encoding]::UTF8.GetBytes($body)
            $bodyHash = [System.Convert]::ToHexString(
                [System.Security.Cryptography.SHA256]::HashData($bodyBytes)
            ).ToLowerInvariant()
            $sourceConstructCounts = [pscustomobject]@{
                let   = [regex]::Matches($body, '\blet\s+v\d+\s*=').Count
                match = [regex]::Matches($body, '\bmatch\s').Count
                if    = [regex]::Matches($body, '\bif\s').Count
                subtract = [regex]::Matches($body, '\s-\s').Count
                and = [regex]::Matches($body, '\s&&\s').Count
                array = [regex]::Matches($body, '\blet items = \[').Count
                arrayIndex0 = [regex]::Matches($body, '\bitems\[0\]').Count
                arrayIndex1 = [regex]::Matches($body, '\bitems\[1\]').Count
                function = [regex]::Matches($body, '\blet transform = fn\(').Count
                functionInt = [regex]::Matches($body, '\blet transform = fn\(p\d+ : Int\)').Count
                functionBool = [regex]::Matches($body, '\blet transform = fn\(p\d+ : Bool\)').Count
                struct = [regex]::Matches($body, '\blet pair = Pair::\{').Count
                structNumber = [regex]::Matches($body, '\bpair\.number\b').Count
                structFlag = [regex]::Matches($body, '\bpair\.flag\b').Count
                choiceMatch = [regex]::Matches($body, '\bmatch selected_choice \{').Count
                choiceNumber = [regex]::Matches($body, 'Choice::Number\(').Count
                choiceFlag = [regex]::Matches($body, 'Choice::Flag\(').Count
                forLoop = [regex]::Matches($body, '\bfor _ms_index = 0, _ms_acc =').Count
                forNobreak = [regex]::Matches($body, '\bnobreak\s*\{').Count
                valtypeRaiseProbe = [regex]::Matches($body, '_ms_valtype_run\(').Count
            }
        }
        $cases.Add([pscustomobject]@{
            seed       = $seed
            finding    = $finding
            referenceChecked = [bool]$report.referenceChecked
            expectedOutput = $report.expectedOutput
            signature  = $report.signature
            caseId     = $report.caseId
            exitCode   = $caseExitCode
            durationMs = $durationMs
            bodySha256 = $bodyHash
            sourceConstructCounts = $sourceConstructCounts
            referencePathKinds = $referencePathKinds
            referencePath = $report.referenceTrace
            error = $report.error
            sourceLineCount = $report.sourceLineCount
            sourceLineLimit = $report.sourceLineLimit
        })
    }
    catch {
        $errorMessage = $_.Exception.Message
        $finding = if ($errorMessage -like 'MoonSmith generator-limit:*') {
            'generator-limit'
        } else {
            'harness-error'
        }
        $counts[$finding]++
        $cases.Add([pscustomobject]@{
            seed       = $seed
            finding    = $finding
            referenceChecked = $false
            expectedOutput = $null
            signature  = $null
            caseId     = $null
            exitCode   = -1
            durationMs = 0
            error      = $errorMessage
        })
    }
}

$startedAt.Stop()
$harnessDigestEnd = Get-HarnessDigest
$harnessChangedDuringRun = $harnessDigestStart -ne $harnessDigestEnd
$unexpectedCount = $Count - $counts.consistent
$referenceCheckedCount = @($cases | Where-Object referenceChecked).Count
$casesWithSourceLineCount = @($cases | Where-Object { $null -ne $_.sourceLineCount }).Count
$sourceLineCountMaximum = if ($casesWithSourceLineCount -gt 0) {
    ($cases | Where-Object { $null -ne $_.sourceLineCount } |
        Measure-Object -Property sourceLineCount -Maximum).Maximum
} else {
    $null
}
$uniqueFailureSignatures = @(
    $cases |
        Where-Object { $_.finding -ne 'consistent' -and $null -ne $_.signature } |
        Select-Object -ExpandProperty signature -Unique
).Count
$uniqueProgramBodies = @(
    $cases | Where-Object { $null -ne $_.bodySha256 } |
        Select-Object -ExpandProperty bodySha256 -Unique
).Count
$casesWithLet = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.let -gt 0 }).Count
$casesWithMatch = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.match -gt 0 }).Count
$casesWithIf = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.if -gt 0 }).Count
$casesWithSubtract = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.subtract -gt 0 }).Count
$casesWithAnd = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.and -gt 0 }).Count
$casesWithArray = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.array -gt 0 }).Count
$casesWithArrayIndex0 = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.arrayIndex0 -gt 0 }).Count
$casesWithArrayIndex1 = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.arrayIndex1 -gt 0 }).Count
$casesWithFunction = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.function -gt 0 }).Count
$casesWithIntFunction = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.functionInt -gt 0 }).Count
$casesWithBoolFunction = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.functionBool -gt 0 }).Count
$casesWithStruct = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.struct -gt 0 }).Count
$casesWithNumberField = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.structNumber -gt 0 }).Count
$casesWithFlagField = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.structFlag -gt 0 }).Count
$casesWithChoiceMatch = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.choiceMatch -gt 0 }).Count
$casesWithNumberConstructor = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.choiceNumber -gt 0 }).Count
$casesWithFlagConstructor = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.choiceFlag -gt 0 }).Count
$casesWithForLoop = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.forLoop -gt 0 }).Count
$casesWithForIteration = @($cases | Where-Object { $_.referencePathKinds -contains 'for-iteration' }).Count
$casesWithValtypeRaiseProbe = @($cases | Where-Object { $_.sourceConstructCounts -and $_.sourceConstructCounts.valtypeRaiseProbe -gt 0 }).Count

$summary = [pscustomobject]@{
    schemaVersion           = 6
    runId                   = $runId
    seedStart               = $SeedStart
    count                   = $Count
    depth                   = $Depth
    targets                 = $Targets
    timeoutSeconds          = $TimeoutSeconds
    durationMs              = $startedAt.ElapsedMilliseconds
    toolchainVersion         = $toolchainVersion
    harnessDigestStart       = $harnessDigestStart
    harnessDigestEnd         = $harnessDigestEnd
    harnessChangedDuringRun  = $harnessChangedDuringRun
    unexpectedCount         = $unexpectedCount
    referenceCheckedCount   = $referenceCheckedCount
    casesWithSourceLineCount = $casesWithSourceLineCount
    sourceLineCountMaximum  = $sourceLineCountMaximum
    uniqueFailureSignatures = $uniqueFailureSignatures
    uniqueProgramBodies     = $uniqueProgramBodies
    casesWithLet            = $casesWithLet
    casesWithMatch          = $casesWithMatch
    casesWithIf             = $casesWithIf
    casesWithSubtract       = $casesWithSubtract
    casesWithAnd            = $casesWithAnd
    casesWithArray          = $casesWithArray
    casesWithArrayIndex0    = $casesWithArrayIndex0
    casesWithArrayIndex1    = $casesWithArrayIndex1
    casesWithFunction       = $casesWithFunction
    casesWithIntFunction    = $casesWithIntFunction
    casesWithBoolFunction   = $casesWithBoolFunction
    casesWithStruct         = $casesWithStruct
    casesWithNumberField    = $casesWithNumberField
    casesWithFlagField      = $casesWithFlagField
    casesWithChoiceMatch    = $casesWithChoiceMatch
    casesWithNumberConstructor = $casesWithNumberConstructor
    casesWithFlagConstructor = $casesWithFlagConstructor
    casesWithForLoop        = $casesWithForLoop
    casesWithForIteration   = $casesWithForIteration
    casesWithValtypeRaiseProbe = $casesWithValtypeRaiseProbe
    referenceTraceSource    = 'MoonBit reference interpreter; not backend runtime instrumentation'
    referencePathCaseCounts = $referencePathCaseCounts
    counts                  = $counts
    cases                   = @($cases)
}

New-Item -ItemType Directory -Force -Path $runDirectory | Out-Null
$summaryJson = $summary | ConvertTo-Json -Depth 7
Set-Content -LiteralPath $summaryPath -Value $summaryJson -Encoding utf8
$summaryJson

if ($harnessChangedDuringRun) {
    exit 2
}
if ($unexpectedCount -ne 0) {
    exit 1
}
