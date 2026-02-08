#!/bin/bash

# Proxmox Post-Installation Setup Script for Debian 13 (Trixie)
# This script configures repositories and performs a full system upgrade.

echo "Starting Proxmox configuration for Debian 13 (Trixie)..."

# 1. Clean up existing repository files to avoid conflicts and 401 errors
echo "Cleaning up existing repository configurations..."
# Removing old .list files
rm -f /etc/apt/sources.list.d/pve-enterprise.list
rm -f /etc/apt/sources.list.d/ceph.list
rm -f /etc/apt/sources.list.d/pve-no-sub.list
# Removing the new DEB822 format file to avoid duplication warnings
rm -f /etc/apt/sources.list.d/debian.sources
# Final wipe of the directory to ensure a clean state
rm -f /etc/apt/sources.list.d/*

# 2. Create a clean, unified sources.list
echo "Configuring the main sources.list file..."
# Recreating sources.list with the correct Trixie repositories
cat <<EOF > /etc/apt/sources.list
deb http://deb.debian.org/debian trixie main contrib non-free non-free-firmware
deb http://deb.debian.org/debian trixie-updates main contrib non-free non-free-firmware
deb http://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware

# Proxmox No-Subscription Repository
deb http://download.proxmox.com/debian/pve trixie pve-no-subscription
EOF

# 3. Update package database and perform distribution upgrade
echo "Updating package database..."
apt update

echo "Performing system distribution upgrade..."
# Running the upgrade
apt dist-upgrade -y

# 4. Restart services
echo "Restarting Proxmox proxy service..."
systemctl restart pveproxy

# 5. Verify status
echo "Checking service status..."
systemctl status pveproxy --no-pager

echo "-------------------------------------------------------"
echo "Setup complete! Your Proxmox is now using No-Subscription"
echo "repositories and is fully up to date."
echo "-------------------------------------------------------"