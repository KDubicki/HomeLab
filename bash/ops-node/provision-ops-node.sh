#!/bin/bash
# Ops-Node provisioning (IaC tools & Locales)

CT_ID=210

echo "--- [1/5] Configuring DNS & System Locales ---"
pct exec $CT_ID -- bash -c "echo -e 'nameserver 8.8.8.8\nnameserver 1.1.1.1' > /etc/resolv.conf"
pct exec $CT_ID -- apt update && pct exec $CT_ID -- apt install -y locales
pct exec $CT_ID -- sed -i '/en_US.UTF-8 UTF-8/s/^# //' /etc/locale.gen
pct exec $CT_ID -- locale-gen
pct exec $CT_ID -- update-locale LANG=en_US.UTF-8

echo "--- [2/5] Installing base dependencies ---"
pct exec $CT_ID -- apt install -y curl gpg unzip git python3-pip sshpass

echo "--- [3/5] Installing HashiCorp Terraform ---"
pct exec $CT_ID -- bash -c "curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg"
pct exec $CT_ID -- bash -c "echo 'deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com trixie main' | tee /etc/apt/sources.list.d/hashicorp.list"
pct exec $CT_ID -- apt update && pct exec $CT_ID -- apt install -y terraform

echo "--- [4/5] Installing Ansible ---"
pct exec $CT_ID -- apt install -y ansible

echo "--- [5/5] Creating workspace structure ---"
pct exec $CT_ID -- mkdir -p /root/infrastructure/{terraform,ansible,bash}

echo "--- Provisioning Complete ---"
pct exec $CT_ID -- terraform -version | head -n1
pct exec $CT_ID -- bash -c "export LANG=en_US.UTF-8; ansible --version | head -n1"