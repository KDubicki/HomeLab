# Runbooks

Step-by-step execution guides for the platform foundation. **Owned by the `devops` skill.** Each runbook implements one `change-plan/` ADR (same number): the ADR says *why*, the runbook says *how* — validated, with exact commands, verification, and rollback.

> Runbooks are authored by the `devops` skill once the matching change-plan is `Accepted` — one runbook per slice, conforming to the current standard. The **`executer`** skill executes them following the executer contract.

## Index
| # | Runbook | Status |
| :--- | :--- | :--- |
| 0002 | Host & storage hygiene | Validated |

## The pipeline
```
architect                 devops                     executer
change-plan/ (+ plan.md)  →  runbooks/ (validated)  →  execution on the node
   what / why                 how (this folder)          run it
```

## How a runbook is produced
1. `architect` marks a change-plan `Accepted`.
2. `devops` runs the validation checklist (`.claude/skills/devops/references/validation-checklist.md`). On `SEND-BACK` it goes back to the architect; on pass it authors the runbook here from `templates/runbook.md`.
3. Every runbook carries a **Validation** sign-off (verdict + cumulative budget), prompt-prefixed commands, **Verify** gates, **Rollback**, **Definition of Done**, and **Extensibility**.

## How a runbook is executed (executer contract)
Execution follows `.claude/skills/devops/references/executer-contract.md`: validated runbooks only, prerequisites met, steps in order, **Verify is a hard gate (stop on mismatch)**, confirm before destroying, convention-only values, and on Definition-of-Done pass the `executer` sets the runbook to `Executed` and flags the `architect` to mark the change-plan `Implemented` and refresh `change-plan/plan.md` + `docs/current-state-analysis.md`.

## Order
See `change-plan/plan.md` for the current slice list and focus. Slices execute in number order (0002 → 0008); each runbook lists its prerequisites.
