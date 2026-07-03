#!/bin/bash
# Create Privileged Gateway Container

CT_ID="200"
CT_NAME="local-gateway"
STORAGE="nvme-storage"
TEMPLATE="local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"

echo "--- Cleaning up old configuration ---"
pct stop $CT_ID 2>/dev/null
pct destroy $CT_ID 2>/dev/null

echo "--- Creating Container $CT_ID (Privileged) ---"
# unprivileged 0 is crucial for VPN performance in LXC
pct create $CT_ID $TEMPLATE \
    --hostname $CT_NAME \
    --arch amd64 \
    --storage $STORAGE \
    --rootfs $STORAGE:8 \
    --unprivileged 0 \
    --features nesting=1 \
    --onboot 1

echo "--- Setting up Networking ---"
# eth0: Home LAN (vmbr0) | eth1: LAB (vmbr1)
pct set $CT_ID --net0 name=eth0,bridge=vmbr0,ip=192.168.0.200/24,gw=192.168.0.1,firewall=0
pct set $CT_ID --net1 name=eth1,bridge=vmbr1,ip=10.10.0.2/24

echo "--- Setting Special Permissions ---"
CONF_FILE="/etc/pve/lxc/${CT_ID}.conf"
cat <<EOF >> $CONF_FILE
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF

echo "--- Starting Container & Optimizing Kernel ---"
pct start $CT_ID
sleep 2
pct exec $CT_ID -- sysctl -w net.ipv4.ip_forward=1
pct exec $CT_ID -- sysctl -w net.ipv4.conf.all.rp_filter=0