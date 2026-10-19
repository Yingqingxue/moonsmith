param(
    [Parameter(Mandatory)][ValidateSet('sequential','semanticGuided','moonGrammata')][string]$Arm,
    [Parameter(Mandatory)][int]$Attempt,
    [Parameter(Mandatory)][string]$OutputPath,
    [Parameter(Mandatory)][int]$DelayMilliseconds,
    [Parameter()][string]$InitialSeenPathKindsCsv = '',
    [Parameter()][string]$FailureMode = ''
)

$ErrorActionPreference = 'Stop'
if ($DelayMilliseconds -gt 0) { Start-Sleep -Milliseconds $DelayMilliseconds }
if ($FailureMode -eq 'no-valid-preflight') {
    [Console]::Error.WriteLine('Proposal window has no candidate with a completed reference preflight.')
    exit 1
}
$target = 'js'
if ($Arm -eq 'moonGrammata') {
    $result = [ordered]@{
        schemaVersion=1
        moonGrammata=[ordered]@{
            liveFindings=@('reference-match'); liveEvaluations=1; liveBackendExecutions=1
            observations=@(@{ backendRuns=@(@{target=$target;status='ok';exitCode=0}) })
        }
    }
} else {
    $result = [ordered]@{
        schemaVersion=1; proposalCount=2; backendChecks=1; backendExecutionAttempts=1
        findings=@{ 'reference-match'=1 }
        perArmCases=@(@{
            backendStatuses=@("${target}:ok:0")
            seenPathKindsBeforeSelection=@($InitialSeenPathKindsCsv -split ',' | Where-Object { $_ })
            referencePathKinds=@("mock-path-$Arm-$Attempt")
        })
    }
}
$json = $result | ConvertTo-Json -Depth 10
$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Force -Path $parent | Out-Null
[IO.File]::WriteAllText($OutputPath,$json + [Environment]::NewLine,[Text.UTF8Encoding]::new($false))
