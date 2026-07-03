# Runbook NNNN — <Short Descriptive Title>

- **Implements**: change-plan/NNNN
- **Status**: Draft <!-- Draft | Validated | Executed -->
- **Prerequisites**: <runbook numbers that must be Executed first, or "none">
- **Owner**: <who executes this>

## Validation
- **Verdict**: PASS | PASS-WITH-CONDITIONS <!-- SEND-BACK ⇒ no runbook is written; this template is only reached on a pass -->
- **Validated**: YYYY-MM-DD
- **Cumulative budget after this slice**: <vCPU used / 6 · RAM used / 31 GB · pool usage> — within ceiling? yes/no.
- **Conditions** (if any): <the named conditions this runbook must honor; else N/A>
- **Conventions allocated**: <new IPs/VMIDs/hostnames written into docs/platform-conventions.md, or N/A>

## Goal
One or two sentences: what state the node is in after this runbook that it was not in before.

## Conventions used
Pull every concrete value from `docs/platform-conventions.md`. List the specific rows this runbook depends on (IDs, IPs, sizes, versions). Do not invent values here.

## Steps
Each step: an imperative heading, exact commands (prompt-prefixed: `root@pve:~#` host · `you@ws:~$` workstation · `deploy@<guest>:~$` guest), then a **Verify** sub-step stating the expected output. Gate every destructive command behind a verify of its target.

### Step 1 — <action>
```
<commands>
```
**Verify:** <what proves this step worked>

## Definition of Done
The slice is independently demonstrable when all of these are true:
- [ ] …

## Rollback
Exact commands/steps that undo this slice. Note anything that must be backed up first.

## Extensibility / Further development
- **Idempotency**: which parts are re-runnable (Terraform/Ansible) vs. one-shot; how to re-run safely.
- **Next hooks**: where the following slices attach to what this one built.
- **Follow-ups**: deferred hardening or improvements.

## After execution
- [ ] Definition of Done passes.
- [ ] Set this runbook `Status` → `Executed`.
- [ ] Flag the `architect` to set `change-plan/NNNN` → `Implemented`, update `change-plan/plan.md`, and refresh `docs/current-state-analysis.md` (and `docs/hardware.md` if hardware/storage/network changed) — those live in the architect's domain.
