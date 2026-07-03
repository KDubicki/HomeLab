# 0007 — Managed-Services Tier (Postgres + MinIO)

- **Status**: Proposed
- **Date proposed**: 2026-07-03
- **Date decided**: —
- **Date implemented**: —
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0002, 0003, 0004, 0005, 0006
- **Depends on**: 0002 (SSD pool), 0003 (provisioning), 0004 (private subnet), 0005 (Vault credentials)

## Context
The cloud-fidelity model keeps stateful backing services **outside** the k3s cluster (0006), as the RDS/S3 analogs. This slice stands up **Postgres** (relational store for the future data pipeline: Airflow/Dagster metadata + warehouse) and **MinIO** (S3-compatible object store: data lake / artifacts / Terraform state), each in its own LXC with data on the `ssd-data` pool.

## Decision
Run two separate LXC containers on the private subnet (0004):
1. **Postgres** — its own CT; data volume on `ssd-data`; credentials issued dynamically by Vault's database engine (0005); reachable from k3s (0006) and from data workloads.
2. **MinIO** — its own CT; buckets on `ssd-data`; the S3 analog for the data lake, workload artifacts, and (later) remote Terraform state.

Both are provisioned by Terraform and configured by Ansible; neither runs inside k3s.

## Rationale
Keeping databases and object storage off the cluster is the explicit cloud best practice (stateful durability decoupled from cluster lifecycle) and the concrete realization of 0001's compute/managed-services split. LXC (not VMs) keeps these lightweight and dense — appropriate for always-on services with modest CPU. Data on the dedicated SSD isolates their I/O from the NVMe OS/VM pool (0002). MinIO doubles as the S3 backend that later hardens the IaC story (remote state) and feeds the data-engineering workloads.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Postgres/MinIO inside k3s | One substrate | Couples data durability to cluster; anti-pattern | Defeats the 0001 separation |
| Managed VMs instead of LXC | Stronger isolation | Heavier for always-on services | LXC is lighter; isolation adequate on the private subnet |
| Cloud object storage (real S3) | Zero local footprint | External dependency; not self-contained | Self-hosted MinIO keeps the lab autonomous |
| Single combined "data" CT | Fewer containers | Muddies the RDS/S3 separation | Two clean analogs read better |

## Resource budget
- **vCPU**: Postgres CT ~1, MinIO CT ~1.
- **RAM**: Postgres ~2 GB, MinIO ~2 GB.
- **Storage**: data on `ssd-data` (256 GB SSD) — the bulk of that pool; rootfs ~4 GB each on `local-lvm`.
- **Network**: private subnet (`vmbr1`); reachable from k3s and (later) data workloads.

## Implementation outline
1. Terraform: provision the Postgres and MinIO CTs, each with a data mount on `ssd-data`.
2. Ansible: install/configure Postgres (tuning, backups) and MinIO (buckets, users/policies).
3. Wire Vault database engine to Postgres for dynamic credentials; store MinIO keys in Vault.
4. Verify: a k3s pod connects to Postgres with a Vault-issued cred; MinIO bucket read/write from the cluster; (optional) migrate Terraform state to a MinIO bucket.

## Risks & rollback
- **Data durability on a single SSD (no RAID).** Detection: SMART/health. Mitigation: scheduled Postgres dumps + MinIO backup to `local`/`ssd-data`; documented restore. Rollback: restore from backup.
- **RAM pressure with k3s at 12 GB.** Detection: 0008 alerts. Mitigation: tune Postgres `shared_buffers`/`work_mem`; cap MinIO.
- **Credential exposure.** Mitigation: Vault-issued, short-lived Postgres creds; no static secrets in manifests.

## Portfolio framing
Demonstrates a managed-services data tier (RDS + S3 analogs) cleanly separated from compute, with Vault-issued dynamic database credentials and dedicated data storage. Does not claim replicated/HA data services — single-node, backup-based durability.

## Follow-ups
- [ ] Migrate Terraform state to a MinIO bucket (hardens 0003).
- [ ] Backup/restore runbook for Postgres and MinIO.
- [ ] Update `docs/current-state-analysis.md` when implemented.
