# 0003 — IaC Control Plane (Terraform + Golden Template + Ansible)

- **Status**: Proposed
- **Date proposed**: 2026-07-03
- **Date decided**: —
- **Date implemented**: —
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0002; precedes 0004
- **Depends on**: 0002 (Proxmox API token, storage pools)

## Context
The heart of the portfolio is reproducibility: every VM/CT must be code, not a GUI click. Nothing exists yet — this slice builds the provisioning control plane that all later layers (0004–0008) are provisioned *through*.

## Decision
Stand up the IaC control plane:
1. **Terraform** with the **`bpg/proxmox`** provider, authenticating via the `terraform@pve` token (0002), managing VM/CT lifecycle. State kept locally in the repo working tree (gitignored), with a documented path to a Vault/MinIO-backed backend later.
2. A **cloud-init golden template** (Debian 13 / Ubuntu 24.04 LTS) built once and cloned by Terraform — the AMI analog.
3. An **Ansible baseline role** applied to every guest post-provision: admin user + SSH keys, SSH hardening, base packages, `node_exporter` (ready for 0008).

Prove the slice by provisioning one throwaway VM end-to-end from code and destroying it.

## Rationale
`bpg/proxmox` is the actively-maintained provider (the older Telmate one is effectively unmaintained). Terraform-for-provisioning + Ansible-for-configuration is the natural, widely-recognized pairing and matches the folders already present in `old_homelab/`. A golden template + cloud-init makes clones fast and identical — the exact pattern reviewers expect. Baking `node_exporter` into the baseline means observability (0008) has data the moment it turns on.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Telmate `proxmox` provider | Older docs/tutorials | Largely unmaintained; bugs | `bpg/proxmox` is the current standard |
| Pulumi | Real language, familiar | Smaller Proxmox ecosystem; less common in job posts | Terraform is the dominant hiring signal |
| Plain cloud-init, no Terraform | Simplest | No lifecycle/state; not "infra as code" | Loses the core portfolio signal |
| Remote state backend now | "Proper" from day one | Chicken-and-egg (no MinIO/Vault yet) | Start local, migrate after 0005/0007 |

## Resource budget
- **vCPU**: build-time only (template build); one throwaway test VM (~1 vCPU, transient).
- **RAM**: transient during template/test.
- **Storage**: golden template ~3–5 GB on `local-lvm`.
- **Network**: `vmbr0` for template internet access; no new bridges.

## Implementation outline
1. Repo layout: `terraform/` (providers, modules, envs) + `ansible/` (inventory, baseline role).
2. Build the cloud-init template (download cloud image, customize, convert to Proxmox template).
3. Write a reusable Terraform module: clone template → set vCPU/RAM/disk/net/cloud-init.
4. Ansible baseline role: user, SSH hardening, packages, `node_exporter`.
5. Verify: `terraform apply` one test VM, Ansible converges it, then `terraform destroy`.

## Risks & rollback
- **Provider/API auth friction.** Detection: apply fails. Mitigation: least-priv role from 0002; iterate. Rollback: none needed (no persistent state).
- **Local state loss.** Mitigation: gitignored but backed up; documented migration to a remote backend after 0005/0007.
- **Template drift.** Mitigation: template build itself scripted/documented so it's rebuildable.

## Portfolio framing
Demonstrates infrastructure-as-code provisioning with a golden-image workflow and configuration management — the core reproducibility story. Does not yet claim remote state / CI-gated plans (later follow-ups).

## Follow-ups
- [ ] Migrate Terraform state to a MinIO/Vault-backed backend after 0007/0005.
- [ ] Add CI (fmt/validate/plan) once the repo has a remote.
- [ ] Update `docs/current-state-analysis.md` when implemented.
