#!/bin/bash

# Proxmox NVMe Storage Setup Script
# Target disk: /dev/nvme0n1
# This script initializes LVM-Thin for virtual machines.

echo "Initializing NVMe storage on /dev/nvme0n1..."

# 1. Create Physical Volume (PV)
# This labels the disk for LVM use.
echo "Creating Physical Volume..."
pvcreate /dev/nvme0n1

# 2. Create Volume Group (VG)
# Named 'vg_nvme' as per your command history.
echo "Creating Volume Group: vg_nvme..."
vgcreate vg_nvme /dev/nvme0n1

# 3. Create Thin Pool (TP)
# Named 'tp_nvme', using 100% of the free space.
echo "Creating Thin Pool: tp_nvme..."
lvcreate -l 100%FREE --thinpool tp_nvme vg_nvme

# 4. Register storage in Proxmox
# This adds the storage to the web interface as 'nvme-storage'.
echo "Adding 'nvme-storage' to Proxmox configuration..."
pvesm add lvmthin nvme-storage --vgname vg_nvme --thinpool tp_nvme --content rootdir,images

echo "-------------------------------------------------------"
echo "Success! Storage 'nvme-storage' is now ready."
echo "Check your Proxmox GUI to start using it."
echo "-------------------------------------------------------"

# Show final status
pvesm status