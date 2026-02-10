# WireGuard VPN Architecture & Management

## 1. Overview
This VPN provides secure remote access to the isolated Lab Network (`10.10.0.0/24`) hosted on Proxmox. It uses a **Privileged LXC Container (ID: 200)** as a gateway between the Home LAN and the Lab environment.

## 2. Technical Specifications
* **Protocol**: WireGuard (UDP)
* **Listen Port**: `51820`
* **VPN Gateway IP**: `10.99.0.1` (Internal VPN tunnel IP)
* **WAN Interface**: `eth0` (Connects to `vmbr0`)
* **LAB Interface**: `eth1` (Connects to `vmbr1`)
* **Routing Policy**: MASQUERADE on `eth0` for `10.10.0.0/24` traffic

## 3. Client Configuration Standards
Every Windows or mobile client must use these settings to ensure full connectivity and name resolution:
* **DNS**: `10.10.0.5` (Points to internal CoreDNS for resolving `.lab` hostnames)
* **AllowedIPs**: `10.99.0.0/24, 10.10.0.0/24` (Routes both VPN and Lab traffic through the tunnel)
* **PersistentKeepalive**: `25` (Prevents NAT timeouts and keeps the tunnel active)

## 4. Troubleshooting Checklist
If a "Handshake" occurs but "Received" data remains at 0:
1. Ensure **Windows Firewall** (or local router) allows UDP traffic on port 51820.
2. Check if **rp_filter** is disabled on the Proxmox Host:
   `sysctl net.ipv4.conf.all.rp_filter` (Must be 0)
3. Verify if **Offloading** is disabled on the Host to prevent packet drops:
   `ethtool -K vmbr0 tx off rx off`
4. **DNS Issues**: If you can ping `10.10.0.10` but not `ops-node.lab`, verify the client is using `10.10.0.5` as its DNS server.

## 5. Management Commands
* **Show VPN Status**: `pct exec 200 -- wg show`
* **Restart VPN Service**: `pct exec 200 -- systemctl restart wg-quick@wg0`
* **Add New Client**: Run the local helper script: `./add-windows-client.sh <name>`