param(
    [Parameter(Mandatory)]
    [object]$Summary,

    [ValidateRange(1, 10000)]
    [int]$ExpectedCount = 1000
)

$ErrorActionPreference = 'Stop'
if ($Summary.schemaVersion -ne 9) {
    throw "Nightly corpus validator requires batch schema 9; received '$($Summary.schemaVersion)'."
}
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
    'casesVisitingBothValtypeProbeKinds',
    'casesWithChoiceReturningFunction'
    'casesWithOr'
)
foreach ($name in $requiredCoverage) {
    $property = $Summary.PSObject.Properties[$name]
    if ($null -eq $property -or $null -eq $property.Value -or [long]$property.Value -le 0) {
        throw "Nightly corpus did not exercise the required generator coverage metric '$name'."
    }
}
$choiceFunctionCount = $Summary.PSObject.Properties['choiceReturningFunctionCount']
if ($null -eq $choiceFunctionCount -or
    $null -eq $choiceFunctionCount.Value -or
    [long]$choiceFunctionCount.Value -le 0) {
    throw 'Nightly corpus did not count any Choice-returning local functions.'
}
if ($null -eq $Summary.cases -or $Summary.cases.Count -ne $ExpectedCount) {
    throw "Nightly corpus must contain $ExpectedCount per-case records to verify Choice-function coverage totals."
}
$observedChoiceFunctionCases = 0
$observedChoiceFunctionCount = 0
$observedOrCases = 0
$observedOrRhsExecutedCases = 0
$observedOrRhsSkippedCases = 0
foreach ($case in $Summary.cases) {
    $constructCounts = $case.PSObject.Properties['sourceConstructCounts']
    $functionCount = if ($null -ne $constructCounts -and $null -ne $constructCounts.Value) {
        $constructCounts.Value.PSObject.Properties['functionChoice']
    } else {
        $null
    }
    if ($null -eq $functionCount -or
        $null -eq $functionCount.Value -or
        [long]$functionCount.Value -lt 0) {
        throw "Nightly case '$($case.seed)' is missing a valid sourceConstructCounts.functionChoice value."
    }
    if ([long]$functionCount.Value -gt 0) {
        $observedChoiceFunctionCases++
        $observedChoiceFunctionCount += [long]$functionCount.Value
    }
    $orCount = if ($null -ne $constructCounts -and $null -ne $constructCounts.Value) {
        $constructCounts.Value.PSObject.Properties['or']
    } else {
        $null
    }
    if ($null -eq $orCount -or $null -eq $orCount.Value -or [long]$orCount.Value -lt 0) {
        throw "Nightly case '$($case.seed)' is missing a valid sourceConstructCounts.or value."
    }
    if ([long]$orCount.Value -gt 0) { $observedOrCases++ }

    $pathKinds = $case.PSObject.Properties['referencePathKinds']
    if ($null -eq $pathKinds -or $null -eq $pathKinds.Value) {
        throw "Nightly case '$($case.seed)' is missing referencePathKinds."
    }
    $casePathKinds = @($pathKinds.Value)
    if ($casePathKinds -contains 'or-rhs-executed') { $observedOrRhsExecutedCases++ }
    if ($casePathKinds -contains 'or-rhs-skipped') { $observedOrRhsSkippedCases++ }
}
if ($observedChoiceFunctionCases -ne [long]$Summary.casesWithChoiceReturningFunction) {
    throw 'Nightly Choice-returning function case total does not match per-case source metrics.'
}
if ($observedChoiceFunctionCount -ne [long]$choiceFunctionCount.Value) {
    throw 'Nightly Choice-returning function count does not match per-case source metrics.'
}
if ($observedOrCases -ne [long]$Summary.casesWithOr) {
    throw 'Nightly disjunction case total does not match per-case source metrics.'
}
$minimumOrCases = [Math]::Max(1, [Math]::Ceiling($ExpectedCount * 0.20))
if ($observedOrCases -lt $minimumOrCases) {
    throw "Nightly disjunction coverage is below the minimum of $minimumOrCases cases (20% of the corpus)."
}

$referencePathProperty = $Summary.PSObject.Properties['referencePathCaseCounts']
if ($null -eq $referencePathProperty -or $null -eq $referencePathProperty.Value) {
    throw 'Nightly corpus did not record reference interpreter path counts.'
}
foreach ($pathCheck in @(
        @{ name = 'or-rhs-executed'; observed = $observedOrRhsExecutedCases },
        @{ name = 'or-rhs-skipped'; observed = $observedOrRhsSkippedCases }
    )) {
    $property = $referencePathProperty.Value.PSObject.Properties[$pathCheck.name]
    if ($null -eq $property -or $null -eq $property.Value -or [long]$property.Value -le 0) {
        throw "Nightly reference traces did not exercise the required '$($pathCheck.name)' path."
    }
    if ([long]$property.Value -ne [long]$pathCheck.observed) {
        throw "Nightly reference trace '$($pathCheck.name)' case total does not match per-case records."
    }
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
    choiceReturningFunctionCases = $Summary.casesWithChoiceReturningFunction
    choiceReturningFunctionCount = $choiceFunctionCount.Value
    disjunctionCases = $Summary.casesWithOr
    minimumDisjunctionCases = $minimumOrCases
    disjunctionRhsExecutedCases = $observedOrRhsExecutedCases
    disjunctionRhsSkippedCases = $observedOrRhsSkippedCases
    directComposedCases = $Summary.casesWithDirectValtypeRaiseArrayComposition
    bothProbeTraceCases = $Summary.casesVisitingBothValtypeProbeKinds
    raiseSuccessPathCases = $Summary.referencePathCaseCounts.'valtype-raise-success-path'
    raiseErrorPathCases = $Summary.referencePathCaseCounts.'valtype-raise-error-path'
}
