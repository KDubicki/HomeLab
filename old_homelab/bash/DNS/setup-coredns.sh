#!/bin/bash
# Internal CoreDNS installation & config

set -e

VERSION="1.11.1"
COREDNS_DIR="/etc/coredns"

echo "Installing system dependencies..."
apt-get update && apt-get install -y curl ca-certificates

echo "Downloading CoreDNS binary..."
curl -L "https://github.com/coredns/coredns/releases/download/v${VERSION}/coredns_${VERSION}_linux_amd64.tgz" | tar xz
mv coredns /usr/local/bin/coredns
chmod +x /usr/local/bin/coredns

mkdir -p "$COREDNS_DIR"

echo "Generating Corefile with Lab Network mappings..."
cat <<EOF > "$COREDNS_DIR/Corefile"
. {
    log
    errors
    hosts {
        10.10.0.2   gateway.lab
        10.10.0.10  ops-node.lab
        10.10.0.5   dns.lab
        fallthrough
    }
    # Forwarding to public DNS via NAT Gateway
    forward . 1.1.1.1 8.8.8.8
    cache 30
}
EOF

echo "Creating systemd service..."
cat <<EOF > /etc/systemd/system/coredns.service
[Unit]
Description=CoreDNS Service (HomeLab Service Discovery)
After=network.target

[Service]
PermissionsStartOnly=true
LimitNOFILE=1048576
ExecStart=/usr/local/bin/coredns -conf $COREDNS_DIR/Corefile
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now coredns
echo "CoreDNS is now active."