# 0005 — Secrets Management with HashiCorp Vault

- **Status**: Implemented
- **Date proposed**: 2026-07-03
- **Date decided**: 2026-07-05
- **Date implemented**: 2026-07-05
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0003, 0004; precedes 0006/0007
- **Depends on**: 0003 (provisioning), 0004 (lives on the private subnet)

## Context
Layers after this (k3s, Postgres, MinIO, Grafana) all carry credentials. The owner chose **HashiCorp Vault** as the secrets manager. It is sequenced **before** those workloads so credentials are issued and stored properly from the start, rather than scattered in tfvars/env and migrated later.

**Implementation status — DONE (2026-07-05):** executed and tester-verified end-to-end. A single-node HashiCorp Vault **1.17.6** (LXC, VMID **102**, private-subnet only — no LAN NIC) runs TLS-enabled with integrated Raft storage on `ssd-data` (5 GB data mount, distinct from its 8 GB rootfs on `local-lvm`), provisioned via a new `terraform/modules/lxc` `data_disk` mount_point and a new Ansible `vault` role. `kv/` (KV v2) and `database/` (mount only — connection deferred to 0007, once Postgres exists) are enabled. A least-privilege `terraform` AppRole (read-only on `kv/data/proxmox/*`, 30m/2h token TTLs, 90-day secret_id) replaced the root token for routine use; the `terraform@pve` Proxmox API token now lives in Vault (`kv/proxmox/terraform`), and `terraform/secrets.tf` wires the `proxmox` provider to read it via `data.vault_kv_secret_v2` over an SSH-tunneled connection — proven with a live `terraform plan` reporting "No changes" through the AppRole. Root tokens are not kept standing: `vault operator generate-root` mints one on demand from the unseal keys, used, then revoked (`vault token revoke -self`).

Several real defects were caught and fixed during execution rather than papered over: (1) stale `terraform/test.tf`/`test-private.tf` from 0003/0004 would have resurrected two already-destroyed throwaway VMs on the next `apply` — deleted; (2) the `baseline` role's SSH hardening (from 0004) disables root login on **every** LXC guest after its first Ansible run, not just `edge` — `vault`'s own first run hit the same wall, and this OpenSSH client build (10.2p1) additionally doesn't propagate `-i` across a `ProxyJump` hop with no agent key loaded, so all post-bootstrap access uses `deploy` + `sudo` over an explicit `ProxyCommand`; (3) the runbook's Vault AppRole API paths were wrong (`auth/approle/role-id/terraform` instead of `auth/approle/role/terraform/role-id`) — fixed; (4) the AppRole's `secret_id_ttl` was silently capped at Vault's 32-day system default instead of the intended 90 days — fixed with `vault auth tune -max-lease-ttl`; (5) Terraform only allows one `required_providers` block per module — the `vault` provider requirement was merged into the existing `versions.tf`; (6) the Vault provider's default ephemeral child-token creation needs `auth/token/create`, which the least-privilege policy intentionally withholds — fixed with `skip_child_token = true` rather than widening the policy. One incident, handled transparently: the operator lost the original root token mid-session and it was regenerated via `generate-root`; the regenerated token was then inadvertently pasted into the assistant conversation to unblock troubleshooting — it was revoked immediately once setup completed, and rotating the `terraform@pve` Proxmox token (also read via tool calls during the KV migration) is carried as a follow-up below.

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
- [x] Update `docs/current-state-analysis.md` when implemented — done 2026-07-05.
- [ ] Rotate the `terraform@pve` Proxmox token (its value passed through tool calls during the KV migration and verification — low risk on this single-node dev host, but cheap to rotate: `pveum user token` remove/add, then `vault kv put kv/proxmox/terraform` with the new value).
- [ ] Consider a repo-wide fix for the `ansible_user=deploy` + `ProxyCommand` SSH pattern discovered on `edge`/`vault` (document in `docs/platform-conventions.md` as the standard for every future LXC guest, so 0007's `pg`/`minio` don't rediscover it).
