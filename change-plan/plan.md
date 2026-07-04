# Plan — Roadmap & Current Work

**This is the roadmap** for the homelab and the entry point a reader hits first: the current objective, every slice, its execution order, and its live status. Maintained by the **architect** skill — the single source of truth for *what is being built and where each slice stands*. The *why* behind each decision lives in the `change-plan/` ADRs, which this file links to. (A roadmap and status map, not a decision record — no rationale is duplicated here.)

## Role model
| Skill | Owns | Does |
| :--- | :--- | :--- |
| **architect** | `change-plan/` + this `plan.md` | Decides *what* and *why*; writes ADRs and keeps this overview current. |
| **devops** | `runbooks/` | Validates an `Accepted` change-plan, authors its executable runbook, and maintains the executer contract. |
| **executer** | execution | Runs the validated runbook tasks against the live node, following the executer contract; paired with the `tester`. |
| **tester** | verification | After each executer step, independently re-checks the live node against the runbook's Verify / Definition of Done; on failure routes the step back to `devops`. |
| **architect-docs** | `docs/system-documentation.md` | After a slice is done (tester-confirmed), scans the live node and refreshes the as-built system documentation. Runs at the end of finished work. |

## Current objective
Build the **cloud-analog platform foundation** — a reproducible, IaC-driven platform floor before any data-engineering workload: a compute tier (k3s) cleanly separated from a managed-services tier (Postgres/MinIO), Vault for secrets, a private-subnet network, and built-in observability, all provisioned as code. The full architectural decision and its rationale (cloud-primitive mapping, alternatives) is the ADR `change-log/0001-cloud-analog-platform-foundation.md` (**Accepted** umbrella; kept in `change-log/` as a settled record so `change-plan/` holds only in-flight slices) — this roadmap tracks its execution, it does not restate its reasoning.

## What is to be done now
Seven slices, **executed strictly in order** (Vault at 0005 deliberately precedes the credentialed workloads 0006–0008). Each has an ADR in `change-plan/`; runbooks are authored by the `devops` skill once a plan is `Accepted`.

| # | Slice | Change-plan status | Runbook |
| :--- | :--- | :--- | :--- |
| 0002 | Host & storage hygiene | **Implemented** → archived in `change-log/` | Done & tester-verified; runbook deleted. `ssd-data`, `terraform@pve` identity, PVE 9.2.4 / kernel 7.0.14-2-pve |
| 0003 | IaC control plane (Terraform + template + Ansible) | **Implemented** → archived in `change-log/` | Done & tester-verified; runbook deleted. Template 9000, `modules/vm`, Ansible `baseline` role, `VM.GuestAgent.Audit` added to `TerraformProv` |
| 0004 | Private-subnet network (VPC analog) | **Implemented** → archived in `change-log/` | Done & tester-verified; runbook deleted. `vmbr1`, `edge` (LXC 101), `modules/lxc`, Ansible `edge` role, `baseline` LXC guard |
| 0005 | Vault secrets | Proposed | to author |
| 0006 | k3s compute tier | Proposed | to author |
| 0007 | Managed-services tier (Postgres + MinIO) | Proposed | to author |
| 0008 | Observability (Prometheus/Grafana/Loki) | Proposed | to author |

**Current focus: 0005** — Vault secrets, still `Proposed`; next step is to `Accept` it, then `devops 0005`. **0004 is Implemented** (2026-07-04): no-uplink bridge `vmbr1` (`10.10.10.0/24`) and an unprivileged LXC `edge` (VMID 101, dual-homed `192.168.0.10`/`10.10.10.1`) provisioned via a new `terraform/modules/lxc` module; `edge` runs IP forwarding + an nftables ruleset (default-deny inbound, NAT egress) + dnsmasq (DHCP/DNS) via a new Ansible `edge` role — proven with a throwaway DHCP client on the private subnet (internet only via `edge`'s NAT, DNS via `edge`, unreachable from the LAN except through the bastion `ssh -J`), then destroyed. One real compatibility gap fixed along the way: the `baseline` role's unconditional `qemu-guest-agent` enable would have failed on LXC guests — now guarded, benefiting every future LXC (0005 Vault, 0007 Postgres/MinIO). **0003 is Implemented** (2026-07-04): golden template **9000** (`debian13-cloud`) built by Terraform from a stock Debian 13 image, reusable `modules/vm` clone module, Ansible `baseline` role (guest agent, `deploy` user, SSH hardening, `node_exporter`) — proven end-to-end by creating, converging, and destroying a throwaway VM. Six real defects were caught and fixed during execution (see `change-log/0003` Implementation status): a delisted Homebrew formula, a slow mirror redirect, a missing `network_device` on template + clone module, a missing module `required_providers`, the two-phase guest-agent enable pattern, and a missing `VM.GuestAgent.Audit` privilege (now added to `TerraformProv`). **0002 is Implemented** (2026-07-03): `ssd-data` pool, `terraform@pve` least-privilege identity, host upgraded to PVE 9.2.4 / kernel 7.0.14-2-pve.

## Documentation map
- **Hardware ceiling** — `docs/hardware.md`
- **Current state** — `docs/current-state-analysis.md`
- **Pinned values** (IP / VMID / sizes / versions / accounts) — `docs/platform-conventions.md`
- **In-flight decisions (ADRs)** — `change-plan/` · **settled decisions (history)** — `change-log/` (implemented slices + the accepted foundational umbrella 0001)
- **Execution guides** — `runbooks/` (authored by `devops`; a runbook is deleted once Executed)
- **As-built system** — `docs/system-documentation.md` (by `architect-docs`)
- **Security rules** — `docs/security-conventions.md`
- **Previous project** (reference only) — `old_homelab/`

## Definition of "base complete"
When 0002–0008 are all `Implemented`, the platform base is done. Data-engineering workloads (Airflow/Dagster + dbt on the Postgres/MinIO tier) then begin as **new** change-plans on top of the base.
