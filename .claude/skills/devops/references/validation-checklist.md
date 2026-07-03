# Validation Checklist

Run every category against the target `Accepted` change-plan before authoring its runbook. Each yields OK / CONDITION / FAIL. Any FAIL ⇒ **SEND-BACK**. Any CONDITION with no FAIL ⇒ **PASS-WITH-CONDITIONS**. All OK ⇒ **PASS**.

## 1. Status & authority
- [ ] The change-plan exists and is not `Rejected`/`Superseded`. `Accepted` is preferred; a still-`Proposed` plan can be worked when you are invoked directly (`devops 000N`) — note it and flag the architect to confirm the status. Only a genuine design defect is a SEND-BACK.
- [ ] It is one decision, not several tangled together.

## 1b. Live-state & release scan (do this first, via `ssh proxmox`)
- [ ] `pveversion` (+ `uname -r`) captured — every command, package, and privilege name in the runbook targets **this** release.
- [ ] Every privilege / flag / parameter a step uses is confirmed to exist in this release (e.g. `pveum role list`), not assumed from memory.
- [ ] Every object the plan creates was checked for prior existence (`pvs; vgs; lvs; pvesm status; pveum user list; pveum role list; qm list; pct list; ip -br a`) — the runbook reflects the real current→desired delta (idempotent or a targeted completion where something already exists), not a blind create.
- [ ] Real free CPU/RAM/storage read from the node (`free -h; nproc; pvesm status; lsblk`) — this, not a doc, feeds the cumulative budget in §2.
- [ ] Device names (e.g. which disk is the SSD) confirmed via `lsblk`, not assumed from a doc.
- [ ] Where the scan and a doc disagree, the scan wins; flag the `architect` to correct the doc before authoring around the real value.

## 2. Fit to the hardware ceiling (cumulative)
- [ ] Sum **vCPU** across all `Accepted`+`Implemented` plans **plus this one**. Flag if nominal allocation exceeds 6 with no idle headroom to justify oversubscription.
- [ ] Sum **RAM** the same way against **31 GB usable** (leave host ~2 GB). Flag if it exceeds the ceiling or leaves no headroom for the next planned slice.
- [ ] Check **storage**: which pool (`local-lvm` NVMe vs. `ssd-data` SSD vs. `local`) and whether it has the space. Data volumes on `ssd-data`; OS/root on `local-lvm`.
- [ ] Check **network**: single 1 GbE NIC, no managed switch — no design may assume a second physical NIC or VLAN hardware.

## 3. Dependencies & ordering
- [ ] Every prerequisite change-plan is `Accepted` or `Implemented` — no dependency on a `Proposed` plan.
- [ ] No forward reference (this slice does not require something only a later slice provides).
- [ ] Execution order respects `plan.md` and change-plan/0001's roadmap.

## 4. Conventions consistency (you own this)
- [ ] No collision of IP / VMID / hostname / storage ID / port with `docs/platform-conventions.md` or any other runbook.
- [ ] If new identifiers are needed, allocate them per the conventions' rules and **write them into `docs/platform-conventions.md`** before the runbook references them.
- [ ] Pinned versions are compatible with what is already deployed.

## 5. Conflict & supersession
- [ ] Does not contradict an `Accepted`/`Implemented` plan or `docs/current-state-analysis.md`. If it does, the architect must supersede that plan first — SEND-BACK.

## 6. Reversibility & safety
- [ ] A real rollback exists (not "reinstall the host").
- [ ] Every destructive action (`wipefs`, `vgremove`, `terraform destroy`, dropping data) is preceded by a verify of the exact target.
- [ ] Anything holding data has a backup step before a destructive change.

## 7. Security & secrets
- [ ] Least privilege (scoped API roles/users, not blanket root/admin).
- [ ] No plaintext credentials in the repo; gitignored bootstrap only until the secrets manager exists, then via the secrets manager.
- [ ] Nothing on the private subnet is needlessly exposed to the LAN.

## 8. Verifiability & portfolio value
- [ ] The slice is **independently demonstrable** — a Definition of Done that proves it alone.
- [ ] Each step has an expected-output Verify.
- [ ] Honest framing carried over from the plan (single node = pattern, not HA) — no overclaiming.

## 9. Extensibility & executer-readiness
- [ ] Prefer idempotent, re-runnable tooling (Terraform/Ansible) over one-shot manual steps where practical.
- [ ] The slice leaves clear hooks for the next planned slice.
- [ ] The runbook conforms to `executer-contract.md` so the `executer` skill can execute it deterministically.

## Verdict block (paste into the runbook's Validation section)
```
Verdict: PASS | PASS-WITH-CONDITIONS | SEND-BACK
Validated: YYYY-MM-DD
Cumulative budget: <vCPU>/6 · <RAM>/31GB · pools OK?
Conditions: <...> | N/A
Conventions allocated: <...> | N/A
```
