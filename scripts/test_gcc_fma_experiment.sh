#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! grep -qE '(^| )fma( |$)' /proc/cpuinfo; then
  echo "GCC/FMA experiment requires a runner exposing the CPU FMA feature" >&2
  exit 2
fi

# These exact inputs make the separately rounded product equal 1.0, so adding
# -1.0 yields zero. A fused multiply-add retains the exact -2^-54 residual.
a='1.000000007450580596923828125'
b='0.999999992549419403076171875'
c='-1.0'

run_expect() {
  local expected="$1"
  shift
  local actual
  actual="$("$@" "$a" "$b" "$c")"
  if [[ "$actual" != "$expected" ]]; then
    printf 'expected %s, got %s from:' "$expected" "$actual" >&2
    printf ' %q' "$@" >&2
    printf '\n' >&2
    exit 1
  fi
  printf '%s -> %s\n' "$*" "$actual"
}

fast=(moon -C regressions/issue_2262_gcc_fma/fast run --release)
control=(moon -C regressions/issue_2262_gcc_fma/control run --release)

run_expect zero "${fast[@]}" --target js .
run_expect zero "${fast[@]}" --target wasm .
run_expect zero "${fast[@]}" --target wasm-gc .
run_expect nonzero "${fast[@]}" --target native .
run_expect zero "${control[@]}" --target native .
