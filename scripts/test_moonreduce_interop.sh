#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
moonreduce_binary=${MOONREDUCE_BINARY:?Set MOONREDUCE_BINARY to a built MoonReduce executable}
command -v pwsh >/dev/null
command -v python3 >/dev/null
[[ -x "$moonreduce_binary" ]] || { echo "MoonReduce executable not found: $moonreduce_binary" >&2; exit 1; }

set +e
baseline_json=$(MOONSMITH_ROOT="$repo_root" pwsh -NoProfile -Command '
  & "$env:MOONSMITH_ROOT/scripts/verify_seed.ps1" -Seed 0 -Depth 3 `
    -Targets @("js", "wasm") -InjectOutputMismatchTarget wasm
')
baseline_exit=$?
set -e
[[ -n "$baseline_json" ]] || {
  echo "MoonSmith did not emit the injected baseline report (exit code $baseline_exit)" >&2
  exit 1
}
[[ $baseline_exit -eq 1 ]] || {
  echo "Expected the intentionally injected baseline to exit 1; got $baseline_exit" >&2
  exit 1
}

baseline_dir=$(printf '%s' "$baseline_json" | python3 -c \
  'import json,sys; report=json.load(sys.stdin); assert report["finding"] == "output-mismatch"; assert report["injection"]["kind"] == "output-mismatch"; print(report["savedTo"])')
[[ -f "$baseline_dir/source.mbt" && -f "$baseline_dir/report.json" ]]

results_root="$repo_root/.moonsmith/moonreduce-integration"
mkdir -p "$results_root"
out_dir="$results_root/run-$(date -u +%Y%m%dT%H%M%SZ)-$$"
pwsh_path=$(command -v pwsh)
"$moonreduce_binary" reduce \
  --input "$baseline_dir/source.mbt" \
  --format lines \
  --checker "$pwsh_path" \
  --checker-arg -NoProfile \
  --checker-arg -File \
  --checker-arg "$repo_root/scripts/moonreduce_checker.ps1" \
  --checker-arg -BaselineReportPath \
  --checker-arg "$baseline_dir/report.json" \
  --out "$out_dir" \
  --timeout-ms 60000 \
  --max-tests 1

python3 - "$out_dir/report.json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as report_file:
    report = json.load(report_file)
status = report.get("status")
if status not in {"verified_reduction", "verified_unchanged"}:
    raise SystemExit(f"MoonReduce did not produce a verified result: status={status!r}")
print(json.dumps({"status": status, "report": sys.argv[1]}, sort_keys=True))
PY

# Exercise MoonReduce on the checked-in, externally reported #1322 reproducer.
# The PowerShell helper keeps validation logic locally testable on Windows.
pwsh -NoProfile -File "$repo_root/scripts/test_moonreduce_issue_1322.ps1" \
  -MoonReduceBinary "$moonreduce_binary" \
  -OutputDirectory "$out_dir/upstream-1322"

# Repeat the reduction study on a runtime crash rather than a compile-time
# ICE. The summary distinguishes edits to source content from formatting-only
# changes and records whether the recursive failure trigger survived.
pwsh -NoProfile -File "$repo_root/scripts/test_moonreduce_issue_2228.ps1" \
  -MoonReduceBinary "$moonreduce_binary" \
  -OutputDirectory "$out_dir/upstream-2228"
