# 0007 — Managed-Services Tier (Postgres + MinIO)

- **Status**: Implemented
- **Date proposed**: 2026-07-03
- **Date decided**: 2026-07-09
- **Date implemented**: 2026-07-09
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
- **vCPU**: Postgres CT ~1, MinIO CT ~1. Cumulative host allocation after this slice: `edge`(1) + `vault`(1) + `k3s-1`(3) + `pg`(1) + `minio`(1) = **7 vCPU against 6 physical cores** (no HT — confirmed via `nproc` on the live node). Accepted oversubscription: both new CTs are I/O-bound, mostly-idle homelab services, and Proxmox's CFS scheduler time-shares non-pinned vCPUs rather than dedicating them — contention risk is low, but this is the ceiling and any future guest needs a corresponding trim elsewhere.
- **RAM**: Postgres ~2 GB, MinIO ~2 GB. Live scan: 22 GB free of 31 GB total before this slice — ample headroom.
- **Storage**: data on `ssd-data`. Live scan: the pool is a 233.47 GB thin volume (`ssd-data/data`), currently 0.07% physically used (only Vault's 5 GB thin volume exists, itself ~170 MB actually written). The planned 40 GB (pg) + 120 GB (minio) thin volumes claim ~160 GB of nominal capacity (~69% of the pool) but consume negligible physical space until data is actually written — normal thin-provisioning headroom, not a hard blocker. rootfs ~4 GB each on `local-lvm` (846 GB free there).
- **Network**: private subnet (`vmbr1`); reachable from k3s and (later) data workloads. Static DNS records for `pg`/`minio` follow the existing `edge` dnsmasq pattern (one `address=` line each, as already done for `vault.lab.internal`).

## Implementation outline
1. Terraform: provision the Postgres and MinIO CTs, each with a data mount on `ssd-data`.
2. Ansible: install/configure Postgres (tuning, backups) and MinIO (buckets, users/policies).
3. Wire Vault database engine to Postgres for dynamic credentials; store MinIO keys in Vault.
4. Verify: a k3s pod connects to Postgres with a Vault-issued cred; MinIO bucket read/write from the cluster; (optional) migrate Terraform state to a MinIO bucket.

## Risks & rollback
- **Data durability on a single SSD (no RAID).** Detection: SMART/health. Mitigation: scheduled Postgres dumps + MinIO backup to `local`/`ssd-data`; documented restore. Rollback: restore from backup.
- **RAM pressure with k3s at 12 GB.** Detection: 0008 alerts. Mitigation: tune Postgres `shared_buffers`/`work_mem`; cap MinIO.
- **vCPU oversubscription (7 allocated vs 6 physical cores, no HT).** Detection: host CPU-steal/contention via 0008. Mitigation: pg/minio are I/O-bound and mostly idle; if contention appears, trim `k3s-1` or cap CT CPU shares. Rollback: reduce a guest's vCPU count via Terraform.
- **Thin-pool overcommit on `ssd-data`.** The pool is 233.47 GB nominal; `vault`(5 GB) + `pg`(40 GB) + `minio`(120 GB) claim ~165 GB of it, but physical usage is currently negligible. Detection: 0008 physical-usage alerts on the thin pool. Mitigation: monitor growth, cap MinIO bucket quotas before the pool nears physical exhaustion.
- **Credential exposure.** Mitigation: Vault-issued, short-lived Postgres creds; no static secrets in manifests.

## Portfolio framing
Demonstrates a managed-services data tier (RDS + S3 analogs) cleanly separated from compute, with Vault-issued dynamic database credentials and dedicated data storage. Does not claim replicated/HA data services — single-node, backup-based durability.

## Follow-ups
- [ ] Migrate Terraform state to a MinIO bucket (hardens 0003).
- [ ] Backup/restore runbook for Postgres and MinIO.
- [x] Update `docs/current-state-analysis.md` when implemented.
- [ ] `ansible/roles/pg/tasks/main.yml` still lacks the `no_log`/pointer-only treatment applied to `minio`'s role after the secret-exposure incident below — fix before any future re-run of the `pg` role.
- [ ] Fix Vault's self-signed cert generation (`ansible/roles/vault`): the `openssl req -newkey ec ...` command produces a cert that fails strict Go x509 validation (`vault operator generate-root` needed `VAULT_SKIP_VERIFY=true` to work around it) — likely needs `-pkeyopt ec_param_enc:named_curve` explicitly.
- [ ] The DNS gap is broader than `change-log/0006` originally scoped: **no guest's default resolver** (LXC or VM, `edge` included) reaches `edge`'s own dnsmasq — Proxmox defaults every guest's `/etc/resolv.conf` to the LAN router regardless of which `terraform/modules/{lxc,vm}` provisioned it. A real fix touches both modules and every already-Implemented guest; scope as its own change-plan rather than patching piecemeal.
- [ ] Rotate the `vaultadmin` Postgres password and MinIO root credentials on a schedule once 0008's alerting can flag staleness (also carries the one-time rotation forced by the secret-exposure incident below).
- [ ] Fix the pinned Debian cloud-image mirror drift discovered during this slice's execution: the upstream image at the pinned mirror URL (`docs/platform-conventions.md`) changed size since 0003, and a plain `terraform apply` now wants to replace the downloaded image, update template 9000's disk import, and touch the running `k3s-1` VM in-place. Left **untouched** during 0007 (all applies were scoped with `-target=module.pg -target=module.minio`) — needs its own reviewed change before any future untargeted `apply`.

## Implementation status
**DONE (2026-07-09):** executed and tester-verified end-to-end, every step and the full Definition of Done. `pg` (LXC, VMID **120**, `10.10.10.30`, private-subnet only) runs **PostgreSQL 17** (corrected from the originally-planned 16 — Debian 13 trixie's native repo only serves 17; pulling 16 would have needed the third-party PGDG repo for no real benefit) with its cluster relocated onto the `ssd-data` mount (`/pg/data/17/main`), tuned modestly for its 2 GB RAM budget, listening on its private IP only. `minio` (LXC, VMID **121**, `10.10.10.40`, private-subnet only) runs **MinIO `RELEASE.2025-09-07T16-13-09Z`** with data on its own `ssd-data` mount (`/minio/data`), as a systemd service. Both provisioned via new `terraform/pg.tf`/`terraform/minio.tf` module invocations (the same `terraform/modules/lxc` pattern as `vault`) and new Ansible `pg`/`minio` roles. Vault's **`database/` secrets engine** is now connected to Postgres (a dedicated `vaultadmin` superuser, `CREATEROLE,CREATEDB,LOGIN`, mints/drops per-consumer creds via `database/roles/app`), and MinIO's root credentials live in Vault KV (`kv/minio`) — no static secret for either service exists in any tracked file. Two new Vault Kubernetes-auth roles (`k3s-pg`, `k3s-minio`, policies `pg-read`/`minio-read`) extend the `kubernetes` auth method configured in 0006. Proven end-to-end with two demo k3s Jobs: `pg-verify`'s Vault Agent sidecar fetched a live `database/creds/app` lease and `psql` connected successfully as the minted user (`v-kubernet-app-...`); `minio-verify`'s Vault Agent sidecar fetched `kv/data/minio` and `mc` created a bucket, wrote, and read back a test object.

A notably high number of real defects and one real security incident were caught and handled during execution — more than any prior slice, reflecting how much new integration surface (Postgres, MinIO, Vault's `database/` engine, two new Vault k8s-auth roles) this slice added on top of 0002–0006:

1. **Pre-existing bug, not new**: `terraform/secrets.tf`'s `ca_cert_file` still pointed at `~/.vault/vault-ca.crt`, a path 0006 renamed to `~/.vault-files/` on the workstation but never updated in this file — every `terraform apply` was broken until fixed in Step 1.
2. **Unrelated upstream drift discovered, deliberately left alone**: the pinned Debian cloud-image mirror's file size changed since 0003, so a plain `terraform apply` wanted to replace the downloaded image and touch template 9000 and the running `k3s-1` VM. All of this slice's applies were scoped with `-target=module.pg -target=module.minio` to avoid pulling an unrelated, unreviewed change into this slice's execution — carried as its own follow-up above.
3. A missing `python3-psycopg2` dependency for the `community.postgresql.postgresql_user` Ansible module — added to the `pg` role's package install task.
4. A bootstrap-ordering assumption in the runbook was wrong: it specified `ansible_user=deploy` for the freshly-created `pg`/`minio` LXCs, but `deploy` doesn't exist until the `baseline` role's first run creates it (only `root` has the injected SSH key at container creation) — corrected to `ansible_user=root` for the initial run, matching the precedent already documented in `change-log/0005`.
5. **A real secret-exposure incident**, same class as the root-token leak in `change-log/0005`: the `pg` role's Ansible `debug` task, intended to print the generated `vaultadmin` password only to "the operator's own terminal," instead printed into the executer's own captured tool output — i.e. into the assistant's conversation transcript — because the executer (not the operator) ran `ansible-playbook`. The leaked password was rotated immediately by the operator directly on the `pg` container (`ALTER ROLE ... PASSWORD`), never disclosed back to the assistant. The `minio` role was proactively fixed before it ran: the credential-generation task got `no_log: true` and the debug task now only tells the operator where to read the file (`/etc/default/minio`, 0600) themselves — MinIO's credentials never printed anywhere the assistant could see. **`ansible/roles/pg/tasks/main.yml`'s equivalent debug task was left un-fixed** (Postgres, unlike MinIO, has no durable retrievable copy of the plaintext afterward, so the fix there is procedural — the operator must run any future re-run of that specific task directly — rather than a code suppression) — flagged as a follow-up above.
6. **The DNS gap `change-log/0006` first found is broader than it described**: that entry attributed unresolvable `*.lab.internal` names from `k3s-1` to "the vm module hardcodes DNS to the LAN router." This slice found the same failure on the freshly-created `pg` LXC, and then confirmed it on `edge` itself — every guest, LXC or VM, gets `/etc/resolv.conf` managed by Proxmox to mirror the host's own DNS (the LAN router), because neither `terraform/modules/lxc` nor `modules/vm` ever configures guest-side DNS servers. The dnsmasq records for `pg.lab.internal`/`minio.lab.internal` were still added correctly (and verified to resolve when queried directly against `10.10.10.1`) as the forward-looking, correct configuration — but the demo Jobs in Step 9 reference `pg`/`minio` by private IP, not hostname, the same workaround 0006 used for `vault.lab.internal`. A real fix is scoped as its own follow-up, not patched here.
7. **Vault CA trust missing from the demo Job manifests**: as in 0006, a pod using the Vault Agent Injector needs `vault.hashicorp.com/ca-cert`/`tls-secret` annotations pointing at the already-existing `vault-tls-ca` k8s Secret, or the agent fails to authenticate (`x509: certificate signed by unknown authority`). Missing from the first draft of both `pg-verify` and `minio-verify`; added once diagnosed.
8. **The Vault Agent Injector's default secret-rendering template doesn't flatten KV v2 secrets.** For `database/creds/app` (a dynamic secret, flat `.Data`), the default template renders usable `key: value` lines. For `kv/data/minio` (a real KV v2 read), the default template instead dumps the raw nested Go map (`data: map[...]`, `metadata: map[...]`) — not usable directly. Fixed with a custom `vault.hashicorp.com/agent-inject-template-minio-creds` annotation rendering `MINIO_ROOT_USER=...`/`MINIO_ROOT_PASSWORD=...` lines instead.
9. **Vault's self-signed TLS cert fails strict Go x509 validation** for CLI operations like `vault operator generate-root` (`x509: ... certificate is not standards compliant`), even against its own CA. Worked around with `VAULT_SKIP_VERIFY=true` for the operator's CLI session; the likely root cause (the `openssl req -newkey ec ...` command in `ansible/roles/vault` probably needs `-pkeyopt ec_param_enc:named_curve` to avoid an explicit-parameter EC encoding Go rejects) is carried as a follow-up above, not fixed in this slice.

Portfolio note: the secret-exposure incident (defect 5) was caught and handled transparently in real time — the same discipline `change-log/0006` established for a similar root-token exposure — rather than silently proceeding or hiding it after the fact.
