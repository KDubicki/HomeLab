# Hardware Inventory — Proxmox Host

Collected via SSH on `192.168.0.113` (`ssh proxmox`). Reflects the state immediately after the July 2026 Proxmox reinstall.

## Host
| Property | Value |
| :--- | :--- |
| **Model** | Dell OptiPlex 7070 (SFF) |
| **Serial** | 90HHR33 |
| **BIOS/Firmware** | 1.34.0 (2025-06-30) |
| **OS** | Debian GNU/Linux 13 (Trixie) |
| **Hypervisor** | Proxmox VE 9.2.4 (kernel 7.0.14-2-pve) — upgraded 2026-07-03 |

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
| `sda` | Crucial/Micron MTFDDAK256TBN | 256 GB (238.5G) | **Reclaimed** → `ssd-data` lvmthin pool (see below) |

### NVMe (`nvme0n1`) — active
- `pve-root`: 96 GB (`/`) — currently 4.2G used, 85G free
- `pve-swap`: 8 GB
- `pve-data` (LVM-thin, `local-lvm`): 816 GB — **primary pool for VM/CT disks**, currently ~0.1% used (golden template 9000's disk, `change-log/0003`)

### SATA SSD (`sda`) — reclaimed as `ssd-data` (2026-07-03)
This disk originally held a **full previous Proxmox install** in VG `pve-OLD-B195BA60` (~237 GB: `root` 69 GB, `swap` 8 GB, a `data` thin pool ~141 GB, and a leftover `vm-220-disk-0`) — **not** a single stray 4 GB image, as an earlier draft of this doc incorrectly stated (scan-verified 2026-07-03). It survived the NVMe-only reinstall, unmounted and unregistered.

Reclaimed per `change-log/0002`: the old VG was removed and the disk wiped, then recreated as VG `ssd-data` with an lvmthin pool `data`, registered as Proxmox storage **`ssd-data`** (content `images,rootdir`). It is the dedicated pool for stateful data volumes (Vault/Postgres/MinIO), isolating their I/O from the NVMe OS pool.

### Proxmox storage registered today
| Storage ID | Type | Total | Used | Content |
| :--- | :--- | :--- | :--- | :--- |
| `local` | Directory (on root) | 94 GiB | 4.2 GiB | ISOs, templates, backups |
| `local-lvm` | LVM-thin | 816 GiB | 0 | VM/CT disk images |
| `ssd-data` | LVM-thin (on `sda`) | 233.5 GiB | 0 | stateful data volumes (`images,rootdir`) |

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
One object: VMID **9000** (`debian13-cloud`), the golden Debian 13 template built by Terraform in `change-log/0003` — stopped, not a running guest. `pct list` returns empty; no containers and no persistently running VMs yet.

## Sizing Guidance for Planning
With 6 vCPU / 32GB RAM / 816GB fast storage on a single node:
- No room for a multi-node HA Kubernetes cluster with real fault tolerance — a single-node **k3s** (or 1 control-plane + lightweight agents as VMs on the same host) is the realistic ceiling, positioned as "cluster architecture knowledge demonstrated," not "production HA."
- 32GB is comfortable for: k3s + observability stack (Prometheus/Grafana/Loki) + a data pipeline stack (Airflow/Dagster + Postgres + object storage) run concurrently, as long as each component's requests/limits are set deliberately.
- The 256GB SSD is now reclaimed as the `ssd-data` pool (233.5 GiB, empty) — the dedicated volume for database/object-store workloads, isolating their I/O from the OS/NVMe pool.
