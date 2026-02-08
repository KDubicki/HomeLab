# Proxmox VE 9.x - Infrastructure Documentation

## 1. Operating System & Network
* **Base OS**: Debian 13 (Trixie)
* **Platform**: Proxmox VE 9.x
* **Main IP (WAN/LAN)**: `192.168.0.113`
* **Lab Network (Internal)**: `10.10.0.0/24` (via `vmbr1`)
* **VPN Subnet**: `10.99.0.0/24`
* **Web GUI**: `https://192.168.0.113:8006`

---

## 2. Network Bridges
| Bridge | IP Address | Purpose |
| :--- | :--- | :--- |
| **vmbr0** | 192.168.0.113 | Public/Home LAN Access |
| **vmbr1** | 10.10.0.1 | Isolated Lab Network |

---

## 3. Storage Infrastructure
| Storage ID | Type | Device | Content | Status |
| :--- | :--- | :--- | :--- | :--- |
| **local** | Directory | `/dev/sda3` | ISOs, Templates | Active |
| **nvme-storage** | LVM-Thin | `/dev/nvme0n1` | CT/VM Volumes | Active (Primary) |

---

## 4. Key Security Settings (Applied)
* **LXC Privileged Mode**: Enabled for VPN Gateways to allow WireGuard kernel-space operations.
* **AppArmor**: Set to `unconfined` for CT 200 to allow tun/tap access.
* **IP Forwarding**: Enabled on Host and Gateway CT.
* **UDP Checksum Offloading**: Disabled on `vmbr0` to fix WireGuard packet drops.

---

## 5. Active Managed Services
* **CT 200**: `local-gateway` (WireGuard VPN & NAT Gateway)