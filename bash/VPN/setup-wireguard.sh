#!/bin/bash
# Install & Configure VPN Server

CT_ID="200"

echo "--- Installing Tools in Container ---"
pct exec $CT_ID -- apt update
pct exec $CT_ID -- apt install -y wireguard wireguard-tools iptables

echo "--- Generating Server Keys ---"
pct exec $CT_ID -- bash -c "mkdir -p /etc/wireguard && cd /etc/wireguard && wg genkey | tee privatekey | wg pubkey > publickey"

PRIV_KEY=$(pct exec $CT_ID -- cat /etc/wireguard/privatekey)

echo "--- Creating wg0.conf with NAT to 10.10.x.x ---"
pct exec $CT_ID -- bash -c "cat <<EOF > /etc/wireguard/wg0.conf
[Interface]
PrivateKey = $PRIV_KEY
Address = 10.99.0.1/24
ListenPort = 51820

# Forwarding rules to LAB network
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth1 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth1 -j MASQUERADE
EOF"

echo "--- Starting WireGuard Service ---"
pct exec $CT_ID -- systemctl enable --now wg-quick@wg0