# WireGuard VPN Architecture & Management

## 1. Overview
This VPN provides secure remote access to the isolated Lab Network (`10.10.0.0/24`) hosted on Proxmox. It uses a **Privileged LXC Container (ID: 200)** as a gateway between the Home LAN and the Lab.

## 2. Technical Specifications
* **Protocol**: WireGuard (UDP)
* **Listen Port**: `51820`
* **VPN Gateway IP**: `10.99.0.1` (Internal)
* **NAT Interface**: `eth1` (Connects to `vmbr1`)

## 3. Client Configuration Standards
Every Windows client must use these settings to ensure connectivity:
* **AllowedIPs**: `10.99.0.0/24, 10.10.0.0/24` (Routes both VPN and Lab traffic)
* **PersistentKeepalive**: `25` (Prevents NAT timeouts)

## 4. Troubleshooting Checklist
If "Handshake" occurs but "Received" is 0:
1. Ensure **Windows Firewall** allows UDP 51820.
2. Check if **rp_filter** is disabled on Proxmox Host:
   `sysctl net.ipv4.conf.all.rp_filter` (Should be 0)
3. Verify if **Offloading** is disabled on Host:
   `ethtool -K vmbr0 tx off rx off`

## 5. Management Commands
* **Show VPN Status**: `pct exec 200 -- wg show`
* **Restart VPN**: `pct exec 200 -- systemctl restart wg-quick@wg0`
* **Add New Client**: Run `./add-windows-client.sh <name>`