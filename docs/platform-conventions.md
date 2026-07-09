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
| DHCP range (private subnet) | `10.10.10.100`–`10.10.10.200` (below `.100` is reserved for statically-assigned guests) |
| Static DNS records (dnsmasq on edge) | `vault.lab.internal` → `10.10.10.10` (added in 0005); `pg.lab.internal` → `10.10.10.30`, `minio.lab.internal` → `10.10.10.40` (allocated for 0007); future guests append one `address=` line each |

## IP & ID allocation plan
| Role | Hostname | Proxmox ID | Type | Private IP | LAN IP |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Golden template | `debian13-cloud` | **9000** | template | — | — |
| Provisioning test (transient, 0003) | `tf-test` | **999** | VM | — | `192.168.0.180` (verify free before apply; destroyed at end) |
| Private-subnet test (transient, 0004) | `priv-test` | **998** | VM | `10.10.10.x` (DHCP) | — (no LAN NIC — reached only via `edge`; destroyed at end) |
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
| k3s → Vault reviewer identity | k8s ServiceAccount `vault-auth` (namespace `default`) bound to `system:auth-delegator`; its token is Vault's `auth/kubernetes/config` `token_reviewer_jwt` | JWT held only in Vault's auth config, never written to the repo; issued via `kubectl create token` (long-duration, manual renewal — see change-plan/0006 follow-ups) |
| k3s sample workload secret | demo value, consumed by the Vault Agent Injector | **Vault** KV `kv/k3s/sample` |
| Postgres Vault-management superuser | `vaultadmin` (used only by Vault's `database/` engine to create/drop dynamic roles) | password generated at setup, written straight into `database/config/postgresql` by the operator's own Vault CLI session — never in the repo |
| k3s → Vault consumer identity (Postgres) | k8s ServiceAccount `pg-client` (namespace `default`) bound to Vault k8s-auth role `k3s-pg`, policy `pg-read` (`database/creds/app`, read) | reuses the `kubernetes` auth method configured in 0006; no new reviewer identity needed |
| k3s → Vault consumer identity (MinIO) | k8s ServiceAccount `minio-client` (namespace `default`) bound to Vault k8s-auth role `k3s-minio`, policy `minio-read` (`kv/data/minio`, read) | reuses the `kubernetes` auth method configured in 0006 |

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
| Helm | latest stable release (pin the emitted version at install) |
| `vault-k8s` (Helm chart, injector only — `server.enabled=false`) | latest stable chart from the `hashicorp` Helm repo |
| Vault | 1.17.6 (OSS), `vault_1.17.6_linux_amd64.zip`, sha256 `0cddc1fbbb88583b5ba5b845f9f8fae47c6fb39a6d48cd543c6ba6fd3ac1a669` |
| PostgreSQL | 17 (corrected from the originally-planned 16 for 0007: Debian 13 trixie's native `postgresql` package resolves to `17+278` — using the native repo avoids adding the third-party PGDG apt repo just to pin an older major version) |
| MinIO | `RELEASE.2025-09-07T16-13-09Z` (pinned at 0007 authoring time — latest stable as of 2026-07-09), sha256 `7c5bd8512c6e966455b1d198209358b2d191c77a83ab377c4073281065fb855f` |
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
