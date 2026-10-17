param(
    [Parameter(Position = 0)]
    [ValidateSet('doctor', 'demo', 'fuzz', 'replay', 'reduce', 'report', 'batch-report', 'help')]
    [string]$Command = 'help',

    [int]$Seed = 42,
    [int]$SeedStart = 0,

    [ValidateRange(1, 10000)]
    [int]$Count = 100,

    [ValidateRange(0, 12)]
    [int]$Depth = 4,

    [ValidateSet('js', 'wasm', 'wasm-gc', 'native', 'native-release')]
    [string[]]$Targets = @('js', 'wasm', 'wasm-gc'),

    [ValidateRange(1, 300)]
    [int]$TimeoutSeconds = 10,

    [string]$CasePath = '',
    [string]$BatchPath = '',
    [string]$BatchOutputPath = '',
    [string]$ReductionPath = '',
    [switch]$Force,

    [ValidateRange(1, 10000)]
    [int]$MaxAttempts = 100,

    [string]$InjectOutputMismatchTarget = '',
    [string]$InjectOnlyWhenSourceContains = '',
    [string]$InjectCommonWrongOutput = ''
)

$ErrorActionPreference = 'Stop'
$verifyScript = Join-Path $PSScriptRoot 'verify_seed.ps1'

switch ($Command) {
    'help' {
        @'
MoonSmith commands:
  doctor                         Check MoonBit and execute a small backend probe.
  demo                           Run an explicitly injected end-to-end example.
  fuzz   -SeedStart N -Count N    Run a deterministic seed range.
  replay -CasePath PATH           Replay a saved finding directory or report.json.
  reduce -Seed N -Depth N         Reduce a reproducible generated finding.
  report -CasePath PATH           Render saved finding as Markdown and offline HTML.
  batch-report -BatchPath PATH    Render batch JSON as an offline HTML summary.
                 -BatchOutputPath PATH optionally selects the HTML output path.

Common options: -Depth N -Targets js,wasm,wasm-gc,native,native-release -TimeoutSeconds N
The reduce command also accepts -MaxAttempts and explicit fault-injection options.
The report command accepts -ReductionPath PATH and -Force to replace report.md and report.html.
This is a PowerShell host adapter; the generator, oracle, and AST reducer are MoonBit.
'@
        exit 0
    }
    'doctor' {
        $moonCommand = Get-Command moon -ErrorAction SilentlyContinue
        if ($null -eq $moonCommand) {
            [pscustomobject]@{
                command = 'doctor'
                ready = $false
                error = 'moon was not found on PATH'
            } | ConvertTo-Json -Depth 4
            exit 1
        }
        $version = (& moon version | Select-Object -First 1)
        $raw = & $verifyScript -Seed 0 -Depth 0 -Targets $Targets `
            -TimeoutSeconds $TimeoutSeconds -NoPersist
        $probe = $raw | ConvertFrom-Json
        $ready = $probe.finding -eq 'consistent'
        [pscustomobject]@{
            command = 'doctor'
            ready = $ready
            moonVersion = $version
            powerShellVersion = $PSVersionTable.PSVersion.ToString()
            targets = @($probe.runs | Select-Object target, status, exitCode)
            finding = $probe.finding
        } | ConvertTo-Json -Depth 5
        if (-not $ready) { exit 1 }
        exit 0
    }
    'demo' {
        & (Join-Path $PSScriptRoot 'demo.ps1')
        if ($LASTEXITCODE -ne 0) { exit 1 }
        exit 0
    }
    'fuzz' {
        $raw = & (Join-Path $PSScriptRoot 'run_batch.ps1') -SeedStart $SeedStart `
            -Count $Count -Depth $Depth -Targets $Targets `
            -TimeoutSeconds $TimeoutSeconds
        $batch = $raw | ConvertFrom-Json
        $raw
        if ($batch.harnessChangedDuringRun) { exit 2 }
        if ($batch.unexpectedFindingCount -ne 0) { exit 1 }
        exit 0
    }
    'reduce' {
        $raw = & (Join-Path $PSScriptRoot 'reduce_case.ps1') -Seed $Seed `
            -Depth $Depth -Targets $Targets -TimeoutSeconds $TimeoutSeconds `
            -MaxAttempts $MaxAttempts `
            -InjectOutputMismatchTarget $InjectOutputMismatchTarget `
            -InjectOnlyWhenSourceContains $InjectOnlyWhenSourceContains `
            -InjectCommonWrongOutput $InjectCommonWrongOutput
        $raw
        exit 0
    }
    'replay' {
        if (-not $CasePath) {
            throw 'replay requires -CasePath pointing to a saved finding.'
        }
        $resolved = (Resolve-Path -LiteralPath $CasePath -ErrorAction Stop).Path
        $caseDirectory = if (Test-Path -LiteralPath $resolved -PathType Container) {
            $resolved
        } else {
            Split-Path -Parent $resolved
        }
        $reportPath = Join-Path $caseDirectory 'report.json'
        $sourcePath = Join-Path $caseDirectory 'source.mbt'
        foreach ($required in @($reportPath, $sourcePath)) {
            if (-not (Test-Path -LiteralPath $required -PathType Leaf)) {
                throw "Saved finding is missing $required"
            }
        }
        $original = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $sourceHashProperty = $original.PSObject.Properties['sourceSha256']
        $sourceIntegrityChecked = $null -ne $sourceHashProperty
        $sourceSha256 = (Get-FileHash -LiteralPath $sourcePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($sourceIntegrityChecked) {
            $recordedSourceSha256 = [string]$sourceHashProperty.Value
            if ($recordedSourceSha256 -notmatch '^[0-9a-fA-F]{64}$') {
                throw "Saved report '$reportPath' contains an invalid sourceSha256 value."
            }
            if ($sourceSha256 -ne $recordedSourceSha256.ToLowerInvariant()) {
                throw "Saved source '$sourcePath' does not match the SHA-256 recorded in report.json. Restore the original source or save a new finding before replay."
            }
        }
        if ($original.injection -and $original.injection.kind -eq 'common-wrong-output') {
            throw 'This older injected case does not record the replacement output, so it cannot be replayed faithfully.'
        }
        $replayOptions = @{
            Seed = [int]$original.seed
            Depth = [int]$original.depth
            Targets = @($original.runs | Select-Object -ExpandProperty target)
            TimeoutSeconds = [int]$original.timeoutSeconds
            SourcePath = $sourcePath
            NoPersist = $true
        }
        $hasReferenceCheckedField = $null -ne $original.PSObject.Properties['referenceChecked']
        $shouldReplayReference = if ($hasReferenceCheckedField) {
            [bool]$original.referenceChecked
        } else {
            # Older reports did not record the flag; retain their historical
            # non-empty-output inference while preserving explicit empty values
            # in current reports.
            -not [string]::IsNullOrEmpty([string]$original.expectedOutput)
        }
        if ($shouldReplayReference) {
            $replayOptions.ExpectedOutput = [string]$original.expectedOutput
        }
        if ($original.injection -and $original.injection.kind -eq 'output-mismatch') {
            $replayOptions.InjectOutputMismatchTarget = [string]$original.injection.target
            $replayOptions.InjectOnlyWhenSourceContains = [string]$original.injection.sourceTrigger
        }
        $raw = & $verifyScript @replayOptions
        $replayed = $raw | ConvertFrom-Json
        $reproduced = $replayed.finding -eq $original.finding -and
            $replayed.reductionKey -eq $original.reductionKey
        [pscustomobject]@{
            command = 'replay'
            caseId = $original.caseId
            reproduced = $reproduced
            originalFinding = $original.finding
            replayFinding = $replayed.finding
            sourcePath = $sourcePath
            sourceIntegrityChecked = $sourceIntegrityChecked
            sourceSha256 = $sourceSha256
            targetStatuses = @($replayed.runs | Select-Object target, status, exitCode)
        } | ConvertTo-Json -Depth 5
        if (-not $reproduced) { exit 1 }
        exit 0
    }
    'report' {
        if (-not $CasePath) {
            throw 'report requires -CasePath pointing to a saved finding.'
        }
        & (Join-Path $PSScriptRoot 'render_report.ps1') -CasePath $CasePath `
            -ReductionPath $ReductionPath -Force:$Force
        exit 0
    }
    'batch-report' {
        if (-not $BatchPath) {
            throw 'batch-report requires -BatchPath pointing to a batch JSON file or directory.'
        }
        & (Join-Path $PSScriptRoot 'render_batch_report.ps1') -BatchPath $BatchPath `
            -OutputPath $BatchOutputPath -Force:$Force
        exit 0
    }
}
