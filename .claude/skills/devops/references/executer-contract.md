# Executer Contract

The rules the **`executer`** skill (task executor) must follow when running a runbook, and therefore the rules `devops` must satisfy when authoring one. This is the interface between authoring and execution: a runbook that conforms here is safe to execute deterministically. Keep this file in sync whenever the runbook standard changes.

## Preconditions the executer checks before executing
1. **Validated only.** Execute a runbook only if its `Status` is `Validated` (or `Executed` for a deliberate re-run) and its Validation verdict is `PASS` or `PASS-WITH-CONDITIONS`. Never execute a `Draft` or a plan that was `SEND-BACK`.
2. **Prerequisites met.** Every runbook listed under `Prerequisites` must already be `Executed`. If not, stop and report.
3. **Conditions acknowledged.** For `PASS-WITH-CONDITIONS`, the named conditions are honored (e.g. keep CPU limits set, cap retention). Surface them before starting.
4. **State matches.** `docs/platform-conventions.md` and `docs/current-state-analysis.md` reflect the assumed starting state. If reality diverges, stop and report — do not improvise.

## Execution rules
5. **In order, no skipping.** Run steps top to bottom. Do not reorder or skip.
6. **Verify is a gate, not decoration.** After each step, run its **Verify** and confirm the expected output. On mismatch, **stop immediately** — do not proceed to the next step.
7. **Confirm before destroying.** For any destructive command, first run the target-verification the runbook specifies (e.g. confirm `/dev/sda` is the right disk) and confirm it matches before executing.
8. **Convention-only values.** Use the exact IPs/VMIDs/hostnames/sizes from `docs/platform-conventions.md`. Never invent or guess a value; if one is missing, stop and report (it is a `devops`/architect gap).
9. **No silent fixes.** If a step fails or a value is wrong, report it — do not patch the runbook or the design mid-execution. Fixes flow back to `devops` (runbook) or `architect` (design).

## On completion
10. **Definition of Done.** Run every DoD check. The slice is done only when all pass.
11. **Status transitions.** On DoD pass: set the runbook `Status` → `Executed` (runbooks are the executer's to update, this field only). Then **flag the `architect`** to set `change-plan/NNNN` → `Implemented`, update `change-plan/plan.md`, and refresh `docs/current-state-analysis.md` — `change-plan/` is the architect's domain; the executer does not write there.
12. **Report faithfully.** State what ran, what verified, what was skipped, and any deviation — with the real output. If something failed, say so plainly and stop.

## On failure
13. **Roll back.** Use the runbook's Rollback section to return the node to its prior state; back up first where the runbook says so.
14. **Leave a trail.** Report the failing step, its actual vs. expected output, and the rollback outcome, so `devops`/`architect` can act.

## Idempotency expectation
15. Re-running Terraform/Ansible steps must be safe (declarative, guarded). One-shot steps (`vault operator init`, disk wipes) are marked as such in the runbook and must not be blindly re-run.
