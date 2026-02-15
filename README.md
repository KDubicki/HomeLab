# Homelab - Cloud Infrastructure, Networking & IaC

This project documents my home-scale cloud infrastructure based on **Proxmox VE 9.x**. It focuses on creating an automated, hybrid environment with isolated network segments, secure remote access, and Infrastructure as Code (IaC) workflows.

## 🛠 Tech Stack
- **Virtualization:** Proxmox VE 9.x (Debian 13 Trixie)
- **IaC & Automation:** Terraform, Ansible, Bash
- **Networking:** Linux Bridges (vmbr), NAT Gateway, WireGuard VPN
- **Service Discovery:** CoreDNS (LXC)
- **Hardware:** Intel Core i5-9500 | 1TB NVMe (LVM-Thin)
- **OS Templates:** Debian 13 Standard

## 🌐 Network Architecture
The infrastructure is split into three main segments to ensure security and isolation:

- **Management Layer**: Proxmox Web UI and host access via Home LAN (`192.168.0.x`).
- **Secure Access (VPN Gateway)**: A dedicated WireGuard Gateway (CT 200) providing an encrypted tunnel and NAT routing for the internal lab.
- **Isolated Lab Network**: A private `10.10.0.0/24` subnet where all services reside, routed through the Gateway and managed via internal DNS.

---

## 🚀 Infrastructure Map
| Node | ID | Internal IP | Gateway | DNS | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Gateway** | 200 | `10.10.0.2` | - | - | NAT Router & WireGuard Server |
| **DNS-Node** | 220 | `10.10.0.5` | `10.10.0.2` | `127.0.0.1` | CoreDNS Service Discovery (.lab domain) |
| **Ops-Node** | 210 | `10.10.0.10` | `10.10.0.2` | `10.10.0.5` | Central Management (Bastion Host) |

---

## 🕹️ Operations Center (Ops-Node)
The **Ops-Node (CT 210)** serves as the central management hub (Bastion Host):
- **Internal IP:** `10.10.0.10`.
- **Deployment:** Fully automated via `provision-ops-node.sh`.
- **Service Discovery:** Configured to use internal `dns-node` (`10.10.0.5`) for resolving `.lab` hostnames.
- **Tools:** Pre-installed **Terraform** and **Ansible**.
- **Connectivity:** Securely connected to GitHub via SSH Deploy Keys for GitOps workflows.
- **Routing:** All traffic is routed through the NAT Gateway (`10.10.0.2`).

## 📂 Project Structure
- **`/bash`**: Automated scripts for LXC creation, storage management (NVMe), and network configuration.
- **`/dns`**: CoreDNS configuration, `setup-coredns.sh` and `provision-dns.sh`.
- **`/terraform`**: Infrastructure definitions for Proxmox provider.
- **`/ansible`**: Playbooks for service configuration and OS hardening.

---

## ✅ Verification Commands
To verify the internal networking and DNS resolution, run these commands from the Proxmox Host:

1. **DNS Visibility**: `pct exec 220 -- ping -c 3 ops-node.lab` (resolves to `10.10.0.10`).
2. **Service Discovery**: `pct exec 210 -- ping -c 3 gateway.lab` (resolves to `10.10.0.2`).
3. **Internal Connectivity**: `pct exec 210 -- ping -c 3 dns.lab`.
4. **External Access**: `pct exec 210 -- ping -c 3 google.com`.
5. **Observability**: `pct exec 210 -- curl -I http://localhost:3001` (Check if Uptime Kuma is up).
6. **Internal DNS Resolve**: `pct exec 220 -- dig +short @127.0.0.1 status.lab`.