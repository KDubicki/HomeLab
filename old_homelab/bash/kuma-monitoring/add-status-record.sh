#!/bin/bash
# Inject DNS record into DNS-Node

DNS_CT_ID=220
OPS_NODE_IP="10.10.0.10"
COREFILE="/etc/coredns/Corefile"
RECORD="$OPS_NODE_IP status.lab"

echo "--- Starting DNS update for status.lab ---"

# 1. Check if container is running
if ! pct status $DNS_CT_ID | grep -q "status: running"; then
    echo "Error: DNS-Node ($DNS_CT_ID) is not running."
    exit 1
fi

# 2. Clean up any previous incorrect formats and add the correct one
pct exec $DNS_CT_ID -- bash -c "
    # Remove old incorrect BIND-style record if exists
    sed -i '/status.lab IN A/d' '$COREFILE'

    # Check if correct record already exists
    if grep -q '$RECORD' '$COREFILE'; then
        echo 'Record already exists in correct format.'
    else
        # Add record right after 'hosts {' line
        sed -i '/hosts {/a \        $RECORD' '$COREFILE'
        echo 'Record added: $RECORD'

        echo '--- Restarting CoreDNS ---'
        systemctl restart coredns
    fi
"

echo "--- Final Verification ---"
pct exec $DNS_CT_ID -- dig +short @127.0.0.1 status.lab