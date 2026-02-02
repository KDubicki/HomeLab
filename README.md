# Homelab Operations - Proxmox Cloud

## 🛠 Hardware Spec
- **Host:** Dell
- **RAM:** 32GB DDR4
- **Storage OS:** 256GB SSD (SATA)
- **Storage Data:** 1TB (NVMe)

## 🌐 Network Map
- **Proxmox UI:** `https://192.168.0.102:8006`
- **Domain:** `lab.home`

## 🏗 Base Installation
- Installed Proxmox VE 9.1.1 on /dev/sda.
- Configured LVM-Thin storage `nvme-data` on 1TB.
- Updated repositories to `no-subscription`.
- Generated API Token for Terraform automation.