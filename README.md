# sysadmin-main

Windows sysadmin PowerShell scripts for Windows PowerShell 5.1 under `PowerShell Script/`.

Runtime scripts under `PowerShell Script/` are designed to be copied and run as single files on target PCs. When an original script still has baked-in launch-time defaults, the repo keeps a sibling `.Standalone.ps1` copy next to it instead of changing the original contract.

Start with `AGENTS.md` for the branch playbook, `PLANS.md` for repo-specific ExecPlan rules, `SKILL.md` for the short workflow entrypoint, and `docs/sysadmin-main-multi-agent-sop.md` for the longer branch-specific workflow notes.

Historical changelog or imported notes may reference `.agents/`, `.codex/agents/`, or `.github/workflows/` from fuller upstream layouts; this checkout is the local script, tool, test, docs, sandbox, and validation-artifact slice.
