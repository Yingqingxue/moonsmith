# Issue 1322 same-runner toolchain comparison (2026-10-12)

Workflow: [GitHub Actions run 38272857808](https://github.com/Yingqingxue/moonsmith/actions/runs/38272857808), commit `958745f`. Both Linux and Windows jobs succeeded. Each job installed the two official MoonBit toolchain bundles sequentially on the same hosted runner, verified each requested MoonC version against `moon version --all`, cleaned `_build` between them, and ran `scripts/test_issue_1322.ps1` against the same checked-in fixture and generated probe. The downloaded run artifacts contain each per-version JSON report (including exact MoonC versions) and a comparison summary.

| Runner | MoonC version | C compiler (same for both versions in this job) | Native-debug fixture | Native release | Wasm-GC | Generated probe native debug |
| --- | --- | --- | --- | --- | --- | --- |
| Linux | `0.10.14+7d59c7ec9` → `0.10.15+943464bfa` | GCC 13.3.0 (`13.3.0-6ubuntu2~24.04.1`) | reproduced → reproduced | expected output → expected output | exit 0 → exit 0 | upstream signature → upstream signature |
| Windows | `0.10.14+7d59c7ec9` → `0.10.15+943464bfa` | MSVC 19.51.36260 x64 | not reproduced → reproduced | expected output → expected output | exit 0 → exit 0 | not reproduced → upstream signature |

This same-runner result strengthens the earlier cross-date observation: on this Windows runner, the native-debug result changed with the installed MoonBit toolchain while the recorded MSVC version remained the same. Linux reproduced the signature under both toolchains. The `native-release` and Wasm-GC controls passed in all four runs. MoonSmith's reference oracle classified the debug compile failure when present; the exact expected output is external to MoonSmith and comes from the upstream report.

This is evidence of a toolchain-bundle-associated change on one hosted runner per OS, not a confirmed root cause. The installer changes `moon`, `moonc`, and the bundled core together; the experiment does not isolate which component changed behavior, pin the hosted runner image, or control every dependency. It is one comparison per platform and does not establish whether the upstream behavior violates the language contract. Issue [moonbitlang/moon-docs#1322](https://github.com/moonbitlang/moon-docs/issues/1322) predates this project probe; this is not a MoonSmith discovery.
