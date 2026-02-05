# 3: Automation & Proxmox API (Bash Setup)

## Objective
Automating the Proxmox node preparation and configuring advanced Software-Defined Networking (SDN) using shell scripts and the `pvesh` utility.

## Tasks Completed (Day 4)

### 1. System Preparation (Host)
* Installed `ifupdown2` and `dnsmasq` packages required for SDN functionality.
* Disabled the default system `dnsmasq` service to prevent conflicts with SDN-managed DHCP instances.

### 2. SDN Configuration via API
* Implemented the `configure_sdn_api.sh` script to automate network provisioning via the `pvesh` API.
* Created the `vnetlab` zone (simple type) and the `vnet1` virtual network.
* Defined the `10.0.1.0/24` subnet with **SNAT** enabled, allowing isolated VMs to reach the internet.

### 3. Network State Management
* Implemented a network reload trigger using `ifreload -a` to activate the `vnet1` bridge without a host reboot.
* Verified the operational state of the `dnsmasq` process assigned to the `vnetlab` zone.

## Technical Details
* **Tools**: `pvesh`, `ifupdown2`, `brctl`.
* **Config Location**: `/etc/network/interfaces.d/sdn`.
* **Outcome**: Fully automated L2/L3 isolation for the lab environment.

---
**Git Commit:** `feat(bash): automate sdn zone and vnet creation via pvesh api`