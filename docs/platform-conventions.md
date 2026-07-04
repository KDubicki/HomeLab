# Platform Conventions — Pinned Values

The single source of truth for every concrete value the runbooks (`runbooks/`) use. If a runbook and this file disagree, **this file wins** — change it here, not in the runbook. Change a value here only before the slice that first uses it is Implemented.

## Host (existing, do not change)
| Item | Value |
| :--- | :--- |
| Proxmox host IP (LAN) | `192.168.0.113/24` |
| LAN gateway | `192.168.0.1` |
| LAN bridge | `vmbr0` |
| SSH alias | `ssh proxmox` (root, key `~/.ssh/id_ed25519_proxmox`) |
| Proxmox version | VE 9.2.4 (Debian 13 / trixie), kernel 7.0.14-2-pve |

## Storage pools
| Pool ID | Type | Backing | Content | Use |
| :--- | :--- | :--- | :--- | :--- |
| `local` | dir | NVMe root | iso, vztmpl, backup | ISOs, templates, dumps |
| `local-lvm` | lvmthin | NVMe | images, rootdir | OS/VM & CT root disks |
| `ssd-data` | lvmthin | 256 GB SATA SSD (`/dev/sda`) | images, rootdir | **stateful data mounts** (Vault/Postgres/MinIO) |

## Private network (created in 0004)
| Item | Value |
| :--- | :--- |
| Private bridge | `vmbr1` (no bridge-ports = no uplink) |
| Private subnet | `10.10.10.0/24` |
| Gateway (edge) | `10.10.10.1` |
| DNS for private subnet | `10.10.10.1` (dnsmasq on edge) |

## IP & ID allocation plan
| Role | Hostname | Proxmox ID | Type | Private IP | LAN IP |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Golden template | `debian13-cloud` | **9000** | template | — | — |
| Provisioning test (transient, 0003) | `tf-test` | **999** | VM | — | `192.168.0.180` (verify free before apply; destroyed at end) |
| Edge / bastion / NAT | `edge` | **101** | LXC | `10.10.10.1` | `192.168.0.10` |
| Vault | `vault` | **102** | LXC | `10.10.10.10` | — |
| k3s server | `k3s-1` | **110** | VM | `10.10.10.20` | — |
| Postgres | `pg` | **120** | LXC | `10.10.10.30` | — |
| MinIO | `minio` | **121** | LXC | `10.10.10.40` | — |

Future guests: LXC 12x, VMs 11x, keep private IPs in the matching last octet (pg=.30 → 120).

## Resource sizing (from change-log/0001 budget)
| Guest | vCPU | RAM | Root disk (`local-lvm`) | Data mount (`ssd-data`) |
| :--- | :--- | :--- | :--- | :--- |
| `edge` | 1 | 512 MB | 4 GB | — |
| `vault` | 1 | 1 GB | 8 GB | 5 GB |
| `k3s-1` | 3 | 12 GB | 60 GB | — |
| `pg` | 1 | 2 GB | 8 GB | 40 GB |
| `minio` | 1 | 2 GB | 8 GB | 120 GB |

## Accounts & credentials
| Purpose | Identity | Where the secret lives |
| :--- | :--- | :--- |
| Proxmox API for Terraform | `terraform@pve`, token id `provider`, role `TerraformProv` | gitignored `terraform/secrets.auto.tfvars` until 0005, then **Vault** |
| In-guest admin user | `deploy` (sudo, SSH key only) | key `~/.ssh/id_ed25519_proxmox` (reused) |
| Vault root/unseal | — | **offline only**, never in repo |
| Postgres app creds | dynamic, per-consumer | issued by **Vault** database engine |
| MinIO root | `minioadmin` replaced at setup | **Vault** KV `kv/minio` |
| Grafana admin | — | **Vault** KV `kv/grafana` |

## Software versions (pin at install; "stable" = latest stable at build time)
| Component | Version / channel |
| :--- | :--- |
| Guest OS (template) | Debian 13 (trixie) generic cloud image |
| Debian image source | `https://saimei.ftp.acc.umu.se/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2` (direct mirror — `cloud.debian.org`'s geo-redirect took ~56s on 2026-07-04, exceeding Proxmox's download-url read timeout; this mirror answers in <1s) → downloaded to `local` as `debian-13-genericcloud-amd64.qcow2` (content `import`; already enabled on `local` in `/etc/pve/storage.cfg`) |
| Terraform | ≥ 1.9 |
| Terraform provider | `bpg/proxmox` ≥ 0.66 |
| Ansible | ≥ 2.16 |
| node_exporter | latest stable release (pin the emitted version at install) |
| k3s | stable channel (pin the emitted version) |
| Vault | 1.17.x |
| PostgreSQL | 16 |
| MinIO | latest stable release |
| kube-prometheus-stack | latest stable chart |

## Repo layout (target)
```
HomeLab/
├── change-plan/        # ADRs (why/what)
├── runbooks/           # step-by-step execution (how)
├── docs/               # hardware, current-state, this file, diagrams
├── terraform/          # providers, modules, per-guest configs
│   ├── modules/{lxc,vm}/
│   └── *.tf, secrets.auto.tfvars (gitignored)
├── ansible/            # inventory, roles (baseline, edge, vault, k3s, pg, minio, monitoring)
└── old_homelab/        # reference only
```

## Global conventions
- **Nothing is created in the Proxmox GUI** once 0003 exists — every guest is `terraform apply`.
- Every guest gets the Ansible `baseline` role (user `deploy`, SSH hardening, `node_exporter`).
- Every runbook ends with a **Definition of Done** checklist and a **Rollback** section; do not mark a slice Implemented until DoD passes.
- Verify destructive steps (`wipefs`, `vgremove`, `terraform destroy`) against the expected output shown in the runbook before proceeding.
