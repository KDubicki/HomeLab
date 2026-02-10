# DNS-Node Configuration & Service Discovery

## 1. Overview
**DNS-Node (CT 220)** is the central service discovery provider for the isolated Lab Network (`10.10.0.0/24`). It runs **CoreDNS** to provide internal hostname resolution for the `.lab` domain, allowing nodes to communicate without hardcoded IP addresses.

## 2. Technical Stack
- **OS**: Debian 13 (Standard Template)
- **DNS Software**: CoreDNS v1.11.1
- **Configuration**: Managed via `Corefile`
- **Deployment**: Automated via `dns/provision-dns.sh` and `dns/setup-coredns.sh`

## 3. Connectivity & Configuration
- **Internal IP**: `10.10.0.5`
- **Gateway**: `10.10.0.2` (NAT Gateway)
- **Local Resolver**: `127.0.0.1` (Self-referencing for `.lab` resolution)
- **Upstream Forwarders**: `1.1.1.1`, `8.8.8.8` (For external resolution)

### Corefile Structure
The service is configured to log queries, handle errors, and serve a static `hosts` block before falling through to external forwarders.

## 4. DNS Records (Static Mapping)
The following authoritative A-records are defined for the internal environment:

| Hostname | IP Address | Description |
| :--- | :--- | :--- |
| `gateway.lab` | `10.10.0.2` | NAT & WireGuard Gateway |
| `dns.lab` | `10.10.0.5` | Internal CoreDNS Server |
| `ops-node.lab` | `10.10.0.10` | Central Management Node |

---

## 5. Maintenance & Verification
### Service Management
- **Check Status**: `systemctl status coredns`
- **Restart Service**: `systemctl restart coredns`
- **Edit Records**: `nano /etc/coredns/Corefile`

### Verification Commands
Run these from the Proxmox Host to ensure the service is responding correctly:
- **Internal Resolution Test**:
  `pct exec 220 -- dig @127.0.0.1 ops-node.lab`
- **Connectivity Test**:
  `pct exec 220 -- ping -c 3 ops-node.lab` (Should return `10.10.0.10`)

## 6. Client Integration
To configure a new container to use this DNS service, execute the following on the Proxmox Host:
```bash
pct set <CT_ID> --nameserver 10.10.0.5 --searchdomain lab