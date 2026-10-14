#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! grep -qE '(^| )fma( |$)' /proc/cpuinfo; then
  echo "GCC/FMA experiment requires a runner exposing the CPU FMA feature" >&2
  exit 2
fi

# Build the known cancellation-sensitive case through MoonSmith's typed AST.
generated_source="$(moon run --target js cmd/main --fma-probe)"
if [[ "$generated_source" != *"_ms_fma_product"* ]]; then
  echo "MoonSmith did not emit the expected FMA probe source" >&2
  exit 1
fi

temporary_root="$(mktemp -d)"
trap 'rm -rf "$temporary_root"' EXIT
cp regressions/issue_2262_gcc_fma/moon.mod "$temporary_root/moon.mod"
mkdir -p "$temporary_root/fast" "$temporary_root/control"
cp regressions/issue_2262_gcc_fma/fast/moon.pkg "$temporary_root/fast/moon.pkg"
cp regressions/issue_2262_gcc_fma/control/moon.pkg "$temporary_root/control/moon.pkg"
printf '%s\n' "$generated_source" > "$temporary_root/fast/main.mbt"
printf '%s\n' "$generated_source" > "$temporary_root/control/main.mbt"

run_expect() {
  local expected="$1"
  shift
  local actual
  actual="$("$@")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected %s, got %s from:' "$expected" "$actual" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    exit 1
  fi
  printf '%s -> %s\n' "$*" "$actual"
}

fast=(moon -C "$temporary_root/fast" run --release)
control=(moon -C "$temporary_root/control" run --release)

run_expect true "${fast[@]}" --target js .
run_expect true "${fast[@]}" --target wasm .
run_expect true "${fast[@]}" --target wasm-gc .
run_expect false "${fast[@]}" --target native .
run_expect true "${control[@]}" --target native .
