param(
    [Parameter(Mandatory)]
    [object]$Summary,

    [ValidateRange(1, 10000)]
    [int]$ExpectedCount = 1000
)

$ErrorActionPreference = 'Stop'
if ($Summary.count -ne $ExpectedCount -or
    $Summary.uniqueProgramBodies -ne $ExpectedCount -or
    $Summary.referenceCheckedCount -ne $ExpectedCount -or
    $Summary.unexpectedCount -ne 0 -or
    $Summary.harnessChangedDuringRun) {
    throw "Nightly batch must contain $ExpectedCount unique, reference-checked cases with no unexpected findings or harness change."
}

$requiredCoverage = @(
    'casesWithValtypeRaiseProbe',
    'casesWithDirectValtypeRaiseArrayComposition',
    'casesVisitingBothValtypeProbeKinds'
)
foreach ($name in $requiredCoverage) {
    $property = $Summary.PSObject.Properties[$name]
    if ($null -eq $property -or $null -eq $property.Value -or [long]$property.Value -le 0) {
        throw "Nightly corpus did not exercise the required generator coverage metric '$name'."
    }
}

$referencePathProperty = $Summary.PSObject.Properties['referencePathCaseCounts']
if ($null -eq $referencePathProperty -or $null -eq $referencePathProperty.Value) {
    throw 'Nightly corpus did not record reference interpreter path counts.'
}
foreach ($name in @('valtype-raise-success-path', 'valtype-raise-error-path')) {
    $property = $referencePathProperty.Value.PSObject.Properties[$name]
    if ($null -eq $property -or $null -eq $property.Value -or [long]$property.Value -le 0) {
        throw "Nightly reference traces did not visit the required '$name' path."
    }
}

[pscustomobject]@{
    valid = $true
    count = $Summary.count
    valtypeRaiseCases = $Summary.casesWithValtypeRaiseProbe
    directComposedCases = $Summary.casesWithDirectValtypeRaiseArrayComposition
    bothProbeTraceCases = $Summary.casesVisitingBothValtypeProbeKinds
    raiseSuccessPathCases = $Summary.referencePathCaseCounts.'valtype-raise-success-path'
    raiseErrorPathCases = $Summary.referencePathCaseCounts.'valtype-raise-error-path'
}
