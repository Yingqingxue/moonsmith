[CmdletBinding()]
param(
    [int]$Seed,
    [int]$Depth,
    [string[]]$Targets,
    [int]$TimeoutSeconds,
    [string]$SourcePath,
    [switch]$NoPersist
)

$source = [IO.File]::ReadAllText($SourcePath)
$match = [regex]::Match($source, 'println\(deep\(([\d_]+)\)\)')
if (-not $match.Success) { throw 'Expected the depth argument in the candidate source.' }
$candidateDepth = [int]($match.Groups[1].Value -replace '_', '')
$native = [pscustomobject]@{ target = 'native'; status = 'succeeded'; exitCode = 0; output = ''; error = '' }
$js = [pscustomobject]@{ target = 'js'; status = 'succeeded'; exitCode = 0; output = ''; error = '' }
$finding = 'consistent'
if ($candidateDepth -eq 1000000 -and $env:MOONSMITH_MOCK_NATIVE_FIXED -eq '1') {
    # Model the normal return path after a hypothetical upstream fix.
    $finding = 'runtime-failure'
    $native.output = "before-deep-recursion`n1000000`n"
    $js.status = 'runtime-failed'
    $js.exitCode = 1
    $js.error = 'RangeError: Maximum call stack size exceeded'
} elseif ($candidateDepth -ge 750000) {
    $finding = 'runtime-failure'
    $native.status = 'runtime-failed'
    $native.exitCode = 139
    $js.status = 'runtime-failed'
    $js.exitCode = 1
    $js.error = 'RangeError: Maximum call stack size exceeded'
} elseif ($candidateDepth -eq 500000 -and $env:MOONSMITH_MOCK_UNKNOWN_AT_500K -eq '1') {
    # Model a mixed/unknown outcome. The search must fail closed and preserve
    # enough structured evidence to diagnose why this is not a valid bound.
    $finding = 'mixed-failure'
    $native.status = 'timed-out'
    $native.exitCode = -1
    $js.status = 'runtime-failed'
    $js.exitCode = 1
    $js.error = 'RangeError: Maximum call stack size exceeded'
} else {
    # Below the native crash boundary, the exact paired signature is absent:
    # native returns the known pre-crash print and value while JS still errors.
    $native.output = "before-deep-recursion`n$candidateDepth`n"
    if ($candidateDepth -gt 0) {
        $finding = 'runtime-failure'
        $js.status = 'runtime-failed'
        $js.exitCode = 1
        $js.error = 'RangeError: Maximum call stack size exceeded'
    }
}
[pscustomobject]@{
    finding = $finding
    runs = @($native, $js)
} | ConvertTo-Json -Depth 5 -Compress
