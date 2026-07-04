# 0004 — Private-Subnet Network (VPC Analog)

- **Status**: Implemented
- **Date proposed**: 2026-07-03
- **Date decided**: 2026-07-04
- **Date implemented**: 2026-07-04
- **Owner**: KDubicki
- **Related plans**: 0001 (foundation); depends on 0003; precedes 0005
- **Depends on**: 0003 (guests provisioned via Terraform)

## Context
Only `vmbr0` (LAN-facing, `192.168.0.113/24`) exists. The cloud-fidelity intent calls for a private subnet where backing services live unexposed to the LAN, reached through a controlled edge — the VPC + private-subnet + bastion pattern. There is **no managed switch** on the LAN, so VLAN tagging is off the table.

**Implementation status — DONE (2026-07-04):** executed and tester-verified end-to-end. `vmbr1` (no bridge-ports, `10.10.10.0/24`) and an unprivileged LXC `edge` (VMID 101, dual-homed `192.168.0.10`/`10.10.10.1`) were provisioned via a new `terraform/modules/lxc` module; `edge` runs IP forwarding + an nftables ruleset (default-deny inbound, masquerade egress) + dnsmasq (DHCP/DNS), applied by a new Ansible `edge` role. Proven with a throwaway DHCP client (`priv-test`, VMID 998) on the private subnet: internet egress worked only through `edge`'s NAT, DNS resolved via `edge`'s dnsmasq, and the guest was unreachable directly from the LAN — reachable only via `ssh -J` through the bastion. The guest was then destroyed; only `edge` persists. One real compatibility gap was found and fixed rather than papered over: the existing `baseline` Ansible role (from 0003) unconditionally enabled `qemu-guest-agent`, which is meaningless inside an LXC (no virtio-serial channel) and would have failed the play — guarded with `ansible_virtualization_type != 'lxc'`, a fix that benefits every future LXC guest (0005 Vault, 0007 Postgres/MinIO). No `nesting` feature or privileged mode was needed for NAT/forwarding in the unprivileged container, despite Terraform's own warning about newer systemd suggesting it might be.

## Decision
Build a private-subnet network:
1. Create an **internal, no-uplink Linux bridge** (e.g. `vmbr1`) as the private subnet (e.g. `10.10.0.0/24`) — no physical port, so traffic never touches the LAN directly.
2. Provision a small **edge VM/CT** dual-homed on `vmbr0` and `vmbr1`, acting as **NAT gateway + SSH bastion + DNS** for the private subnet.
3. Backing services (0005 Vault, 0007 Postgres/MinIO) and the k3s node (0006) attach to the private subnet; only the edge (and deliberately-published services) face the LAN.

## Rationale
A no-uplink bridge is the faithful single-NIC analog of a cloud private subnet: guests get outbound internet only via the edge's NAT and are unreachable from the LAN except through the bastion — exactly the security posture reviewers expect. It also rebuilds the isolation the old `vmbr1` lab had, without needing a second NIC or a managed switch. Doing it as code (Terraform provisions the edge, Ansible configures NAT/firewall) keeps the reproducibility story intact.

## Alternatives considered
| Option | Pros | Cons | Why not chosen |
| :--- | :--- | :--- | :--- |
| Flat on `vmbr0` + firewall rules | Simplest | No real subnet/bastion pattern to show | Weaker cloud-fidelity signal |
| VLAN-tagged segments | Cleanest "enterprise" segmentation | Requires a managed switch | **No managed switch available** |
| Second physical NIC | True physical isolation | Hardware not present (single onboard NIC) | Not an option on this box |

## Resource budget
- **vCPU**: edge CT ~1 (mostly idle).
- **RAM**: edge CT ~0.5 GB.
- **Storage**: edge CT rootfs ~4 GB on `local-lvm`.
- **Network**: new no-uplink bridge `vmbr1` (private `10.10.0.0/24`); edge dual-homed `vmbr0`+`vmbr1`. No VLANs, no new physical ports.

## Implementation outline
1. Define `vmbr1` (no bridge-ports) in Proxmox network config.
2. Terraform: provision the edge CT/VM dual-homed.
3. Ansible: enable IP forwarding + NAT (nftables/iptables masquerade), firewall policy (default-deny inbound from LAN, allow bastion SSH), optional dnsmasq for DHCP/DNS on the private subnet.
4. Verify: a private-subnet test guest reaches the internet only through the edge and is not reachable from the LAN except via the bastion.

## Risks & rollback
- **Locking yourself out / no egress.** Detection: test guest can't reach internet. Mitigation: keep host `vmbr0` mgmt access independent of the edge. Rollback: remove `vmbr1` / edge; guests fall back to `vmbr0`.
- **NAT/firewall misconfig exposing services.** Detection: reachability tests from the LAN. Mitigation: default-deny, explicit allows.

## Portfolio framing
Demonstrates private-subnet segmentation with a NAT/bastion edge on a single NIC — the VPC pattern realized without VLAN hardware. Does not claim physical network isolation or redundant routing.

## Follow-ups
- [ ] Document the network topology (diagram) in `docs/`.
- [x] Update `docs/current-state-analysis.md` and `docs/hardware.md` (network section) when implemented — done 2026-07-04.
