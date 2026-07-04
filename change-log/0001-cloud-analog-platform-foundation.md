# 0001 — Cloud-Analog Platform Foundation

- **Status**: Accepted <!-- Proposed | Accepted | Implemented | Rejected | Superseded by NNNN -->
- **Date proposed**: 2026-07-03
- **Date decided**: 2026-07-03
- **Date implemented**: —
- **Owner**: KDubicki
- **Related plans**: 0002 (host/storage), 0003 (IaC control plane), 0004 (network), 0005 (Vault), 0006 (k3s), 0007 (managed services), 0008 (observability)
- **Scope of this document**: this is the **foundational architecture decision (ADR)** — the *shape and the why*. It is **not** the roadmap: the live roadmap, execution order, and per-slice status are owned by `change-plan/plan.md`. Read that first for "where are we"; read this for "why is it built this way".

## Context
The Proxmox host was reinstalled and is a genuine clean slate: zero VMs/containers, a single `vmbr0` bridge on `192.168.0.113/24`, 6 vCPU / 32 GB RAM / 816 GB NVMe (`local-lvm`) + a reclaimable 256 GB SATA SSD, no dGPU (see `docs/hardware.md` and `docs/current-state-analysis.md`).

The project has been deliberately reframed as a **long-term DevOps + Data Engineering portfolio**. Before any workload is built, the "base" needs a definition: what constitutes a *complete, ready* platform floor on top of which data-engineering work begins. This plan settles that definition and the single most load-bearing architectural choice — the orchestration and service topology — so that repo structure (Terraform/Ansible/k8s manifests) can be laid down coherently.

The explicit design intent, stated by the owner, is to **replicate a public-cloud environment as faithfully as possible on a single bare-metal node**, so the portfolio demonstrates cloud-native architecture patterns rather than ad-hoc self-hosting.

## Decision
Adopt a **cloud-analog platform architecture** as the base, with a strict separation between a **compute tier** and a **managed-services tier**. This foundation plan is **split into seven independently-executed change plans (0002–0008)**; this document is the **foundational decision** they trace back to. Their live status and the tracked roadmap live in `change-plan/plan.md`, not here.

The layers:
1. **Host & storage hygiene** (→ 0002) — reclaim the orphaned 256 GB SSD (`pve-OLD-B195BA60`) as a second Proxmox pool dedicated to stateful data volumes; create a dedicated non-root Proxmox API user + token for IaC.
2. **IaC control plane** (→ 0003) — Terraform (`bpg/proxmox`) drives all VM/CT lifecycle; a cloud-init **golden template** is the cloneable base image; Ansible applies in-guest baseline config. Nothing is provisioned by hand in the GUI.
3. **Network as a private VPC analog** (→ 0004) — an internal, **no-uplink** Linux bridge is the private subnet; a small edge VM/CT is NAT gateway + bastion; `vmbr0` stays the LAN-facing edge. **No VLANs** — confirmed there is no managed switch on the LAN.
4. **Secrets — HashiCorp Vault** (→ 0005) — Vault is the Secrets Manager analog; Terraform/Ansible and all services read credentials from it. Stood up **early** (before workloads accrue credentials), not last.
5. **Compute tier — k3s on a dedicated VM** (→ 0006) — the managed-Kubernetes (EKS) analog; application and pipeline workloads run here.
6. **Managed-services tier** (→ 0007) — **Postgres** and **MinIO** in **separate LXC containers outside the cluster** (RDS / S3 analogs), data volumes on the reclaimed 256 GB SSD.
7. **Observability skeleton** (→ 0008) — Prometheus + Grafana + Loki in-cluster (`monitoring` namespace), the CloudWatch analog, stood up **before** data workloads so everything is observed from day one.

The base is **complete** when all seven plans reach Implemented. Only then does data-engineering work (Airflow/Dagster + dbt on the Postgres/MinIO tier) begin — that is a *workload on the base*, not part of the base, and will be its own plan.

**Recommended execution order** (= plan numbering): 0002 → 0003 → 0004 → 0005 (Vault) → 0006 (k3s) → 0007 (managed services) → 0008 (observability). Vault precedes the credentialed workloads deliberately.

## Rationale
- **Serves the portfolio intent, not just "make it run."** The compute/managed-services split is the clearest cloud-native signal a reviewer looks for: you don't run your database inside your Kubernetes cluster. Mapping each component to a named cloud primitive turns a homelab into a legible "I modeled a VPC + managed services on bare metal" narrative.
- **k3s over Compose/Nomad** — the owner's explicit choice: strongest DevOps hiring signal, real Helm/manifest/GitOps surface, acceptable single-node cost. Honestly framed as *cluster architecture demonstrated*, not production HA.
- **Vault over file-based secrets (SOPS/age)** — the owner's explicit choice: demonstrates a real secrets-management workflow (dynamic secrets, leasing, policies) instead of static encrypted files; the higher-value skill to show.
- **IaC-first from day zero** — the whole platform reproducible from a wiped host: the highest-value thing a DevOps portfolio can prove.
- **Observability before workloads** mirrors real platform engineering.
- **Fits the hardware envelope** — the entire base fits inside 6 vCPU / 32 GB with ~11.5 GB headroom for the first data workload.

**Cloud-primitive mapping (portfolio narrative):**

| Cloud primitive | Homelab realization |
| :--- | :--- |
| Terraform vs. cloud API + IAM keys | Terraform `bpg/proxmox` vs. Proxmox API token (dedicated non-root user) |
| AMI / golden image | cloud-init template cloned by Terraform |
| VPC / private subnet | internal no-uplink bridge |
| Bastion / NAT gateway | edge VM/CT |
| Secrets Manager | HashiCorp Vault |
| EKS (managed k8s) | k3s on a dedicated VM |
| RDS (managed Postgres) | Postgres in a separate LXC |
| S3 (object storage) | MinIO in a separate LXC |
| CloudWatch / managed Prometheus | Prometheus + Grafana + Loki in-cluster |

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Docker/Podman Compose as base | Simplest, fastest demo | Weak DevOps signal; no orchestration story | Owner wants max cloud fidelity; k3s chosen |
| Nomad + Consul | Lighter than k8s | Smaller ecosystem; less interview demand | Kubernetes is the dominant hiring signal |
| Postgres/MinIO inside k3s | Fewer moving parts | Contradicts cloud best practice; couples data durability to cluster lifecycle | Defeats the compute/managed-services separation that is the point |
| SOPS + age for secrets | Simple, gitops-friendly | Static secrets only; less to demonstrate | Owner chose Vault for the richer skill signal |
| Flat network on `vmbr0` | Simplest | No VPC/subnet analog | Cloud-fidelity intent favors an explicit private subnet |
| VLAN-tagged segments | Most "enterprise" | Requires a managed switch | **Confirmed no managed switch on the LAN** — not possible |

## Resource budget
Indicative steady-state (limits set per component; oversubscription of 6 logical CPUs acceptable at rest but watched):
- **vCPU**: k3s VM 3 · Postgres CT 1 · MinIO CT 1 · edge CT 1 · Vault CT 1 → ~7 nominal, bursty (edge/Vault/DB mostly idle). Acceptable on 6c/6t with contention awareness.
- **RAM**: host ~2 GB · k3s VM ~12 GB (incl. `monitoring`) · Postgres ~2 GB · MinIO ~2 GB · edge ~0.5 GB · Vault ~1 GB → **~19.5 GB of 31 usable**, ~11.5 GB headroom for the first data workload.
- **Storage**: k3s VM + OS on `local-lvm` (NVMe); Postgres/MinIO/Vault data on the **reclaimed 256 GB SSD**; templates/ISOs/backups on `local`.
- **Network**: `vmbr0` (edge) + one new internal no-uplink bridge (private subnet). No new physical ports, no VLANs.

## Implementation outline
Each layer is a separate plan (0002–0008); see those for detailed slices. This plan's job is only to fix the shape and order above.

## Risks & rollback
- **RAM pressure once the data tier lands.** Mitigation: strict requests/limits; ~11.5 GB headroom; the data-workload plan must budget within it. Detection: Grafana memory + OOM alerts.
- **Storage reclaim wipes the wrong volume.** Mitigation: `pve-OLD-B195BA60` confirmed unmounted/unregistered; verify `lsblk`/`vgs` before `vgremove` (detailed in 0002).
- **Single-node reality.** Nothing here is fault-tolerant. Accepted; stated honestly in framing, never overclaimed as HA.
- **CPU contention on 6c/6t.** Mitigation: keep vCPU sums near-physical; monitor run-queue.

## Portfolio framing
Demonstrates cloud-native platform architecture on bare metal: IaC-driven provisioning, Vault-managed secrets, a Kubernetes compute tier cleanly separated from a managed-services (RDS/S3-analog) data tier, private-subnet networking, and built-in observability. It deliberately does **not** claim production high availability — it is a single node, and demonstrates the *patterns* of a cloud platform, not its resilience guarantees.

## Follow-ups
- [x] Confirm managed switch — **none exists**; no-uplink bridge is the network model (0004).
- [x] Split the foundation into separately-executed plans — 0002–0008 created.
- [ ] Update `docs/current-state-analysis.md` as each of 0002–0008 reaches Implemented.
