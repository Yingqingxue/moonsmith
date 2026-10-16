[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$OriginalPath,

    [Parameter(Mandatory)]
    [string]$ReducedPath
)

$ErrorActionPreference = 'Stop'

function Get-LayoutIndependentLines {
    param([Parameter(Mandatory)][string]$Path)

    # This is intentionally a textual classifier, not a MoonBit parser. It
    # ignores only blank lines and MoonBit block separators; comments and all
    # other source lines remain significant.
    @(
        Get-Content -LiteralPath $Path | Where-Object {
            $_.Trim().Length -gt 0 -and $_.Trim() -ne '///|'
        }
    )
}

if (-not (Test-Path -LiteralPath $OriginalPath -PathType Leaf)) {
    throw "Original source does not exist: $OriginalPath"
}
if (-not (Test-Path -LiteralPath $ReducedPath -PathType Leaf)) {
    throw "Reduced source does not exist: $ReducedPath"
}

$originalRaw = [System.IO.File]::ReadAllText($OriginalPath)
$reducedRaw = [System.IO.File]::ReadAllText($ReducedPath)
if ($originalRaw -ceq $reducedRaw) {
    'unchanged'
    exit 0
}

$originalLines = @(Get-LayoutIndependentLines -Path $OriginalPath)
$reducedLines = @(Get-LayoutIndependentLines -Path $ReducedPath)
if ($originalLines.Count -eq $reducedLines.Count) {
    $sameLines = $true
    for ($index = 0; $index -lt $originalLines.Count; $index++) {
        if (-not [string]::Equals(
                [string]$originalLines[$index],
                [string]$reducedLines[$index],
                [System.StringComparison]::Ordinal
            )) {
            $sameLines = $false
            break
        }
    }
    if ($sameLines) {
        'layout-only'
        exit 0
    }
}

'content-lines-changed'
