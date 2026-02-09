# Homelab - Cloud Infrastructure, Networking & IaC

This project documents my home-scale cloud infrastructure based on **Proxmox VE 9.x**. It focuses on creating an automated, hybrid environment with isolated network segments, secure remote access, and Infrastructure as Code (IaC) workflows.

## 🛠 Tech Stack
- **Virtualization:** Proxmox VE 9.x (Debian 13 Trixie)
- **IaC & Automation:** Terraform, Ansible, Bash
- **Networking:** Linux Bridges (vmbr), NAT Gateway, WireGuard VPN
- **Hardware:** Intel Core i5-9500 | 1TB NVMe (LVM-Thin)
- **OS Templates:** Debian 13 Standard

## 🌐 Network Architecture
The infrastructure is split into three main segments to ensure security and isolation:

- **Management Layer**: Proxmox Web UI and host access via Home LAN (`192.168.0.x`).
- **Secure Access (VPN Gateway)**: A dedicated WireGuard Gateway (CT 200) providing an encrypted tunnel and NAT routing for the internal lab.
- **Isolated Lab Network**: A private `10.10.0.0/24` subnet where all services reside, routed through the Gateway.


## 🚀 Infrastructure Map
| Segment | Network Range | Gateway | Description |
| :--- | :--- | :--- | :--- |
| **Management** | `192.168.0.x` | Router IP | Host management & GUI access |
| **VPN Tunnel** | `10.99.0.x` | - | Secure remote client access (WireGuard) |
| **Isolated Lab** | `10.10.0.x` | `10.10.0.2` | Private environment for services |

## 🕹️ Operations Center (Ops-Node)
The **Ops-Node (CT 210)** serves as the central management hub (Bastion Host):
- **Deployment:** Fully automated via `provision-ops-node.sh`.
- **Tools:** Pre-installed **Terraform** and **Ansible**.
- **Connectivity:** Securely connected to GitHub via SSH Deploy Keys for GitOps workflows.
- **Routing:** All traffic is routed through the NAT Gateway (`10.10.0.2`).

## 📂 Project Structure
- **`/bash`**: Automated scripts for LXC creation, storage management (NVMe), and network configuration.
- **`/terraform`**: Infrastructure definitions for Proxmox provider.
- **`/ansible`**: Playbooks for service configuration and OS hardening.