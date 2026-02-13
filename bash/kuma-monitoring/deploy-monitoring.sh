#!/bin/bash
# Deploy Uptime Kuma monitoring on Ops-Node (CT 210)

set -e

echo "--- Updating system packages ---"
apt-get update && apt-get install -y curl ca-certificates

# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "--- Installing Docker Engine ---"
    curl -fsSL https://get.docker.com | sh
fi

echo "--- Deploying Uptime Kuma Container ---"
# Using a persistent volume for cloud-native data management
docker run -d \
  --name uptime-kuma \
  --restart always \
  --publish 3001:3001 \
  --volume uptime-kuma-data:/app/data \
  louislam/uptime-kuma:1

echo "--- Deployment Complete ---"
echo "Service available at: http://10.10.0.10:3001"