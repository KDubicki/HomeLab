# Plan — Current Work Overview

The living entry point to what this homelab is doing right now. Maintained by the **architect** skill alongside the `change-plan/` ADRs. This is a **map, not a decision record** — for the *why* behind anything here, follow the reference.

## Role model
| Skill | Owns | Does |
| :--- | :--- | :--- |
| **architect** | `change-plan/` + this `plan.md` | Decides *what* and *why*; writes ADRs and keeps this overview current. |
| **devops** | `runbooks/` | Validates an `Accepted` change-plan, authors its executable runbook, and maintains the executer contract. |
| **executer** | execution | Runs the validated runbook tasks against the live node, following the executer contract; paired with the `tester`. |
| **tester** | verification | After each executer step, independently re-checks the live node against the runbook's Verify / Definition of Done; on failure routes the step back to `devops`. |
| **architect-docs** | `docs/system-documentation.md` | After a slice is done (tester-confirmed), scans the live node and refreshes the as-built system documentation. Runs at the end of finished work. |

## Current objective
Build the **cloud-analog platform foundation** — a reproducible, IaC-driven platform floor before any data-engineering workload. Umbrella decision: `change-plan/0001-cloud-analog-platform-foundation.md` (**Accepted**).

## What is to be done now
Seven slices, executed in order. Each has an ADR in `change-plan/`; runbooks are authored by the `devops` skill once a plan is `Accepted`.

| # | Slice | Change-plan status | Runbook |
| :--- | :--- | :--- | :--- |
| 0002 | Host & storage hygiene | **Implemented** → archived in `change-log/` | Done & tester-verified; runbook deleted. `ssd-data`, `terraform@pve` identity, PVE 9.2.4 / kernel 7.0.14-2-pve |
| 0003 | IaC control plane (Terraform + template + Ansible) | Proposed | to author |
| 0004 | Private-subnet network (VPC analog) | Proposed | to author |
| 0005 | Vault secrets | Proposed | to author |
| 0006 | k3s compute tier | Proposed | to author |
| 0007 | Managed-services tier (Postgres + MinIO) | Proposed | to author |
| 0008 | Observability (Prometheus/Grafana/Loki) | Proposed | to author |

**Current focus: 0003** — IaC control plane. **0002 is Implemented** (2026-07-03): `ssd-data` pool, `terraform@pve` least-privilege identity (role + ACL + token), host upgraded to PVE 9.2.4 / kernel 7.0.14-2-pve. Next: accept 0003, then `devops 0003`.

## Documentation map
- **Hardware ceiling** — `docs/hardware.md`
- **Current state** — `docs/current-state-analysis.md`
- **Pinned values** (IP / VMID / sizes / versions / accounts) — `docs/platform-conventions.md`
- **Active decisions (ADRs)** — `change-plan/` · **completed decisions (history)** — `change-log/`
- **Execution guides** — `runbooks/` (authored by `devops`; a runbook is deleted once Executed)
- **As-built system** — `docs/system-documentation.md` (by `architect-docs`)
- **Security rules** — `docs/security-conventions.md`
- **Previous project** (reference only) — `old_homelab/`

## Definition of "base complete"
When 0002–0008 are all `Implemented`, the platform base is done. Data-engineering workloads (Airflow/Dagster + dbt on the Postgres/MinIO tier) then begin as **new** change-plans on top of the base.
