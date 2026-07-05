# 0006 — k3s Compute Tier (EKS Analog)

- **Status**: Implemented
- **Date proposed**: 2026-07-03
- **Date decided**: 2026-07-05
- **Date implemented**: 2026-07-06
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0003, 0004, 0005; precedes 0007/0008
- **Depends on**: 0003 (provisioning), 0004 (private subnet), 0005 (Vault for cluster secrets)

## Context
This is the compute tier — the owner's chosen orchestration substrate: **k3s on a dedicated VM**, the managed-Kubernetes (EKS) analog. Application and pipeline workloads, plus the observability stack (0008), run here. Stateful backing services deliberately do **not** (they are 0007).

**Implementation status — DONE (2026-07-06):** executed and tester-verified end-to-end, every step and the full Definition of Done. `k3s-1` (VM, VMID **110**, `10.10.10.20`, private-subnet only) runs single-node **k3s v1.36.2+k3s1** (bundled Traefik + `ServiceLB` retained) with Helm, provisioned via a new `terraform/modules/vm` `k3s.tf` module invocation and a new Ansible `k3s` role. Vault's **`kubernetes` auth method** is configured (role `k3s-sample` bound to ServiceAccount `sample`/`default`, reviewer identity `vault-auth`), and the **`vault-k8s` Agent Injector** (Helm, `server.enabled=false`) is live in-cluster. `edge` (0004) now DNATs LAN `80`/`443` to `k3s-1`'s ingress; kube-API (`6443`) and kubeconfig retrieval stayed bastion/SSH-tunnel-only, as designed. A sample Deployment/Service/Ingress proved the whole path: the Vault Agent sidecar rendered `kv/k3s/sample`'s `greeting` into the pod, the Ingress answered from the LAN through `edge`'s new DNAT, and `kubectl get nodes` worked over the tunneled kubeconfig.

Nine real defects were caught and fixed during execution rather than papered over: (1) a step-ordering bug — the runbook originally ran the Ansible bootstrap before the Terraform `agent_enabled` flip, but the qemu-guest-agent's virtio-serial channel doesn't exist until the second `apply`, so the guest-agent service failed to start; fixed by swapping the step order (agent-enable now precedes Ansible bootstrap). (2) A stale assumption from change-log/0003 corrected: on the current `bpg/proxmox` provider (0.111.1), flipping `agent_enabled` actually performs a `qmshutdown`+`qmstart` (confirmed via the Proxmox task log), not a true hot-plug as 0003 claimed — harmless on a fresh VM with no workloads, but the "no reboot" claim doesn't hold on this provider version. (3)–(4) Two YAML/idempotency bugs in the new `k3s` Ansible role: an unquoted colon in a task name (YAML parse error), and a JSONPath filter whose quotes were stripped by `ansible.builtin.command`'s tokenizer — fixed by switching to `kubectl wait --for=condition=Ready`; also an `AlreadyExists`-string-matching idempotency guard that didn't match the real (differently-worded) kubectl CLI error text — fixed with the standard `--dry-run=client -o yaml | kubectl apply -f -` idiom. (5) A missing `mode: "0600"` on two `ansible.builtin.fetch` tasks (kubeconfig, Vault CA cert) — they landed at the local umask default (644) instead of 600, a real least-privilege gap for files carrying live cluster/Vault credentials. (6) A DNS/private-zone gap: `vault.lab.internal` (edge's dnsmasq zone) is not resolvable from `k3s-1` or its pods, because `terraform/modules/vm` hardcodes DNS to `192.168.0.1` (the LAN router) regardless of bridge — worked around by addressing Vault via its private IP (`10.10.10.10`), which the Vault TLS cert's SAN already covered; a genuine structural gap in `modules/vm`, carried as a follow-up. (7) A missing Vault CA-trust step: the Agent Injector had no way to trust Vault's self-signed server cert inside the cluster — fixed by distributing the CA as a Kubernetes Secret (`vault-tls-ca`) and adding `vault.hashicorp.com/tls-secret`/`ca-cert` pod annotations. (8) A single-node Helm deadlock: the `hashicorp/vault` chart's injector Deployment sets a default `podAntiAffinity`, which can never be satisfied with exactly one node — every `helm upgrade` hung at `pending-upgrade` until `injector.affinity=""` was set. (9) An operational collision: the project's own `~/.vault/` directory convention (holding `vault-ca.crt`, from 0005) collides with the Vault CLI's own reserved config file, also at `~/.vault` — renamed to `~/.vault-files/` everywhere (Ansible role, runbook, workstation). A tenth, smaller gap was also found and closed: `.gitignore` never covered Terraform plan files (`*.plan`), which can embed resolved sensitive values same as state — added `terraform/**/*.plan`.

One thing worth recording as a **successful precaution**, not a defect: the Vault root-token minting/consumption/revocation for the `kubernetes` auth setup was deliberately kept to the operator's own terminal throughout, never routed through the assistant's tool calls — specifically to avoid repeating the exact incident logged in change-log/0005 (a root token pasted into the assistant conversation). The root token was confirmed revoked (`vault token lookup` → `403 permission denied`/`invalid token`) before the slice was considered done.

## Decision
Provision **k3s on a single dedicated VM** on the private subnet:
1. Terraform provisions the VM (from the golden template, `k3s-1` / VMID 110 / `10.10.10.20` per `docs/platform-conventions.md`); Ansible bootstraps k3s (server node, bundled Traefik + `ServiceLB` retained as ingress/LB), installs Helm.
2. **Vault integration — Agent Sidecar Injector** (decided over CSI driver / `vault-secrets-operator`, see Alternatives): enable a `kubernetes` auth method in Vault (0005) with a role bound to the consuming app's ServiceAccount/namespace; install HashiCorp's `vault-k8s` Helm chart (Agent Injector), whose mutating webhook uses a **self-signed cert the chart generates itself** — no `cert-manager` dependency. Pods opt in via `vault.hashicorp.com/agent-inject` annotations; the sidecar renders secrets to a shared volume.
3. **Ingress reachability — edge DNAT for data plane, SSH bastion for admin plane** (both k3s-1 and Vault sit on the private subnet, so k3s already resolves `vault.lab.internal` directly with no tunnel needed for the Vault Agent → Vault path):
   - Data plane: extend `edge`'s (0004) nftables with a `nat prerouting` DNAT (`tcp dport {80,443} iif eth0 → 10.10.10.20`) plus a matching `forward` accept (`iif eth0 oif eth1 tcp dport {80,443}`), so ingress traffic reaches k3s-1's Traefik/ServiceLB the same way a cloud ALB fronts a private-subnet target — the cloud-analog point of 0004's edge.
   - Admin plane: kube-API (6443) and kubeconfig retrieval stay **off** DNAT — fetched to the workstation the same way the Vault provider reached Vault in 0005 (SSH-tunneled through the bastion), keeping cluster admin access as private as Vault's.
4. Verify: a sample Deployment + Service + Ingress, with the pod annotated for Vault Agent injection (rendering a `kv/data/k3s/sample` secret) — confirm the injected file inside the pod, reach the Ingress from the LAN through edge's DNAT, and `kubectl get nodes` healthy via the SSH-tunneled kubeconfig.

Single-node k3s (control-plane + workloads on one VM). Optionally add a second lightweight agent VM later purely to demonstrate multi-node scheduling — explicitly not for HA.

## Rationale
k3s is the lightweight, production-grade Kubernetes that fits a single host while presenting the full k8s API — real Helm, manifests, GitOps, RBAC. On this box it is honestly *cluster architecture demonstrated*, not HA. Putting only stateless/cluster-managed workloads here (and keeping databases in 0007) is the cloud-native separation that is the whole point of 0001. The Agent Sidecar Injector is HashiCorp's flagship Kubernetes integration pattern — the strongest "real Vault shop" portfolio signal, and it reuses the Vault instance from 0005 rather than adding a parallel secrets path. Routing only ports 80/443 through edge's DNAT while keeping 6443 bastion-only mirrors a real cloud split: a public-facing ALB/ingress vs. a private control-plane endpoint — both patterns worth having in the portfolio, not just one.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Full kubeadm k8s | Most "real" | Heavy for one node; more RAM/ops | k3s gives the same API at a fraction of the cost |
| k3s in LXC | Denser | Nesting/cgroup friction; less clean | A dedicated VM is cleaner and template-driven |
| Multi-node k3s across VMs now | Shows scheduling | Splits fixed RAM; no true HA anyway | Single node now; optional agent later for demo |
| Secrets Store CSI Driver (Vault provider) | Modern, GitOps-friendly, fewer moving parts than a webhook | Generic CSI interface, less iconic as a "Vault" demonstration | Agent Injector is the more recognizable HashiCorp pattern |
| `vault-secrets-operator` (sync to native k8s Secrets) | Simplest consumption (plain k8s Secret) | Newest/least battle-tested; hides Vault's dynamic-secret mechanics from the demo | Weakest demonstration of Vault internals |
| Expose kube-API (6443) via edge DNAT too | One less SSH tunnel for the workstation | Widens inbound surface for the cluster's admin plane | Keep 6443 bastion-only, consistent with how Vault's own admin path was kept private in 0005 |

## Resource budget
- **vCPU**: k3s VM ~3.
- **RAM**: ~12 GB (includes the `monitoring` namespace from 0008; the Agent Injector's own webhook pod and per-pod sidecars are small, ~64–128 Mi each, absorbed within this ceiling).
- **Storage**: VM disk ~60 GB on `local-lvm` (NVMe); PVs for stateless/cluster-managed workloads via k3s's bundled `local-path` provisioner.
- **Network**: private subnet (`vmbr1`); ingress (80/443 only) reachable from the LAN via a new DNAT on `edge` (0004); kube-API (6443) stays bastion-only, no DNAT.

## Implementation outline
1. Terraform: provision `k3s-1` (VM, VMID 110, 3 vCPU / 12 GB / ~60 GB) on `vmbr1` at `10.10.10.20`, from template 9000.
2. Ansible `baseline` role, then a new `k3s` role: install k3s server (bundled Traefik + `ServiceLB` kept), Helm; fetch kubeconfig to the workstation over the existing SSH-bastion path (same pattern as 0005's Vault tunnel), rewriting the server address for the tunnel.
3. Vault: enable the `kubernetes` auth method (new role, service-account/namespace bound); install `vault-k8s` (Agent Injector) via Helm on k3s-1 — chart-generated self-signed webhook cert, no `cert-manager`.
4. Ansible `edge` role: add the `nat prerouting` DNAT (`tcp dport {80,443}` → `10.10.10.20`) and matching `forward` accept rule; leave the default-deny policy and all other ports untouched.
5. Verify: deploy a sample Deployment/Service/Ingress with a Vault-Agent-annotated pod (secret from `kv/data/k3s/sample`) — confirm the rendered secret file in-pod, `curl` the Ingress from the LAN through edge's new DNAT, and confirm `kubectl get nodes` healthy via the tunneled kubeconfig.

## Risks & rollback
- **RAM contention** with managed services + host. Detection: node memory alerts (0008). Mitigation: requests/limits; the 12 GB is a ceiling to respect. Rollback: scale down non-essential workloads.
- **Edge DNAT widens `edge`'s inbound surface** (previously SSH-only from the LAN). Mitigation: only `tcp/80,443` forwarded to `10.10.10.20`, default-deny policy and all other ports unchanged; kube-API stays off DNAT entirely. Rollback: remove the two added nftables rules — `edge` reverts to its 0004 egress-only forwarding.
- **This runbook modifies already-`Implemented` guests** (`edge`'s nftables, `vault`'s auth methods) rather than only creating new ones. Mitigation: changes are additive (new rules/mounts alongside existing ones), applied via the same Ansible roles already idempotent from 0004/0005. Rollback: re-run the prior role version, or revert via the guest's Terraform/Ansible state.
- **Cluster rebuild.** Mitigation: everything (VM + bootstrap + Vault auth config + edge DNAT) is code — reprovision from scratch.

## Portfolio framing
Demonstrates Kubernetes platform operations — provisioning, Helm, ingress, RBAC, and a real HashiCorp Vault Agent Injector secrets pattern — on k3s, plus a cloud-analog traffic split (edge DNAT as a public ALB/ingress front door for 80/443, bastion-only access for the private control-plane/API). Explicitly single-node: demonstrates cluster architecture and operations, **not** production high availability.

## Follow-ups
- [ ] Optional second agent VM to demo multi-node scheduling (not HA).
- [ ] GitOps (Argo CD / Flux) as a later portfolio slice.
- [ ] Consider exposing 6443 via edge later if remote (non-tunneled) `kubectl` access is ever wanted — deliberately deferred now.
- [x] Update `docs/current-state-analysis.md` when implemented — done 2026-07-06.
- [ ] Rotate/automate the `vault-auth` reviewer JWT (currently a `kubectl create token` with a 10-year duration, manually renewed).
- [ ] Add a TLS cert for the demo Ingress (443 path currently unexercised — only 80 was proven).
- [ ] Consider folding the Vault Agent Injector Helm install, and the `vault-tls-ca` Secret distribution, into the `k3s` Ansible role for full one-command re-provisioning, rather than the manual steps used here.
- [ ] `terraform/modules/vm` hardcodes DNS to `192.168.0.1` regardless of bridge, so no private-subnet VM can resolve `edge`'s dnsmasq zone (`*.lab.internal`) — a structural gap, worked around here with IP addressing. Revisit if a future slice (e.g. 0007's `pg`/`minio`) ever needs private-DNS-name resolution from a VM.
