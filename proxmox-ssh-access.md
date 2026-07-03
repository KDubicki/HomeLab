# Proxmox SSH Key Access Setup

## 1. Overview
After a fresh Proxmox VE install (or reinstall), root SSH login uses password authentication by default. This guide covers generating a dedicated SSH key pair and enabling key-based login to the host at `192.168.0.113`.

## 2. Generate a Dedicated Key Pair
Run on your local machine (not on Proxmox):
```bash
ssh-keygen -t ed25519 -C "proxmox-homelab" -f ~/.ssh/id_ed25519_proxmox
```
- `-f` gives it a distinct filename so it doesn't collide with other keys (e.g. GitHub).
- Passphrase is optional; leave empty for unattended/automation use, or set one for extra protection.

This creates:
- `~/.ssh/id_ed25519_proxmox` — private key (never share)
- `~/.ssh/id_ed25519_proxmox.pub` — public key (safe to copy to servers)

## 3. Copy the Public Key to Proxmox
```bash
ssh-copy-id -i ~/.ssh/id_ed25519_proxmox.pub root@192.168.0.113
```
Enter the root password (set during install) when prompted. This appends the key to `/root/.ssh/authorized_keys` on the host.

### If the host was reinstalled
A reinstall generates new SSH host keys, so your local `known_hosts` entry for `192.168.0.113` will no longer match, causing a `REMOTE HOST IDENTIFICATION HAS CHANGED` warning. If you're certain it's your own freshly reinstalled host (not a MITM), clear the stale entry before retrying:
```bash
ssh-keygen -R 192.168.0.113
```

## 4. Add a Convenience Host Entry
Add to `~/.ssh/config` on your local machine:
```
Host proxmox
  HostName 192.168.0.113
  User root
  IdentityFile ~/.ssh/id_ed25519_proxmox
```
This allows connecting with just:
```bash
ssh proxmox
```

## 5. Verify Key-Based Login
```bash
ssh proxmox
```
Should log in without a password prompt.

## 6. (Recommended) Disable Password Authentication
Once key-based login is confirmed working, harden SSH access on the Proxmox host by editing `/etc/ssh/sshd_config`:
```
PermitRootLogin prohibit-password
```
Then restart the SSH daemon:
```bash
systemctl restart sshd
```
This keeps key-based root login working while blocking password-based login attempts.
