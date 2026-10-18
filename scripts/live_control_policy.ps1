function Get-LiveControlSizeBand {
    param([int]$SourceLineCount)
    if ($SourceLineCount -lt 50) { return 'lt50' }
    if ($SourceLineCount -lt 100) { return '50to99' }
    if ($SourceLineCount -lt 200) { return '100to199' }
    if ($SourceLineCount -lt 500) { return '200to499' }
    return '500plus'
}

function Select-LiveControlCandidate {
    param(
        [Parameter(Mandatory)][object[]]$Candidates,
        [Parameter(Mandatory)][ValidateSet('sequential', 'semantic-guided')][string]$Policy,
        [Parameter(Mandatory)][AllowEmptyCollection()][System.Collections.Generic.HashSet[string]]$SeenPathKinds
    )
    $valid = @($Candidates | Where-Object { $_.preflightStatus -eq 'checked' } |
        Sort-Object proposalOrdinal)
    if ($valid.Count -eq 0) { throw 'Proposal window has no candidate with a completed reference preflight.' }
    $anchor = $valid[0]
    if ($Policy -eq 'sequential') {
        return [pscustomobject]@{ candidate = $anchor; noveltyScore = $null; selectionRule = 'first valid seed in ascending proposal window' }
    }

    $eligible = @($valid | Where-Object { $_.sourceSizeBand -eq $anchor.sourceSizeBand })
    $ranked = foreach ($candidate in $eligible) {
        $novel = @($candidate.referencePathKinds | Where-Object { -not $SeenPathKinds.Contains([string]$_) } | Sort-Object -Unique)
        [pscustomobject]@{
            candidate = $candidate
            novelPathKinds = $novel.Count
            novelPathRatePerSourceLine = [double]$novel.Count / [Math]::Max(1, [int]$candidate.sourceLineCount)
        }
    }
    $selected = $ranked | Sort-Object `
        @{ Expression = 'novelPathRatePerSourceLine'; Descending = $true },
        @{ Expression = 'novelPathKinds'; Descending = $true },
        @{ Expression = { $_.candidate.seed }; Descending = $false } |
        Select-Object -First 1
    return [pscustomobject]@{
        candidate = $selected.candidate
        noveltyScore = $selected.novelPathRatePerSourceLine
        novelPathKindCount = $selected.novelPathKinds
        selectionRule = 'highest unseen reference-path kinds per source line within the first valid proposal size band; ties by count then ascending seed'
    }
}
