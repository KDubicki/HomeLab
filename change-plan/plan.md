# Plan — Current Work Overview

The living entry point to what this homelab is doing right now. Maintained by the **architect** skill alongside the `change-plan/` ADRs. This is a **map, not a decision record** — for the *why* behind anything here, follow the reference.

## Role model
| Skill | Owns | Does |
| :--- | :--- | :--- |
| **architect** | `change-plan/` + this `plan.md` | Decides *what* and *why*; writes ADRs and keeps this overview current. |
| **devops** | `runbooks/` | Validates an `Accepted` change-plan, authors its executable runbook, and maintains the operator contract. |
| **operator** *(future)* | execution | Runs runbook tasks against the live node, following the operator contract. Not built yet. |

## Current objective
Build the **cloud-analog platform foundation** — a reproducible, IaC-driven platform floor before any data-engineering workload. Umbrella decision: `change-plan/0001-cloud-analog-platform-foundation.md` (**Accepted**).

## What is to be done now
Seven slices, executed in order. Each has an ADR in `change-plan/`; runbooks are authored by the `devops` skill once a plan is `Accepted`.

| # | Slice | Change-plan status | Runbook |
| :--- | :--- | :--- | :--- |
| 0002 | Host & storage hygiene | Accepted | Validated |
| 0003 | IaC control plane (Terraform + template + Ansible) | Proposed | to author |
| 0004 | Private-subnet network (VPC analog) | Proposed | to author |
| 0005 | Vault secrets | Proposed | to author |
| 0006 | k3s compute tier | Proposed | to author |
| 0007 | Managed-services tier (Postgres + MinIO) | Proposed | to author |
| 0008 | Observability (Prometheus/Grafana/Loki) | Proposed | to author |

**Current focus: 0002** — Accepted; `devops` is authoring its runbook. Next: execute 0002 (the future `operator`), then 0003.

## Documentation map
- **Hardware ceiling** — `docs/hardware.md`
- **Current state** — `docs/current-state-analysis.md`
- **Pinned values** (IP / VMID / sizes / versions / accounts) — `docs/platform-conventions.md`
- **Decisions (ADRs)** — `change-plan/`
- **Execution guides** — `runbooks/` (authored by `devops`)
- **Previous project** (reference only) — `old_homelab/`

## Definition of "base complete"
When 0002–0008 are all `Implemented`, the platform base is done. Data-engineering workloads (Airflow/Dagster + dbt on the Postgres/MinIO tier) then begin as **new** change-plans on top of the base.
