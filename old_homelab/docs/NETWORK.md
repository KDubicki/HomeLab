# Network Topology & Routing

## 1. Physical Layer (Proxmox Host)
- **Interface:** `eth0` (Physical NIC)
- **Bridge (vmbr0):** External Access | `192.168.0.113`
- **Bridge (vmbr1):** Isolated Lab | No Host IP (Managed by Gateway)

## 2. Logical Segmentation
| Zone | CIDR | Purpose | Gateway |
| :--- | :--- | :--- | :--- |
| **Management** | `192.168.0.x/24` | Proxmox Web UI / Host Access | Home Router |
| **Lab Internal** | `10.10.0.0/24` | Internal Services (LXC) | `10.10.0.2`
| **VPN Overlay** | `10.99.0.0/24` | Remote Secure Access | `10.99.0.1`

## 3. Traffic Flow
1. **Internal:** Service A (`.10`) -> Service B (`.5`) via `vmbr1`.
2. **External:** Lab Node -> Gateway (`.2`) -> NAT (`vmbr0`) -> Internet.
3. **Remote:** WireGuard Client -> Port `51820` -> Gateway (`.2`) -> Lab Network.