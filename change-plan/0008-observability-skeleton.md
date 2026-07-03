# 0008 — Observability Skeleton (Prometheus + Grafana + Loki)

- **Status**: Proposed
- **Date proposed**: 2026-07-03
- **Date decided**: —
- **Date implemented**: —
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0006; last base slice
- **Depends on**: 0006 (runs in the k3s `monitoring` namespace); consumes `node_exporter` from 0003 baseline

## Context
The final base layer. The CloudWatch/managed-Prometheus analog is stood up **before** any data workload so every workload — and the platform itself — is observed from day one. The 0003 baseline already ships `node_exporter` on every guest, so there is data to scrape immediately.

## Decision
Deploy an observability stack into the k3s `monitoring` namespace (0006):
1. **Prometheus** (via kube-prometheus-stack or standalone) — scrapes k3s, `node_exporter` on all guests, and the managed-services tier (Postgres/MinIO exporters, 0007).
2. **Grafana** — dashboards for host, cluster, and data services; credentials from Vault (0005).
3. **Loki + Promtail/Alloy** — centralized logs from cluster and guests.
4. At least one working dashboard and one alert rule to prove the pipeline end-to-end.

## Rationale
Metrics + logs in place before workloads is how real platform teams operate and avoids the portfolio anti-pattern of bolting monitoring on last. It also directly de-risks every later slice: RAM-pressure and I/O concerns flagged in 0006/0007 are only actionable if you can see them. Running it in-cluster (rather than as separate VMs) is dense and demonstrates the standard cloud-native monitoring pattern; it folds into the k3s VM's 12 GB budget.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Uptime Kuma (old approach) | Trivial | Uptime only; no metrics/logs depth | Too shallow for a DevOps portfolio |
| Observability as a separate VM | Isolated from cluster | Extra RAM; less cloud-native | In-cluster is standard and denser |
| Add monitoring after data workloads | Faster first data demo | Blind workloads; anti-pattern | Deliberately before, per 0001 |
| Prometheus without Loki | Less RAM | No log aggregation story | Logs are part of the expected stack |

## Resource budget
- **vCPU**: within the k3s VM's 3 (monitoring pods share it).
- **RAM**: within the k3s VM's ~12 GB (Prometheus is the main consumer — tune retention).
- **Storage**: Prometheus TSDB + Loki chunks on cluster PVs; consider a PV on `ssd-data` if retention grows.
- **Network**: private subnet; Grafana exposed via the edge (0004) ingress.

## Implementation outline
1. Helm-install kube-prometheus-stack (or components) into `monitoring`.
2. Configure scrape targets: k3s, all-guest `node_exporter`, Postgres/MinIO exporters.
3. Deploy Loki + a log shipper (Promtail/Alloy) across cluster and guests.
4. Grafana datasources + dashboards; Grafana admin cred from Vault.
5. Verify: node/cluster/data dashboards populate; trigger one alert (e.g. high memory) and confirm it fires.

## Risks & rollback
- **Prometheus/Loki RAM+disk growth.** Detection: its own metrics. Mitigation: short retention, scrape-interval tuning, PV caps. Rollback: reduce retention/targets.
- **Scrape gaps.** Detection: missing series in Grafana. Mitigation: verify each target after add.

## Portfolio framing
Demonstrates a full metrics-and-logs observability stack (Prometheus/Grafana/Loki) covering host, Kubernetes, and data services, with alerting — the platform's nervous system stood up before workloads. Single-node retention/scale, not a long-term observability warehouse.

## Follow-ups
- [ ] Alertmanager routing (email/webhook) as a later slice.
- [ ] Mark the base **complete** in `docs/current-state-analysis.md` once this is Implemented.
