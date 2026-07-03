# Hardware Inventory — Proxmox Host

Collected via SSH on `192.168.0.113` (`ssh proxmox`). Reflects the state immediately after the July 2026 Proxmox reinstall.

## Host
| Property | Value |
| :--- | :--- |
| **Model** | Dell OptiPlex 7070 (SFF) |
| **Serial** | 90HHR33 |
| **BIOS/Firmware** | 1.34.0 (2025-06-30) |
| **OS** | Debian GNU/Linux 13 (Trixie) |
| **Hypervisor** | Proxmox VE 9.2.2 (kernel 7.0.2-6-pve) |

## CPU
| Property | Value |
| :--- | :--- |
| **Model** | Intel Core i5-9600 @ 3.10GHz (boost 4.6GHz) |
| **Cores / Threads** | 6 cores / 6 threads (no Hyper-Threading) |
| **Virtualization** | VT-x supported and enabled |
| **Cache** | L1 192KiB / L2 1.5MiB / L3 9MiB |

**Implication**: no SMT means 6 logical CPUs is the hard ceiling. Plan VM/CT vCPU allocation conservatively — oversubscription will cause contention faster than on an HT-enabled chip.

## Memory
| Property | Value |
| :--- | :--- |
| **Total** | 32 GiB (31Gi usable) |
| **Swap** | 8 GiB |

## Storage
Two physical drives, currently asymmetric in role:

| Device | Model | Capacity | Role |
| :--- | :--- | :--- | :--- |
| `nvme0n1` | Lexar NM790 | 1 TB (952.9G partition) | **Primary** — fresh Proxmox install lives here |
| `sda` | Crucial/Micron MTFDDAK256TBN | 256 GB (238.5G) | **Legacy/orphaned** — see below |

### NVMe (`nvme0n1`) — active
- `pve-root`: 96 GB (`/`) — currently 4.2G used, 85G free
- `pve-swap`: 8 GB
- `pve-data` (LVM-thin, `local-lvm`): 816 GB — **primary pool for VM/CT disks**, currently 0% used

### SATA SSD (`sda`) — orphaned from previous install
Volume group `pve-OLD-B195BA60` (~237 GB) survived the reinstall untouched because only the NVMe was reimaged. It still contains a leftover disk image (`vm-220-disk-0`, 4G) from the old `dns-node` container. **This VG is not mounted, not registered as Proxmox storage, and safe to reclaim.**

**Action needed**: wipe `pve-OLD-B195BA60` and either (a) re-register the 256GB SSD as a second Proxmox storage pool (e.g. for backups/ISOs/templates, keeping fast NVMe free for VM I/O), or (b) repurpose it as dedicated storage for a data-engineering workload (e.g. a Postgres/MinIO data volume separate from OS disk contention).

### Proxmox storage registered today
| Storage ID | Type | Total | Used | Content |
| :--- | :--- | :--- | :--- | :--- |
| `local` | Directory (on root) | 94 GiB | 4.2 GiB | ISOs, templates, backups |
| `local-lvm` | LVM-thin | 816 GiB | 0 | VM/CT disk images |

## Network
| Property | Value |
| :--- | :--- |
| **NIC** | Single 1GbE onboard (`nic0` / `enp0s31f6`) |
| **Bridge** | `vmbr0` → `192.168.0.113/24`, gateway `192.168.0.1` |
| **Link speed** | 1000 Mb/s |

**Note**: only one physical NIC and one bridge exist post-reinstall. The previous setup's `vmbr1` (isolated `10.10.0.0/24` lab network) is gone — any internal/lab network segmentation will need to be rebuilt, either as a second bridge on the same NIC (VLAN-tagged) or via a Linux bridge with no physical port (as before), since there is no second physical NIC available.

## GPU
- Integrated Intel UHD Graphics 630 (CoffeeLake-S GT2)
- No discrete GPU. Sufficient for hardware video transcode (e.g. Jellyfin/Plex via iGPU passthrough) but **not usable for GPU-accelerated ML/data workloads**. Any "big data" or ML component in the portfolio should be scoped to CPU-based tools (Spark local mode, DuckDB, pandas/Polars) rather than GPU-dependent frameworks.

## Current VM/CT Inventory
**None.** `qm list` and `pct list` both return empty — this is a genuinely clean slate post-reinstall.

## Sizing Guidance for Planning
With 6 vCPU / 32GB RAM / 816GB fast storage on a single node:
- No room for a multi-node HA Kubernetes cluster with real fault tolerance — a single-node **k3s** (or 1 control-plane + lightweight agents as VMs on the same host) is the realistic ceiling, positioned as "cluster architecture knowledge demonstrated," not "production HA."
- 32GB is comfortable for: k3s + observability stack (Prometheus/Grafana/Loki) + a data pipeline stack (Airflow/Dagster + Postgres + object storage) run concurrently, as long as each component's requests/limits are set deliberately.
- The orphaned 256GB SSD, once reclaimed, is well-suited as a dedicated volume for a database or object-store workload, isolating its I/O from the OS/NVMe pool.
