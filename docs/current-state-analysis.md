# Current State Analysis — Project Reboot (2026-07-03)

## Context
This repository previously documented a working homelab: Proxmox host, a WireGuard VPN gateway container, a CoreDNS service-discovery container, and an Uptime Kuma monitoring container, all on an isolated `10.10.0.0/24` lab network behind a second bridge (`vmbr1`).

The Proxmox host was reinstalled. All VMs/containers, the `vmbr1` lab network, and the associated configuration are gone — the host is a genuine clean slate (see [hardware.md](hardware.md)). All prior repo content (docs, scripts, IaC placeholders) has been moved to `old_homelab/` for reference; it should be treated as **historical/design reference only**, not as current state.

This reboot reframes the project's purpose: previously an ad-hoc self-hosting setup, it is now being deliberately designed as a **long-term DevOps + Data Engineering portfolio project** — something to demonstrate real infrastructure and data platform skills to employers, built and documented incrementally.

## What exists right now
- **Proxmox VE 9.2.4** (kernel 7.0.14-2-pve) on a Dell OptiPlex 7070 (i5-9600, 32GB RAM, 1TB NVMe `local-lvm` + 256GB SSD reclaimed as `ssd-data`) — full detail in [hardware.md](hardware.md).
- **Network**: single 1GbE NIC. `vmbr0` (`192.168.0.113/24`) plus a private-subnet bridge `vmbr1` (change-log/0004, 2026-07-04): no bridge-ports (no LAN uplink), `10.10.10.0/24`, gatewayed by an LXC `edge` (VMID 101, dual-homed `192.168.0.10`/`10.10.10.1`) running NAT + SSH bastion + DHCP/DNS for the private side. A static DNS record `vault.lab.internal` → `10.10.10.10` was added to edge's dnsmasq in change-log/0005.
- **Access**: SSH key-based root login configured (dedicated key `~/.ssh/id_ed25519_proxmox`, `ssh proxmox` alias) — see [proxmox-ssh-access.md](../proxmox-ssh-access.md). **Operational note (change-log/0005)**: the `baseline` role's SSH hardening disables root login on *every* LXC guest after its first Ansible run, not just `edge`'s — all subsequent access (Ansible re-runs, manual admin) uses `deploy` + `sudo`; this OpenSSH client build (10.2p1) also doesn't propagate `-i` across a `ProxyJump` hop with no agent key loaded, so jumps through `edge` use an explicit `ProxyCommand` instead.
- **Two persistently running workloads**: `edge` (LXC 101, change-log/0004) — the private-subnet NAT gateway/bastion/DHCP-DNS; `vault` (LXC 102, change-log/0005) — a single-node HashiCorp Vault, private-subnet only, TLS + Raft storage on `ssd-data`. Template 9000 remains stopped (a template, not a running guest); no other VMs/containers run continuously yet.
- **Storage reclaimed** (change-log/0002, 2026-07-03): the legacy 256 GB SSD — which actually held a *full* old Proxmox install, not a stray image — was wiped and is now the `ssd-data` lvmthin pool (233.5 GiB, empty). `local-lvm` (816 GiB) and `local` unchanged.
- **IaC identity** (change-log/0002, done; extended change-log/0003): Proxmox API user `terraform@pve` + token `provider` + role `TerraformProv` (22 PVE-9 privileges, including `VM.GuestAgent.Audit` added in 0003) + ACL at `/`. Host `full-upgrade`d to **PVE 9.2.4**, running kernel **7.0.14-2-pve**.
- **IaC control plane live** (change-log/0003, done 2026-07-04): Terraform (`bpg/proxmox`) + Ansible, both installed on the workstation. Golden template **9000** (`debian13-cloud`, stock Debian 13, powered off) on `local-lvm`; reusable `terraform/modules/vm` clone module; Ansible `baseline` role (`ansible/roles/baseline`) applies qemu-guest-agent (VM guests only, see below), the `deploy` sudo/key-only user, SSH hardening, and `node_exporter` to every guest. Proven end-to-end with a throwaway VM, then destroyed. State/secrets stay in gitignored `terraform/*.tfstate` / `terraform/secrets.auto.tfvars` until Vault (0005).
- **Private-subnet network live** (change-log/0004, done 2026-07-04): bridge `vmbr1` (no bridge-ports, `10.10.10.0/24`) and an unprivileged LXC `edge` (VMID 101, dual-homed `192.168.0.10`/`10.10.10.1`), provisioned via a new `terraform/modules/lxc` module. `edge` runs IP forwarding + an nftables ruleset (default-deny inbound, NAT egress) + dnsmasq (DHCP `10.10.10.100`–`.200`, DNS) via a new Ansible `edge` role. Proven with a throwaway DHCP client on the private subnet: internet egress only via `edge`'s NAT, DNS via `edge`, unreachable from the LAN except through the bastion (`ssh -J deploy@192.168.0.10 ...`) — then destroyed. The `baseline` role now guards `qemu-guest-agent` behind `ansible_virtualization_type != 'lxc'`, a real compatibility fix (the agent is meaningless in a container) that every future LXC guest (0005 Vault, 0007 Postgres/MinIO) relies on.
- **Secrets management live** (change-log/0005, done 2026-07-05): a single-node HashiCorp Vault **1.17.6** (LXC 102, `10.10.10.10`, private-subnet only, TLS, integrated Raft storage on `ssd-data`), provisioned via a `data_disk` addition to `terraform/modules/lxc` and a new Ansible `vault` role. `kv/` (KV v2) and `database/` (mount only, connected in 0007) secrets engines are enabled; a least-privilege `terraform` AppRole (read-only on `kv/data/proxmox/*`) replaced the root token for routine use. The `terraform@pve` Proxmox API token now lives in Vault (`kv/proxmox/terraform`) — `terraform/secrets.tf` reads it via a `vault_kv_secret_v2` data source over an SSH-tunneled connection, proven with a live `terraform plan` reporting no changes. Root tokens are not kept standing: minted on demand via `vault operator generate-root` from the unseal keys, then revoked after use.
- **This git repository**, reset to a near-empty state with the previous work preserved under `old_homelab/`.

## Constraints this design has to respect
- **Single node, no HA**: 6 vCPU / 32GB RAM is enough for a meaningful k3s + data-platform stack running concurrently, but not for real fault-tolerant clustering. Any "cluster" work here demonstrates the pattern, not production resilience — that should be stated honestly in the portfolio framing rather than overclaimed.
- **No dedicated GPU**: rules out GPU-accelerated ML as a component; data engineering work should lean on CPU-based tools (e.g. DuckDB, Polars, Spark local mode) rather than needing GPU acceleration.
- **One physical NIC**: any network segmentation (e.g. isolating a "lab" subnet from the host's LAN-facing IP, as the old setup did with `vmbr1`) will need VLAN tagging or a second no-uplink bridge on the same NIC, not a second physical interface.
- **Reclaimable storage** (DONE 2026-07-03): the old SATA SSD's LVM volume group (`pve-OLD-B195BA60`, a full previous install) has been wiped and repurposed as the `ssd-data` lvmthin pool — dedicated to database/object-storage I/O, isolated from the NVMe pool.

## Open decisions before the build phase
These need to be settled (with you) before writing any Terraform/Ansible/Kubernetes manifests, since they shape the repo structure itself:
1. **Container orchestration**: k3s (stronger portfolio signal, more operational complexity) vs. Docker Compose/Swarm (simpler, faster to demo, less impressive to a DevOps-focused reviewer).
2. ~~**IaC toolchain**~~ — **settled** (`change-log/0003`): Terraform (`bpg/proxmox`) for provisioning + Ansible for in-guest configuration, live and proven end-to-end.
3. **Data engineering component scope**: what pipeline is being demonstrated — batch ETL (Airflow/Dagster + Postgres + dbt), streaming (Kafka/Redpanda + a stream processor), or both in sequence as the project matures? This has real RAM/CPU budget implications on a 6-core/32GB box.
4. ~~**Network segmentation**~~ — **settled** (`change-log/0004`): a no-uplink bridge (`vmbr1`, `10.10.10.0/24`) with an LXC `edge` as NAT gateway/bastion/DHCP-DNS, live and proven end-to-end.
5. **Observability**: Uptime Kuma was the old approach (simple uptime checks). A DevOps portfolio piece typically favors Prometheus + Grafana (+ Loki for logs) to demonstrate metrics/alerting depth — worth deciding now since it affects the resource budget.

## Repository state after this reboot
```
HomeLab/
├── docs/
│   ├── hardware.md                 — hardware inventory (this analysis's source data)
│   └── current-state-analysis.md   — this file
├── proxmox-ssh-access.md           — SSH key setup guide
├── old_homelab/                    — previous project, kept for reference
│   ├── README.md
│   ├── ansible/
│   ├── bash/
│   ├── docs/
│   ├── kubernetes/
│   └── terraform/
├── .gitignore
└── .claude/
```
No new IaC or application code has been written yet — this commit is documentation-only, establishing the baseline before architecture decisions are locked in.
