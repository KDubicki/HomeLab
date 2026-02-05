#!/bin/bash

set -e

NODE_NAME=$(hostname)

echo "Cleaning up existing configuration if present..."
pvesh delete /cluster/sdn/vnets/vnet1/subnets/10.0.1.0-24 2>/dev/null || true
pvesh delete /cluster/sdn/vnets/vnet1 2>/dev/null || true
pvesh delete /cluster/sdn/zones/vnetlab 2>/dev/null || true

echo "Creating SDN Zone (vnetlab) for node $NODE_NAME..."
pvesh create /cluster/sdn/zones --zone vnetlab --type simple --dhcp dnsmasq --ipam pve --nodes "$NODE_NAME"

echo "Creating VNet (vnet1)..."
pvesh create /cluster/sdn/vnets --vnet vnet1 --zone vnetlab

echo "Creating Subnet (10.0.1.0/24)..."
# Added --type subnet to fix 'property is missing' error
pvesh create /cluster/sdn/vnets/vnet1/subnets --subnet 10.0.1.0/24 --type subnet --gateway 10.0.1.1 --snat 1

echo "Applying SDN configuration..."
pvesh set /cluster/sdn

echo "Forcing network interface generation..."
ifreload -a
ifup vnet1 || echo "vnet1 is initializing..."

echo "SDN configuration applied successfully."
echo "Verification: brctl show | grep vnet1"
brctl show | grep vnet1