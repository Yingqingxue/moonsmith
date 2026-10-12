function Get-MoonSmithFailureClusters {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Cases
    )

    $groups = @(
        $Cases |
            Where-Object {
                $_.finding -ne 'consistent' -and
                $null -ne $_.signature -and
                [string]$_.signature -ne ''
            } |
            Group-Object -Property { "$($_.finding)`0$($_.signature)" }
    )
    $clusters = foreach ($group in $groups) {
        $members = @($group.Group | Sort-Object -Property seed)
        $identified = @($members | Where-Object { $null -ne $_.caseId -and [string]$_.caseId -ne '' })
        [pscustomobject]@{
            finding = [string]$members[0].finding
            signature = [string]$members[0].signature
            count = $members.Count
            firstSeed = $members[0].seed
            seeds = @($members | Select-Object -ExpandProperty seed)
            caseIds = @($identified | Select-Object -ExpandProperty caseId)
            representativeCaseId = if ($identified.Count -gt 0) { [string]$identified[0].caseId } else { $null }
        }
    }
    return @($clusters | Sort-Object -Property firstSeed, finding, signature)
}
