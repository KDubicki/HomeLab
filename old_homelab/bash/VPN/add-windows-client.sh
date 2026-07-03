#!/bin/bash
# Client Generator

CT_ID="200"
CLIENT_CONF="/home/root/script/VPN/windows_client.conf"

echo "--- Generating Client Keys ---"
CLIENT_PRIV_KEY=$(pct exec $CT_ID -- wg genkey)
CLIENT_PUB_KEY=$(echo "$CLIENT_PRIV_KEY" | pct exec $CT_ID -- wg pubkey)
SERVER_PUB_KEY=$(pct exec $CT_ID -- cat /etc/wireguard/publickey)

echo "--- Registering Client on Server ---"
pct exec $CT_ID -- bash -c "cat <<EOF >> /etc/wireguard/wg0.conf

[Peer]
PublicKey = $CLIENT_PUB_KEY
AllowedIPs = 10.99.0.2/32
EOF"

# Immediate activation without server restart
pct exec $CT_ID -- wg set wg0 peer "$CLIENT_PUB_KEY" allowed-ips 10.99.0.2/32

echo "--- Generating Windows Configuration File ---"
cat <<EOF > $CLIENT_CONF
[Interface]
PrivateKey = $CLIENT_PRIV_KEY
Address = 10.99.0.2/24
DNS = 1.1.1.1

[Peer]
PublicKey = $SERVER_PUB_KEY
Endpoint = 192.168.0.200:51820
AllowedIPs = 10.10.0.0/24, 10.99.0.0/24
# Keeps tunnel open through NAT/Firewalls
PersistentKeepalive = 25
EOF

echo "--------------------------------------------------------------"
echo "DONE! Copy the content of $CLIENT_CONF"
echo "and save it on Windows as 'homelab.conf'."
echo "--------------------------------------------------------------"
cat $CLIENT_CONF