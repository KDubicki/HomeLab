# Runbooks

Step-by-step execution guides for the platform foundation. **Owned by the `devops` skill.** Each runbook implements one `change-plan/` ADR (same number): the ADR says *why*, the runbook says *how* — validated, with exact commands, verification, and rollback.

> Runbooks are authored by the `devops` skill once the matching change-plan is `Accepted` — one runbook per slice. The **`executer`** skill executes them following the executer contract, and **a runbook is deleted once it is Executed** — it is an ephemeral execution artifact; the durable record is the `change-log/` entry + `docs/system-documentation.md`.

## Index
_No active runbooks. One is authored per Accepted change-plan and deleted once Executed (see `change-log/` for completed slices)._

| # | Runbook | Status |
| :--- | :--- | :--- |
| — | (none active) | — |

0003 (IaC control plane) was **Executed** 2026-07-04 and its runbook deleted; `change-log/0003` now holds the durable record.
0004 (private-subnet network) was **Executed** 2026-07-04 and its runbook deleted; tester-confirmed PASS; `change-log/0004` now holds the durable record.
0005 (Vault secrets) was **Executed** 2026-07-05 and its runbook deleted; tester-confirmed PASS on every step and the final Definition of Done; `change-log/0005` (pending architect move) will hold the durable record.

## The pipeline
```
architect          devops (000N)       executer ⇄ tester        architect-docs
change-plan/    →  runbooks/        →  run each step / verify → refresh as-built docs
  what / why        how (validated)     execute ↔ check           docs/system-documentation.md
                    (invoked directly)  (tester FAIL → devops)     (after finished work)
```

## How a runbook is produced
1. `architect` marks a change-plan `Accepted`.
2. `devops` runs the validation checklist (`.claude/skills/devops/references/validation-checklist.md`). On `SEND-BACK` it goes back to the architect; on pass it authors the runbook here from `templates/runbook.md`.
3. Every runbook carries a **Validation** sign-off (verdict + cumulative budget), prompt-prefixed commands, **Verify** gates, **Rollback**, **Definition of Done**, and **Extensibility**.

## How a runbook is executed (executer + tester)
Execution follows `.claude/skills/devops/references/executer-contract.md`: validated runbooks only, prerequisites met, steps in order, confirm before destroying, convention-only values. Each step is a **pair move** — the `executer` runs it, then the **`tester`** independently re-observes the live node and returns PASS/FAIL; the executer proceeds only on PASS, and a FAIL halts the run and routes the step back to `devops`. On Definition-of-Done pass (re-checked by the tester) the `executer` sets the runbook to `Executed` and flags the `architect` to mark the change-plan `Implemented` and refresh `change-plan/plan.md` + `docs/current-state-analysis.md`.

## Order
See `change-plan/plan.md` for the current slice list and focus. Slices execute in number order (0002 → 0008); each runbook lists its prerequisites.
