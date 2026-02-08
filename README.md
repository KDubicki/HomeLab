# Homelab - Cloud Infrastructure & Networking

This project documents my home-scale cloud infrastructure based on **Proxmox VE 9.x**. It focuses on creating an automated, hybrid environment with isolated network segments and secure remote access.

## 🛠 Tech Stack
- **Virtualization:** Proxmox VE 9.x (Debian 13 Trixie)
- **Networking:** Linux Bridges (vmbr), NAT Gateway, WireGuard VPN
- **Storage:** LVM-Thin on NVMe (1TB)
- **OS Templates:** Debian 13 Standard

## 🌐 Network Architecture
The infrastructure is split into three main segments to ensure security and isolation:

- **Management Layer**: Proxmox Web UI and host access via Home LAN.
- **Secure Access (VPN)**: A dedicated WireGuard Gateway providing an encrypted tunnel into the private lab.
- **Isolated Lab Network**: A private `10.10.0.0/24` subnet for virtual machines and containers, inaccessible from the outside.

## 🚀 Infrastructure Map
| Segment | Network Range | Description |
| :--- | :--- | :--- |
| **Management** | `192.168.0.x` | Host management & GUI access |
| **VPN Tunnel** | `10.99.0.x` | Secure remote client access |
| **Isolated Lab** | `10.10.0.x` | Environment for services |

## 📂 Project Structure
- **/scripts**: Automated Bash tools for storage management (NVMe/LVM) and gateway deployment.
- **/docs**: Network maps and infrastructure documentation.
