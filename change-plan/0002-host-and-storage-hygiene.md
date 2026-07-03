# 0002 — Host & Storage Hygiene

- **Status**: Proposed
- **Date proposed**: 2026-07-03
- **Date decided**: —
- **Date implemented**: —
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation, umbrella); precedes 0003
- **Depends on**: none — first executable slice

## Context
Post-reinstall, the host has an orphaned 256 GB SATA SSD carrying a dead volume group `pve-OLD-B195BA60` (~237 GB, unmounted, unregistered, safe to reclaim — `docs/hardware.md`). The only admin path today is root over SSH; there is no dedicated API identity for automation. Terraform (0003) will need both a place for stateful data and a least-privilege API credential.

## Decision
Prepare the host for IaC-driven use:
1. Wipe `pve-OLD-B195BA60` and register the 256 GB SSD as a **second Proxmox storage pool dedicated to stateful data volumes** (Postgres/MinIO/Vault), keeping NVMe `local-lvm` for OS/VM disks — isolating data I/O from OS I/O.
2. Create a **non-root Proxmox API user + token** (`terraform@pve`) with a least-privilege custom role for VM/CT lifecycle, for use by the IaC control plane.
3. Baseline host hygiene: ensure the no-subscription repo, apply updates.

## Rationale
Separating data storage from the OS pool is the on-prem analog of attaching a dedicated EBS/data volume and mirrors the reason cloud DBs don't share the boot disk. A dedicated least-privilege API identity is basic cloud hygiene (an IAM user with a scoped role, not root keys) and is a prerequisite for any credible IaC story. This slice is pure prep — cheap, reversible where it matters, and unblocks everything after it.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Keep everything on NVMe `local-lvm` | One pool, simpler | Data I/O contends with OS/VM disks; wastes reclaimable SSD | Loses cheap I/O isolation |
| Use root token for Terraform | Zero setup | Over-privileged; poor portfolio hygiene | A scoped API user is the whole point |
| LVM-thin vs. directory/ext4 on the SSD | thin = snapshots/overcommit | thin adds complexity for a data volume | Decide at build time; LVM-thin likely, revisit if MinIO wants a plain FS |

## Resource budget
- **vCPU**: none (config only).
- **RAM**: none.
- **Storage**: reclaims ~238 GB SSD as a new pool (e.g. `ssd-data`). No change to `local-lvm`/`local`.
- **Network**: none.

## Implementation outline
1. Verify target: `lsblk`, `vgs`, `pvs` — confirm `pve-OLD-B195BA60` on `sda`, unmounted, unreferenced.
2. `vgremove` / `pvremove` (or `wipefs`) the old VG on `sda`.
3. Create the new pool on `sda` and register as Proxmox storage `ssd-data` (content: images/rootdir).
4. Create custom role + `terraform@pve` user + API token; record token into Vault later (0005) — until then keep it in a gitignored tfvars for 0003 bootstrap.
5. Ensure no-subscription repo; `apt update && apt full-upgrade`; reboot if kernel updated.

## Risks & rollback
- **Wiping the wrong disk.** Detection: step-1 verification. Mitigation: match by serial (`sda` = Crucial/Micron, `hardware.md`). Rollback: none needed — old VG contents are dead remnants.
- **Over/under-scoped API role.** Detection: Terraform apply fails on a missing privilege. Rollback: adjust role; low-risk, reversible.

## Portfolio framing
Demonstrates deliberate storage tiering and least-privilege API access on the hypervisor — the on-prem equivalents of dedicated data volumes and scoped IAM credentials. Does not claim redundancy: the SSD is a single disk, no RAID.

## Follow-ups
- [ ] Migrate the `terraform@pve` token into Vault once 0005 lands.
- [ ] Update `docs/current-state-analysis.md` and `docs/hardware.md` (storage table) when implemented.
