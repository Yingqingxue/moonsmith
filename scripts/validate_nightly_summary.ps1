param(
    [Parameter(Mandatory)]
    [object]$Summary,

    [ValidateRange(1, 10000)]
    [int]$ExpectedCount = 1000
)

$ErrorActionPreference = 'Stop'
if ($Summary.schemaVersion -ne 10) {
    throw "Nightly corpus validator requires batch schema 10; received '$($Summary.schemaVersion)'."
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
    'casesWithChoiceReturningFunction',
    'casesWithOr',
    'casesWithAnd',
    'casesWithWhileLoop',
    'casesWithWhileIteration'
    'casesWithArrayAliasUpdate'
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
$observedAndCases = 0
$observedOrRhsExecutedCases = 0
$observedOrRhsSkippedCases = 0
$observedAndRhsExecutedCases = 0
$observedAndRhsSkippedCases = 0
$observedWhileLoopCases = 0
$observedWhileIterationCases = 0
$observedArrayGrowFirstIndexCases = 0
$observedArrayGrowSecondIndexCases = 0
$observedArrayGrowSourceCases = 0
$observedArrayAliasUpdateSourceCases = 0
$observedArrayAliasUpdateFirstIndexCases = 0
$observedArrayAliasUpdateSecondIndexCases = 0
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

    $andCount = if ($null -ne $constructCounts -and $null -ne $constructCounts.Value) {
        $constructCounts.Value.PSObject.Properties['and']
    } else {
        $null
    }
    if ($null -eq $andCount -or $null -eq $andCount.Value -or [long]$andCount.Value -lt 0) {
        throw "Nightly case '$($case.seed)' is missing a valid sourceConstructCounts.and value."
    }
    if ([long]$andCount.Value -gt 0) { $observedAndCases++ }

    $whileCount = if ($null -ne $constructCounts -and $null -ne $constructCounts.Value) {
        $constructCounts.Value.PSObject.Properties['whileLoop']
    } else {
        $null
    }
    if ($null -eq $whileCount -or $null -eq $whileCount.Value -or [long]$whileCount.Value -lt 0) {
        throw "Nightly case '$($case.seed)' is missing a valid sourceConstructCounts.whileLoop value."
    }
    if ([long]$whileCount.Value -gt 0) { $observedWhileLoopCases++ }

    $arrayGrowCount = if ($null -ne $constructCounts -and $null -ne $constructCounts.Value) {
        $constructCounts.Value.PSObject.Properties['arrayGrow']
    } else {
        $null
    }
    if ($null -eq $arrayGrowCount -or $null -eq $arrayGrowCount.Value -or [long]$arrayGrowCount.Value -lt 0) {
        throw "Nightly case '$($case.seed)' is missing a valid sourceConstructCounts.arrayGrow value."
    }
    if ([long]$arrayGrowCount.Value -gt 0) { $observedArrayGrowSourceCases++ }
    $arrayAliasUpdateCount = if ($null -ne $constructCounts -and $null -ne $constructCounts.Value) {
        $constructCounts.Value.PSObject.Properties['arrayAliasUpdate']
    } else {
        $null
    }
    if ($null -eq $arrayAliasUpdateCount -or $null -eq $arrayAliasUpdateCount.Value -or
        [long]$arrayAliasUpdateCount.Value -lt 0) {
        throw "Nightly case '$($case.seed)' is missing a valid sourceConstructCounts.arrayAliasUpdate value."
    }
    if ([long]$arrayAliasUpdateCount.Value -gt 0) { $observedArrayAliasUpdateSourceCases++ }

    $pathKinds = $case.PSObject.Properties['referencePathKinds']
    if ($null -eq $pathKinds -or $null -eq $pathKinds.Value) {
        throw "Nightly case '$($case.seed)' is missing referencePathKinds."
    }
    $casePathKinds = @($pathKinds.Value)
    if ($casePathKinds -contains 'or-rhs-executed') { $observedOrRhsExecutedCases++ }
    if ($casePathKinds -contains 'or-rhs-skipped') { $observedOrRhsSkippedCases++ }
    if ($casePathKinds -contains 'and-rhs-executed') { $observedAndRhsExecutedCases++ }
    if ($casePathKinds -contains 'and-rhs-skipped') { $observedAndRhsSkippedCases++ }
    if ($casePathKinds -contains 'while-iteration') { $observedWhileIterationCases++ }
    if ($casePathKinds -contains 'array-grow-index-0') { $observedArrayGrowFirstIndexCases++ }
    if ($casePathKinds -contains 'array-grow-index-1') { $observedArrayGrowSecondIndexCases++ }
    if ($casePathKinds -contains 'array-alias-update-index-0') { $observedArrayAliasUpdateFirstIndexCases++ }
    if ($casePathKinds -contains 'array-alias-update-index-1') { $observedArrayAliasUpdateSecondIndexCases++ }
    if (($casePathKinds -contains 'array-grow-index-0' -or
            $casePathKinds -contains 'array-grow-index-1') -and
        [long]$arrayGrowCount.Value -eq 0) {
        throw "Nightly case '$($case.seed)' executed a grown-array index without generated array growth."
    }
    if (($casePathKinds -contains 'array-alias-update-index-0' -or
            $casePathKinds -contains 'array-alias-update-index-1') -and
        [long]$arrayAliasUpdateCount.Value -eq 0) {
        throw "Nightly case '$($case.seed)' executed an alias update without generated array aliasing."
    }
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
if ($observedAndCases -ne [long]$Summary.casesWithAnd) {
    throw 'Nightly conjunction case total does not match per-case source metrics.'
}
if ($observedWhileLoopCases -ne [long]$Summary.casesWithWhileLoop) {
    throw 'Nightly while-loop case total does not match per-case source metrics.'
}
if ($observedWhileIterationCases -ne [long]$Summary.casesWithWhileIteration) {
    throw 'Nightly while-iteration case total does not match per-case reference paths.'
}
if ($observedArrayGrowSourceCases -ne [long]$Summary.casesWithArrayGrow) {
    throw 'Nightly array-growth case total does not match per-case source metrics.'
}
if ($observedArrayAliasUpdateSourceCases -ne [long]$Summary.casesWithArrayAliasUpdate) {
    throw 'Nightly array-alias-update case total does not match per-case source metrics.'
}
$minimumOrCases = [Math]::Max(1, [Math]::Ceiling($ExpectedCount * 0.20))
if ($observedOrCases -lt $minimumOrCases) {
    throw "Nightly disjunction coverage is below the minimum of $minimumOrCases cases (20% of the corpus)."
}
$minimumAndCases = [Math]::Max(1, [Math]::Ceiling($ExpectedCount * 0.20))
if ($observedAndCases -lt $minimumAndCases) {
    throw "Nightly conjunction coverage is below the minimum of $minimumAndCases cases (20% of the corpus)."
}

$referencePathProperty = $Summary.PSObject.Properties['referencePathCaseCounts']
if ($null -eq $referencePathProperty -or $null -eq $referencePathProperty.Value) {
    throw 'Nightly corpus did not record reference interpreter path counts.'
}
foreach ($pathCheck in @(
        @{ name = 'or-rhs-executed'; observed = $observedOrRhsExecutedCases },
        @{ name = 'or-rhs-skipped'; observed = $observedOrRhsSkippedCases },
        @{ name = 'and-rhs-executed'; observed = $observedAndRhsExecutedCases },
        @{ name = 'and-rhs-skipped'; observed = $observedAndRhsSkippedCases },
        @{ name = 'while-iteration'; observed = $observedWhileIterationCases },
        @{ name = 'array-grow-index-0'; observed = $observedArrayGrowFirstIndexCases },
        @{ name = 'array-grow-index-1'; observed = $observedArrayGrowSecondIndexCases },
        @{ name = 'array-alias-update-index-0'; observed = $observedArrayAliasUpdateFirstIndexCases },
        @{ name = 'array-alias-update-index-1'; observed = $observedArrayAliasUpdateSecondIndexCases }
    )) {
    $property = $referencePathProperty.Value.PSObject.Properties[$pathCheck.name]
    if ($null -eq $property -or $null -eq $property.Value -or [long]$property.Value -le 0) {
        throw "Nightly reference traces did not exercise the required '$($pathCheck.name)' path."
    }
    if ([long]$property.Value -ne [long]$pathCheck.observed) {
        throw "Nightly reference trace '$($pathCheck.name)' case total does not match per-case records."
    }
}
$minimumArrayGrowIndexCases = [Math]::Max(1, [Math]::Ceiling($ExpectedCount * 0.02))
if ($observedArrayGrowFirstIndexCases -lt $minimumArrayGrowIndexCases -or
    $observedArrayGrowSecondIndexCases -lt $minimumArrayGrowIndexCases) {
    throw "Nightly grown-array index coverage is below $minimumArrayGrowIndexCases cases per index (2% of the corpus)."
}
$minimumArrayAliasUpdateIndexCases = [Math]::Max(1, [Math]::Ceiling($ExpectedCount * 0.02))
if ($observedArrayAliasUpdateFirstIndexCases -lt $minimumArrayAliasUpdateIndexCases -or
    $observedArrayAliasUpdateSecondIndexCases -lt $minimumArrayAliasUpdateIndexCases) {
    throw "Nightly array-alias-update index coverage is below $minimumArrayAliasUpdateIndexCases cases per index (2% of the corpus)."
}
if ($observedArrayAliasUpdateFirstIndexCases * 2 -lt $observedArrayAliasUpdateSecondIndexCases -or
    $observedArrayAliasUpdateSecondIndexCases * 2 -lt $observedArrayAliasUpdateFirstIndexCases) {
    throw 'Nightly array-alias-update index balance is worse than 1:2.'
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
    conjunctionCases = $Summary.casesWithAnd
    minimumConjunctionCases = $minimumAndCases
    conjunctionRhsExecutedCases = $observedAndRhsExecutedCases
    conjunctionRhsSkippedCases = $observedAndRhsSkippedCases
    whileLoopCases = $observedWhileLoopCases
    whileIterationCases = $observedWhileIterationCases
    arrayGrowFirstIndexCases = $observedArrayGrowFirstIndexCases
    arrayGrowSecondIndexCases = $observedArrayGrowSecondIndexCases
    minimumArrayGrowIndexCases = $minimumArrayGrowIndexCases
    arrayGrowSourceCases = $observedArrayGrowSourceCases
    arrayAliasUpdateSourceCases = $observedArrayAliasUpdateSourceCases
    arrayAliasUpdateFirstIndexCases = $observedArrayAliasUpdateFirstIndexCases
    arrayAliasUpdateSecondIndexCases = $observedArrayAliasUpdateSecondIndexCases
    minimumArrayAliasUpdateIndexCases = $minimumArrayAliasUpdateIndexCases
    directComposedCases = $Summary.casesWithDirectValtypeRaiseArrayComposition
    bothProbeTraceCases = $Summary.casesVisitingBothValtypeProbeKinds
    raiseSuccessPathCases = $Summary.referencePathCaseCounts.'valtype-raise-success-path'
    raiseErrorPathCases = $Summary.referencePathCaseCounts.'valtype-raise-error-path'
}
