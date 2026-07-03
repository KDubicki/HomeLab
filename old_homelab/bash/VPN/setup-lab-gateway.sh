#!/bin/bash
# Configure CT 200 as NAT Gateway for the Lab Network

CT_GW=200
WAN_IF="eth0"
LAB_IF="eth1"
LAB_NET="10.10.0.0/24"

echo "--- [1/3] Enabling IP Forwarding on Gateway ---"
pct exec $CT_GW -- sysctl -w net.ipv4.ip_forward=1

echo "--- [2/3] Configuring Iptables NAT (Masquerade) ---"
# Flush existing NAT rules to prevent duplicates
pct exec $CT_GW -- iptables -t nat -F
pct exec $CT_GW -- iptables -t nat -A POSTROUTING -s $LAB_NET -o $WAN_IF -j MASQUERADE

echo "--- [3/3] Setting Forwarding Policies ---"
pct exec $CT_GW -- iptables -A FORWARD -i $LAB_IF -o $WAN_IF -j ACCEPT
pct exec $CT_GW -- iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

echo "SUCCESS: Lab NAT Routing is now active via $CT_GW"