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
$match = [regex]::Match($source, 'println\(deep\((\d+)\)\)')
if (-not $match.Success) { throw 'Expected the depth argument in the candidate source.' }
$candidateDepth = [int]$match.Groups[1].Value
$native = [pscustomobject]@{ target = 'native'; status = 'succeeded'; exitCode = 0; output = ''; error = '' }
$js = [pscustomobject]@{ target = 'js'; status = 'succeeded'; exitCode = 0; output = ''; error = '' }
$finding = 'consistent'
if ($candidateDepth -eq 1000000) {
    $finding = 'runtime-failure'
    $native.status = 'runtime-failed'
    $native.exitCode = 139
    $js.status = 'runtime-failed'
    $js.exitCode = 1
    $js.error = 'RangeError: Maximum call stack size exceeded'
} elseif ($candidateDepth -eq 500000) {
    # Model a mixed/unknown outcome. The search must fail closed and preserve
    # enough structured evidence to diagnose why this is not a valid bound.
    $finding = 'mixed-failure'
    $js.status = 'runtime-failed'
    $js.exitCode = 1
    $js.error = 'RangeError: Maximum call stack size exceeded'
}
[pscustomobject]@{
    finding = $finding
    runs = @($native, $js)
} | ConvertTo-Json -Depth 5 -Compress
