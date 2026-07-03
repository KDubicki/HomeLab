#!/bin/bash
# Create Ops-Node LXC container on Proxmox

CT_ID=210
HOSTNAME="ops-node"
STORAGE="nvme-storage"
BRIDGE_LAB="vmbr1"
IP_ADDR="10.10.0.10/24"
GATEWAY="10.10.0.2"
TEMPLATE="/var/lib/vz/template/cache/debian-13-standard_13.1-2_amd64.tar.zst"

echo "--- [1/3] Cleaning up existing container ID $CT_ID ---"
pct destroy $CT_ID --purge > /dev/null 2>&1

echo "--- [2/3] Creating LXC $HOSTNAME ---"
pct create $CT_ID "$TEMPLATE" \
  --hostname $HOSTNAME \
  --cores 2 \
  --memory 2048 \
  --net0 name=eth0,bridge=$BRIDGE_LAB,ip=$IP_ADDR,gw=$GATEWAY \
  --rootfs "$STORAGE:8" \
  --onboot 1 \
  --unprivileged 1 \
  --features nesting=1

if [ $? -eq 0 ]; then
    echo "--- [3/3] Starting container and verifying status ---"
    pct start $CT_ID
    echo "SUCCESS: $HOSTNAME is running at $IP_ADDR"
else
    echo "ERROR: Failed to create container."
    exit 1
fi