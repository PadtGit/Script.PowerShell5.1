# sysadmin-main

Windows sysadmin PowerShell scripts for Windows PowerShell 5.1 under `PowerShell Script/`.

Start with `AGENTS.md` for the branch playbook, `SKILL.md` for the repo entrypoint, and `docs/sysadmin-main-multi-agent-sop.md` for the longer branch-specific workflow notes.

Local workflow runs can also use `tools/Invoke-PerformanceRegressionCheck.ps1` with the committed baseline at `tools/performance-baselines/printer-pester-baseline.json` to catch likely printer-suite timing regressions early.

GitHub Actions CI now lives at `.github/workflows/powershell-ci.yml` with separate `lint`, `test`, `whatif`, and `perf` jobs that mirror the local validation entrypoints.

Historical changelog or imported notes may reference `.agents/`, `.codex/agents/`, or `.github/workflows/` from fuller upstream layouts; this checkout is the local script, tool, test, docs, sandbox, and validation-artifact slice.
