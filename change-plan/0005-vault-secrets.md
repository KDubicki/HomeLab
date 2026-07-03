# 0005 — Secrets Management with HashiCorp Vault

- **Status**: Proposed
- **Date proposed**: 2026-07-03
- **Date decided**: —
- **Date implemented**: —
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0003, 0004; precedes 0006/0007
- **Depends on**: 0003 (provisioning), 0004 (lives on the private subnet)

## Context
Layers after this (k3s, Postgres, MinIO, Grafana) all carry credentials. The owner chose **HashiCorp Vault** as the secrets manager. It is sequenced **before** those workloads so credentials are issued and stored properly from the start, rather than scattered in tfvars/env and migrated later.

## Decision
Run a **single-node HashiCorp Vault** (integrated Raft storage) on the private subnet (0004), TLS-enabled, data on the `ssd-data` pool (0002):
1. Enable the **KV v2** engine for static secrets and the **database** secrets engine for dynamic Postgres credentials (0007).
2. Define **policies** and per-consumer auth (AppRole / token) for Terraform, Ansible, and services.
3. Migrate the `terraform@pve` API token (0002) into Vault; wire Terraform/Ansible to read from Vault instead of gitignored files.

Unseal: manual (or transit auto-unseal via a small second Vault) — documented honestly as a single-node, non-HA deployment.

## Rationale
Vault demonstrates a real secrets workflow — policies, leasing, dynamic DB credentials — which is a stronger hiring signal than static encrypted files (SOPS/age). Standing it up before the credentialed workloads avoids the anti-pattern of secrets sprawl followed by a painful migration. Dynamic Postgres credentials (short-lived, per-consumer) are a headline capability worth showing.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| SOPS + age | Simple, gitops-native | Static only; less to demonstrate | Owner chose Vault |
| Vault last (layer 7) | Matches original layering | Secrets sprawl before it exists; migration churn | Moved earlier by design |
| Cloud KMS auto-unseal | Hands-off unseal | Requires a cloud dependency | Keep it self-contained; manual/transit unseal |
| Vault HA cluster | Production-like | No spare RAM/nodes; overkill single-host | Single node, framed honestly |

## Resource budget
- **vCPU**: Vault CT ~1 (idle-heavy).
- **RAM**: ~1 GB.
- **Storage**: Raft data on `ssd-data` (small); rootfs ~4 GB on `local-lvm`.
- **Network**: private subnet (`vmbr1`); reachable by Terraform/Ansible via the bastion.

## Implementation outline
1. Terraform: provision the Vault CT/VM on the private subnet, data disk on `ssd-data`.
2. Ansible: install Vault, TLS, Raft storage, systemd; `vault operator init`, store unseal/root safely offline.
3. Enable KV v2 + database engines; write policies + AppRole for Terraform/Ansible/services.
4. Migrate the Proxmox token; cut Terraform/Ansible over to Vault-sourced secrets.
5. Verify: Terraform reads the Proxmox token from Vault; a dynamic Postgres cred is issued (after 0007) and expires.

## Risks & rollback
- **Lost unseal keys / root token = data loss.** Mitigation: store keys offline, out of the repo; document recovery. This is the single highest-stakes item — treat accordingly.
- **Seal on reboot blocks automation.** Detection: services fail to fetch secrets after a host reboot. Mitigation: document/automate unseal (transit) so recovery is quick.
- **Bootstrap ordering.** Until cutover, 0003 uses a gitignored token; rollback is simply keeping that file until Vault is verified.

## Portfolio framing
Demonstrates centralized secrets management with policies and dynamic database credentials — real Vault operations. Explicitly a single-node, manually/transit-unsealed deployment: demonstrates the workflow, not HA secret infrastructure.

## Follow-ups
- [ ] Add Vault Agent / CSI to inject secrets into k3s workloads (after 0006).
- [ ] Consider MinIO-backed Terraform state encrypted via Vault transit.
- [ ] Update `docs/current-state-analysis.md` when implemented.
