# 0003 — IaC Control Plane (Terraform + Golden Template + Ansible)

- **Status**: Implemented
- **Date proposed**: 2026-07-03
- **Date decided**: 2026-07-03
- **Date implemented**: 2026-07-04
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0002; precedes 0004
- **Depends on**: 0002 (Proxmox API token, storage pools)

## Context
The heart of the portfolio is reproducibility: every VM/CT must be code, not a GUI click. Nothing exists yet — this slice builds the provisioning control plane that all later layers (0004–0008) are provisioned *through*.

**Verified baseline (scanned 2026-07-03, `ssh proxmox`):** PVE **9.2.4** / kernel **7.0.14-2-pve**; storage pools `local` (dir), `local-lvm` (lvmthin, ~816 GiB, 0 % used) and `ssd-data` (lvmthin, ~233 GiB, 0 % used) all present and empty; **zero VMs/CTs**; the 0002 IaC identity is live — user `terraform@pve`, token `provider`, role `TerraformProv`, ACL propagating at `/`; single bridge `vmbr0` @ `192.168.0.113/24` (NIC `nic0`); no ISO/template cached yet; 6 cores, ~29 GiB RAM free. Everything 0003 depends on exists; this is a genuine clean slate for the control plane.

**Implementation status — DONE (2026-07-04):** executed and tester-verified end-to-end. Golden template **9000** (`debian13-cloud`, stock Debian 13, powered off) built by Terraform via `download_file` + `proxmox_virtual_environment_vm`; a reusable `modules/vm` clone module and the Ansible `baseline` role (qemu-guest-agent, `deploy` sudo/key-only user, SSH hardening, `node_exporter`) were authored and proven by creating `tf-test` (VMID 999) from code, converging it, and destroying it — DoD passed under independent re-verification. Six real defects were caught during execution and fixed rather than papered over: (1) `terraform` is delisted from `homebrew-core` — install from `hashicorp/tap` instead; (2) the pinned `cloud.debian.org` URL's geo-redirect took ~56s, exceeding Proxmox's own download timeout — repinned to a direct fast mirror in `docs/platform-conventions.md`; (3) neither the template nor the clone module had ever declared a `network_device` — guests would have had no NIC; (4) `modules/vm` needs its own `required_providers` block or Terraform mis-resolves `bpg/proxmox` as `hashicorp/proxmox`; (5) condition 2's "agent disabled at creation" is correct to avoid Terraform blocking pre-install, but the runbook never described re-enabling it afterward — fixed with a two-phase `agent_enabled` variable (disabled → Ansible installs the agent → re-`apply` with it enabled; confirmed to hot-plug with no VM reboot needed); (6) enabling the agent this way needs `VM.GuestAgent.Audit`, absent from the `TerraformProv` role minted in 0002 — added (read-only privilege, not `Unrestricted`, preserving least privilege). All fixes are reflected in the as-built Terraform/Ansible code and in `docs/platform-conventions.md`.

## Decision
Stand up the IaC control plane:
1. **Terraform** with the **`bpg/proxmox`** provider, authenticating via the `terraform@pve` token (0002), managing VM/CT lifecycle. State kept locally in the repo working tree (gitignored), with a documented path to a Vault/MinIO-backed backend later.
2. A **cloud-init golden template** built **fully in Terraform, from a vanilla upstream image** — the AMI analog: the `bpg` provider's `download_file` fetches the **Debian 13 (trixie) generic cloud image** to `local`, and a `proxmox_virtual_environment_vm` resource (`template = true`) holds it as the golden template. The image is kept **stock** — no baking; **all** in-guest customization is done by Ansible (see 3), so the template is trivially rebuildable by re-running `download_file`.
3. An **Ansible baseline role** applied to every guest post-provision and responsible for **all** customization: `qemu-guest-agent`, admin user + SSH keys, SSH hardening, base packages, `node_exporter` (ready for 0008).

Prove the slice by provisioning one throwaway VM end-to-end from code and destroying it.

## Rationale
`bpg/proxmox` is the actively-maintained provider (the older Telmate one is effectively unmaintained). Terraform-for-provisioning + Ansible-for-configuration is the natural, widely-recognized pairing and matches the folders already present in `old_homelab/`. A golden template + cloud-init makes clones fast and identical — the exact pattern reviewers expect. Putting `node_exporter` in the baseline role means observability (0008) has data the moment it turns on.

**Why build the template Terraform-native (stock image + Ansible does everything), not Packer/virt-customize:** keeping the template a *vanilla* upstream image with **zero baking** removes the "bake vs. configure" boundary entirely — there is exactly one place customization lives (the version-controlled Ansible baseline role), so there is no hidden state in a hand-built image and no drift between a baked layer and a configured layer. The whole template is a Terraform resource, so a wiped host rebuilds it with `terraform apply` and nothing else. This is the leanest fully-declarative option and the one the six later slices clone against; Packer's stronger AMI-fidelity story was weighed and set aside (below) to avoid a second tool and a duplicated customization surface this early. Packer remains an honest future follow-up if a baked-image narrative becomes worth the cost.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Telmate `proxmox` provider | Older docs/tutorials | Largely unmaintained; bugs | `bpg/proxmox` is the current standard |
| Pulumi | Real language, familiar | Smaller Proxmox ecosystem; less common in job posts | Terraform is the dominant hiring signal |
| Plain cloud-init, no Terraform | Simplest | No lifecycle/state; not "infra as code" | Loses the core portfolio signal |
| **Packer-built golden image** | Most faithful AMI analog (Packer→AMI, TF→provision); extra recognized tool on the CV | Second tool; a bake-vs-configure boundary to keep clean; customization surface duplicated with Ansible | Deferred for leanness — vanilla image + Ansible-does-all is fully declarative with one customization surface; kept as a follow-up |
| **virt-customize script** | Some baking without a new tool | Out-of-band manual step; least declarative; drift-prone | Contradicts the "everything is code" story for no real gain over Ansible |
| Remote state backend now | "Proper" from day one | Chicken-and-egg (no MinIO/Vault yet) | Start local, migrate after 0005/0007 |

## Resource budget
- **vCPU**: build-time only (template build); one throwaway test VM (~1 vCPU, transient).
- **RAM**: transient during template/test.
- **Storage**: golden template ~3–5 GB on `local-lvm`.
- **Network**: `vmbr0` for template internet access; no new bridges.

## Implementation outline
1. Repo layout: `terraform/` (providers, modules, envs) + `ansible/` (inventory, baseline role).
2. Golden template in Terraform: `download_file` fetches the stock Debian 13 cloud image to `local`; a `proxmox_virtual_environment_vm` (`template = true`) holds it as the golden template (VMID pinned in `docs/platform-conventions.md`). No image baking.
3. Write a reusable Terraform module: clone template → set vCPU/RAM/disk/net/cloud-init.
4. Ansible baseline role (all customization): `qemu-guest-agent`, `deploy` user, SSH hardening, packages, `node_exporter`.
5. Verify: `terraform apply` one throwaway test VM, Ansible baseline converges it, then `terraform destroy` leaves only the template.

## Risks & rollback
- **Provider/API auth friction.** Detection: apply fails. Mitigation: least-priv role from 0002; iterate. Rollback: none needed (no persistent state).
- **Local state loss.** Mitigation: gitignored but backed up; documented migration to a remote backend after 0005/0007.
- **Template drift.** Mitigation: template build itself scripted/documented so it's rebuildable.

## Portfolio framing
Demonstrates infrastructure-as-code provisioning with a golden-image workflow and configuration management — the core reproducibility story. Does not yet claim remote state / CI-gated plans (later follow-ups).

## Follow-ups
- [ ] Migrate Terraform state to a MinIO/Vault-backed backend after 0007/0005.
- [ ] Add CI (fmt/validate/plan) once the repo has a remote.
- [x] Update `docs/current-state-analysis.md` when implemented — done 2026-07-04.
- [ ] Cosmetic: template 9000's `ostype` defaults to `other`; consider setting `l26` explicitly.
- [ ] The `bpg/proxmox` provider deprecates `proxmox_virtual_environment_download_file`/`_vm` in favor of `proxmox_download_file`/a renamed VM resource (removed at v1.0) — migrate before then.
- [ ] The direct-mirror image URL (`saimei.ftp.acc.umu.se`) is a single third-party mirror, not the load-balanced `cloud.debian.org` — revisit if it goes stale/offline.
