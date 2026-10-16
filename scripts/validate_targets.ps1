function Assert-UniqueTargets {
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Targets
    )

    if ($Targets.Count -eq 0) {
        throw 'Targets must contain at least one backend.'
    }

    $uniqueTargets = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    foreach ($target in $Targets) {
        if (-not $uniqueTargets.Add($target)) {
            throw "Targets must not contain duplicates: '$target'."
        }
    }
}
