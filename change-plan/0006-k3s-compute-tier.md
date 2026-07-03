# 0006 — k3s Compute Tier (EKS Analog)

- **Status**: Proposed
- **Date proposed**: 2026-07-03
- **Date decided**: —
- **Date implemented**: —
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0003, 0004, 0005; precedes 0007/0008
- **Depends on**: 0003 (provisioning), 0004 (private subnet), 0005 (Vault for cluster secrets)

## Context
This is the compute tier — the owner's chosen orchestration substrate: **k3s on a dedicated VM**, the managed-Kubernetes (EKS) analog. Application and pipeline workloads, plus the observability stack (0008), run here. Stateful backing services deliberately do **not** (they are 0007).

## Decision
Provision **k3s on a single dedicated VM** on the private subnet:
1. Terraform provisions the VM (from the golden template); Ansible bootstraps k3s (server node), installs Helm, and wires kubeconfig retrieval.
2. Ingress via the bundled Traefik (or documented swap); a `LoadBalancer` path via the edge (0004) or `ServiceLB`.
3. Cluster pulls secrets from Vault (0005) via Vault Agent/CSI.
4. Verify with a test Deployment + Ingress reachable through the edge.

Single-node k3s (control-plane + workloads on one VM). Optionally add a second lightweight agent VM later purely to demonstrate multi-node scheduling — explicitly not for HA.

## Rationale
k3s is the lightweight, production-grade Kubernetes that fits a single host while presenting the full k8s API — real Helm, manifests, GitOps, RBAC. On this box it is honestly *cluster architecture demonstrated*, not HA. Putting only stateless/cluster-managed workloads here (and keeping databases in 0007) is the cloud-native separation that is the whole point of 0001.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Full kubeadm k8s | Most "real" | Heavy for one node; more RAM/ops | k3s gives the same API at a fraction of the cost |
| k3s in LXC | Denser | Nesting/cgroup friction; less clean | A dedicated VM is cleaner and template-driven |
| Multi-node k3s across VMs now | Shows scheduling | Splits fixed RAM; no true HA anyway | Single node now; optional agent later for demo |

## Resource budget
- **vCPU**: k3s VM ~3.
- **RAM**: ~12 GB (includes the `monitoring` namespace from 0008).
- **Storage**: VM disk ~60 GB on `local-lvm` (NVMe); PVs for stateless workloads local-path.
- **Network**: private subnet (`vmbr1`); ingress exposed via the edge.

## Implementation outline
1. Terraform: provision the k3s VM (3 vCPU / 12 GB / ~60 GB) on `vmbr1`.
2. Ansible: install k3s server, Helm, kube-vip/ServiceLB or edge-based ingress; fetch kubeconfig to the workstation via the bastion.
3. Integrate Vault (Agent injector or Secrets Store CSI).
4. Verify: deploy a sample app + Ingress; reach it through the edge; `kubectl get nodes` healthy.

## Risks & rollback
- **RAM contention** with managed services + host. Detection: node memory alerts (0008). Mitigation: requests/limits; the 12 GB is a ceiling to respect. Rollback: scale down non-essential workloads.
- **Ingress/LoadBalancer complexity on one NIC.** Mitigation: route ingress through the edge (0004). Rollback: NodePort as fallback.
- **Cluster rebuild.** Mitigation: everything (VM + bootstrap) is code — reprovision from scratch.

## Portfolio framing
Demonstrates Kubernetes platform operations — provisioning, Helm, ingress, RBAC, Vault-injected secrets — on k3s. Explicitly single-node: demonstrates cluster architecture and operations, **not** production high availability.

## Follow-ups
- [ ] Optional second agent VM to demo multi-node scheduling (not HA).
- [ ] GitOps (Argo CD / Flux) as a later portfolio slice.
- [ ] Update `docs/current-state-analysis.md` when implemented.
