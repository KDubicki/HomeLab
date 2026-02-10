#!/bin/bash
# Provision CoreDNS LXC Container
# Isolated Lab Segment (10.10.0.5)

set -e

# Configuration
CT_ID=220
HOSTNAME="dns-node"
TEMPLATE="local:vztmpl/debian-13-standard_13.1-2_amd64.tar.zst"
STORAGE="local-lvm"
BRIDGE="vmbr1"
IP_ADDR="10.10.0.5/24"
GATEWAY="10.10.0.2"

echo "Checking if container $CT_ID exists..."
if pct status $CT_ID >/dev/null 2>&1; then
    echo "Error: Container $CT_ID already exists."
    exit 1
fi

echo "Creating LXC Container: $HOSTNAME using $TEMPLATE..."
pct create $CT_ID "$TEMPLATE" \
    --hostname "$HOSTNAME" \
    --net0 name=eth0,bridge="$BRIDGE",ip="$IP_ADDR",gw="$GATEWAY" \
    --storage "$STORAGE" \
    --unprivileged 1 \
    --features nesting=1 \
    --start 1

echo "Waiting for network initialization (5s)..."
sleep 5

# Pushing the setup script
echo "Deploying CoreDNS configuration..."
pct push $CT_ID dns/setup-coredns.sh /tmp/setup-coredns.sh
pct exec $CT_ID -- chmod +x /tmp/setup-coredns.sh
pct exec $CT_ID -- /tmp/setup-coredns.sh

echo "SUCCESS: DNS Node is up at $IP_ADDR"