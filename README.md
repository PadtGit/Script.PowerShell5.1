# sysadmin-main

Windows sysadmin PowerShell scripts for Windows PowerShell 5.1 under `PowerShell Script/`.

This checkout is the local script, tool, test, docs, sandbox, and validation-artifact slice of the repo. Runtime scripts under `PowerShell Script/` stay copyable as single files for PC-side use; when an original script still has baked-in launch-time defaults, keep a sibling `.Standalone.ps1` copy instead of changing that contract.

Use `AGENTS.md` for the canonical playbook, safety invariants, and validation commands. Use `PLANS.md` for ExecPlan requirements, `SKILL.md` for the short working rules, `docs/sysadmin-main-multi-agent-sop.md` for workflow responsibilities, `docs/windows-sandbox-validation.md` for Windows Sandbox guidance, and `CHANGELOG.md` for landed history.

Historical notes may describe fuller upstream layouts. Verify paths against this checkout before reusing copied workflow instructions.
