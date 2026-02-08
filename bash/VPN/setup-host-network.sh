#!/bin/bash
# Host Bridge & IP Forwarding Configuration

echo "--- Configuring vmbr1 in /etc/network/interfaces ---"
# Check if interface exists to avoid duplicates
if ! grep -q "vmbr1" /etc/network/interfaces; then
cat <<EOF >> /etc/network/interfaces

auto vmbr1
iface vmbr1 inet static
    address 10.10.0.1/24
    bridge-ports none
    bridge-stp off
    bridge-fd 0
    post-up echo 1 > /proc/sys/net/ipv4/ip_forward
EOF
    echo "--- Activating vmbr1 ---"
    ifup vmbr1
else
    echo "--- vmbr1 already exists, skipping ---"
fi

# Essential for Proxmox 9: Disable rp_filter on host
echo "--- Optimizing Kernel Network Filters ---"
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.all.rp_filter=0
sysctl -w net.ipv4.conf.default.rp_filter=0