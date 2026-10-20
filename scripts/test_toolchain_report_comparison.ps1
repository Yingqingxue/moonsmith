$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$compareScript = Join-Path $PSScriptRoot 'compare_toolchain_reports.ps1'
$evidenceDirectory = Join-Path $projectRoot 'docs/evidence/toolchain_diff_20261020'
$baseline = Join-Path $evidenceDirectory 'moon_0.1.20260920_seed21400_depth8.json'
$candidate = Join-Path $evidenceDirectory 'moon_0.1.20261012_seed21400_depth8.json'
$tempDirectory = Join-Path $env:TEMP ("moonsmith-toolchain-compare-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tempDirectory | Out-Null

try {
    $matchedOutput = & pwsh -NoProfile -File $compareScript `
        -BaselineReport $baseline -CandidateReport $candidate -RequireEquivalent
    if ($LASTEXITCODE -ne 0) {
        throw 'The preserved matched toolchain reports were not classified equivalent.'
    }
    $matched = $matchedOutput | ConvertFrom-Json
    if (-not $matched.equivalent -or $matched.matched.count -ne 20 -or
        $matched.bodyHashMismatchSeeds.Count -ne 0 -or
        $matched.outcomeMismatchSeeds.Count -ne 0 -or
        $matched.targetParityMismatchSeeds.Count -ne 0) {
        throw 'The equivalent-report comparison returned unexpected counts.'
    }

    $changed = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
    $changed.cases[0].signature += '|synthetic-comparator-regression-test'
    $changedPath = Join-Path $tempDirectory 'candidate_changed.json'
    $changed | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $changedPath -Encoding utf8
    $changedOutput = & pwsh -NoProfile -File $compareScript `
        -BaselineReport $baseline -CandidateReport $changedPath -RequireEquivalent
    if ($LASTEXITCODE -ne 1) {
        throw "Expected the deliberately changed test fixture to fail equivalence, got exit $LASTEXITCODE."
    }
    $changedResult = $changedOutput | ConvertFrom-Json
    if ($changedResult.equivalent -or
        $changedResult.outcomeMismatchSeeds -notcontains 21400) {
        throw 'The comparator did not identify the deliberately changed seed.'
    }

    $changed = Get-Content -LiteralPath $candidate -Raw | ConvertFrom-Json
    $changed.cases[0].targetParity.status = 'synthetic-test-divergent'
    $parityChangedPath = Join-Path $tempDirectory 'candidate_parity_changed.json'
    $changed | ConvertTo-Json -Depth 30 |
        Set-Content -LiteralPath $parityChangedPath -Encoding utf8
    $parityOutput = & pwsh -NoProfile -File $compareScript `
        -BaselineReport $baseline -CandidateReport $parityChangedPath -RequireEquivalent
    if ($LASTEXITCODE -ne 1) {
        throw "Expected the changed Target Parity fixture to fail equivalence, got exit $LASTEXITCODE."
    }
    $parityResult = $parityOutput | ConvertFrom-Json
    if ($parityResult.equivalent -or
        $parityResult.targetParityMismatchSeeds -notcontains 21400) {
        throw 'The comparator did not identify the deliberately changed Target Parity status.'
    }

    Write-Output 'Toolchain report comparison test passed.'
} finally {
    $resolvedTemp = (Resolve-Path -LiteralPath $tempDirectory).Path
    $expectedParent = (Resolve-Path -LiteralPath $env:TEMP).Path
    $actualParent = [IO.Path]::GetDirectoryName($resolvedTemp)
    if (-not [string]::Equals(
        $actualParent,
        $expectedParent,
        [StringComparison]::OrdinalIgnoreCase
    )) {
        throw "Refusing to remove test data outside TEMP: $resolvedTemp"
    }
    Remove-Item -LiteralPath $resolvedTemp -Recurse -Force
}
