# Current State Analysis — Project Reboot (2026-07-03)

## Context
This repository previously documented a working homelab: Proxmox host, a WireGuard VPN gateway container, a CoreDNS service-discovery container, and an Uptime Kuma monitoring container, all on an isolated `10.10.0.0/24` lab network behind a second bridge (`vmbr1`).

The Proxmox host was reinstalled. All VMs/containers, the `vmbr1` lab network, and the associated configuration are gone — the host is a genuine clean slate (see [hardware.md](hardware.md)). All prior repo content (docs, scripts, IaC placeholders) has been moved to `old_homelab/` for reference; it should be treated as **historical/design reference only**, not as current state.

This reboot reframes the project's purpose: previously an ad-hoc self-hosting setup, it is now being deliberately designed as a **long-term DevOps + Data Engineering portfolio project** — something to demonstrate real infrastructure and data platform skills to employers, built and documented incrementally.

## What exists right now
- **Proxmox VE 9.2.2** on a Dell OptiPlex 7070 (i5-9600, 32GB RAM, 1TB NVMe + orphaned 256GB SSD) — full detail in [hardware.md](hardware.md).
- **Network**: single 1GbE NIC, single bridge `vmbr0` on `192.168.0.113/24`. No internal/lab network segment exists yet.
- **Access**: SSH key-based root login configured (dedicated key `~/.ssh/id_ed25519_proxmox`, `ssh proxmox` alias) — see [proxmox-ssh-access.md](../proxmox-ssh-access.md).
- **Zero running workloads.** No VMs, no containers, no services.
- **This git repository**, reset to a near-empty state with the previous work preserved under `old_homelab/`.

## Constraints this design has to respect
- **Single node, no HA**: 6 vCPU / 32GB RAM is enough for a meaningful k3s + data-platform stack running concurrently, but not for real fault-tolerant clustering. Any "cluster" work here demonstrates the pattern, not production resilience — that should be stated honestly in the portfolio framing rather than overclaimed.
- **No dedicated GPU**: rules out GPU-accelerated ML as a component; data engineering work should lean on CPU-based tools (e.g. DuckDB, Polars, Spark local mode) rather than needing GPU acceleration.
- **One physical NIC**: any network segmentation (e.g. isolating a "lab" subnet from the host's LAN-facing IP, as the old setup did with `vmbr1`) will need VLAN tagging or a second no-uplink bridge on the same NIC, not a second physical interface.
- **Reclaimable storage**: the old SATA SSD's leftover LVM volume group (`pve-OLD-B195BA60`, ~237GB) is unused and should be wiped and repurposed — good candidate for isolating database/object-storage I/O away from the NVMe pool.

## Open decisions before the build phase
These need to be settled (with you) before writing any Terraform/Ansible/Kubernetes manifests, since they shape the repo structure itself:
1. **Container orchestration**: k3s (stronger portfolio signal, more operational complexity) vs. Docker Compose/Swarm (simpler, faster to demo, less impressive to a DevOps-focused reviewer).
2. **IaC toolchain**: Terraform for Proxmox provisioning (VM/CT lifecycle) + Ansible for in-guest configuration is the natural pairing given the `terraform/` and `ansible/` folders already present in `old_homelab/` — confirm we're keeping that pairing rather than switching to e.g. Pulumi or plain cloud-init.
3. **Data engineering component scope**: what pipeline is being demonstrated — batch ETL (Airflow/Dagster + Postgres + dbt), streaming (Kafka/Redpanda + a stream processor), or both in sequence as the project matures? This has real RAM/CPU budget implications on a 6-core/32GB box.
4. **Network segmentation**: rebuild an isolated lab subnet (as before) or run everything flatter on `vmbr0` with firewall rules for isolation instead?
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
