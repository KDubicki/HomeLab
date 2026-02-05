#!/bin/bash
set -e

echo "Updating repositories..."
apt-get update

echo "Installing SDN and DHCP components..."
apt-get install -y ifupdown2 dnsmasq

echo "Disabling default dnsmasq..."
systemctl disable --now dnsmasq

echo "SDN Preparation Complete."