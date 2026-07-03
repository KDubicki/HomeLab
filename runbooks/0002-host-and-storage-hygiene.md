# Runbook 0002 — Host & Storage Hygiene

- **Implements**: change-plan/0002
- **Status**: Validated
- **Prerequisites**: none (first slice)
- **Owner**: KDubicki

## Validation
- **Verdict**: PASS
- **Validated**: 2026-07-03
- **Cumulative budget after this slice**: 0 vCPU / 0 GB RAM in guests; adds the `ssd-data` pool (~230 GB usable) on `/dev/sda`. No other Accepted/Implemented slice yet — within ceiling.
- **Conditions**: N/A
- **Conventions allocated**: none new — uses `ssd-data`, `terraform@pve!provider`, role `TerraformProv`, all already pinned in `docs/platform-conventions.md`.

## Goal
After this runbook the node has: a dedicated **`ssd-data`** storage pool for stateful data (reclaimed from the orphaned 256 GB SSD), a least-privilege **`terraform@pve`** API identity for IaC, and an up-to-date host on the no-subscription repo. Nothing is provisioned yet — this is the foundation 0003 builds on.

> ⚠️ This runbook **wipes a disk**. Do every **Verify**. The target is the 256 GB **SATA SSD** `/dev/sda` (model Crucial/Micron), **not** the NVMe `/dev/nvme0n1`.

## Conventions used
From `docs/platform-conventions.md`:
- **Storage**: new pool `ssd-data` — lvmthin on `/dev/sda` (256 GB SATA SSD), content `images,rootdir`.
- **Host**: `192.168.0.113`, reached as `ssh proxmox` (root, key `~/.ssh/id_ed25519_proxmox`).
- **Account**: `terraform@pve`, token id `provider`, custom role `TerraformProv`.

## Steps
All commands run on the Proxmox host via `ssh proxmox` unless noted.

### Step 1 — Connect and snapshot the current state
```
you@ws:~$ ssh proxmox
root@pve:~# lsblk -o NAME,SIZE,TYPE,MODEL,MOUNTPOINT
root@pve:~# pvs; vgs; lvs
root@pve:~# pvesm status
```
**Verify:** `sda` shows ~238 G with VG `pve-OLD-B195BA60`; `nvme0n1` carries `pve` (root/swap/data). Note the PV device of the old VG from `pvs` (e.g. `sda3`). If `sda` is not the old SSD, **stop** and re-read `docs/hardware.md`.

### Step 2 — Confirm the old VG is inactive and unreferenced
```
root@pve:~# grep -i sda /etc/pve/storage.cfg /etc/fstab || echo "not referenced (good)"
root@pve:~# lvs -o lv_name,vg_name,lv_active pve-OLD-B195BA60
root@pve:~# mount | grep sda || echo "nothing mounted from sda (good)"
```
**Verify:** `sda` is not in `storage.cfg` or `fstab`; the only LV is the dead `vm-220-disk-0`; nothing is mounted from it.

### Step 3 — Destroy the old volume group and wipe the disk
```
root@pve:~# vgchange -an pve-OLD-B195BA60
root@pve:~# vgremove -y pve-OLD-B195BA60
root@pve:~# pvremove -y $(pvs --noheadings -o pv_name -S vg_name=pve-OLD-B195BA60 2>/dev/null) 2>/dev/null; true
root@pve:~# wipefs -a /dev/sda
root@pve:~# sgdisk --zap-all /dev/sda 2>/dev/null; true
```
**Verify:**
```
root@pve:~# vgs             # pve-OLD-B195BA60 is gone
root@pve:~# lsblk /dev/sda  # sda has no children/partitions
```

### Step 4 — Create the `ssd-data` LVM-thin pool
```
root@pve:~# pvcreate /dev/sda
root@pve:~# vgcreate ssd-data /dev/sda
root@pve:~# lvcreate -l 98%FREE -T ssd-data/data      # thin pool "data" (2% left for metadata growth)
root@pve:~# pvesm add lvmthin ssd-data --vgname ssd-data --thinpool data --content images,rootdir
```
**Verify:**
```
root@pve:~# pvesm status
```
`ssd-data` appears as `lvmthin`, ~230 G, active. If `lvcreate` complains about metadata size, retry with `-L 230G -T ssd-data/data`.

### Step 5 — Create the Terraform API role, user, and token
```
root@pve:~# pveum role add TerraformProv -privs "Datastore.AllocateSpace Datastore.AllocateTemplate Datastore.Audit Pool.Allocate Sys.Audit Sys.Console Sys.Modify VM.Allocate VM.Audit VM.Clone VM.Config.CDROM VM.Config.CPU VM.Config.Cloudinit VM.Config.Disk VM.Config.HWType VM.Config.Memory VM.Config.Network VM.Config.Options VM.Migrate VM.Monitor VM.PowerMgmt SDN.Use"
root@pve:~# pveum user add terraform@pve
root@pve:~# pveum aclmod / -user terraform@pve -role TerraformProv
root@pve:~# pveum user token add terraform@pve provider --privsep 0
```
**Verify & capture:** the last command prints a table with `value` = the token secret. **Copy it now — it is shown only once.** It goes into `terraform/secrets.auto.tfvars` in runbook 0003. Full token id: `terraform@pve!provider`.

### Step 6 — Host hygiene: repos and updates
```
root@pve:~# test -f /etc/apt/sources.list.d/pve-enterprise.sources && sed -i 's/^Enabled: true/Enabled: false/' /etc/apt/sources.list.d/pve-enterprise.sources
root@pve:~# cat > /etc/apt/sources.list.d/pve-no-subscription.sources <<'EOF'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
EOF
root@pve:~# apt update && apt -y full-upgrade
root@pve:~# [ -e /var/run/reboot-required ] && echo "REBOOT NEEDED" || echo "no reboot needed"
```
Reboot only if a new kernel was installed (`reboot`, then reconnect).

**Verify (whole slice):**
```
root@pve:~# pvesm status | grep -E 'local|ssd-data'
root@pve:~# pveum user list | grep terraform
root@pve:~# pveum role list | grep TerraformProv
```

## Definition of Done
- [ ] `pve-OLD-B195BA60` gone; `/dev/sda` clean.
- [ ] `ssd-data` lvmthin pool active in `pvesm status`.
- [ ] `terraform@pve` user + `provider` token exist; secret saved offline.
- [ ] No-subscription repo enabled; host fully updated.

## Rollback
- Storage: `pvesm remove ssd-data; lvremove -y ssd-data/data; vgremove -y ssd-data; pvremove /dev/sda`. (Old VG contents were dead — no restore needed.)
- API identity: `pveum user token remove terraform@pve provider; pveum user delete terraform@pve; pveum role delete TerraformProv`.

## Extensibility / Further development
- **Idempotency**: pool creation and disk wipe are **one-shot** (do not blindly re-run Step 3/4). The API role/user are declarative-safe to re-assert. From 0003 on, everything is Terraform/Ansible (re-runnable).
- **Next hooks**: `ssd-data` is the data-mount target for Vault (0005) and Postgres/MinIO (0007); the `terraform@pve` token is what 0003's provider authenticates with.
- **Follow-ups**: migrate the token into Vault once 0005 lands; split a second thin pool if DB and object-store I/O later contend.

## After execution
- [ ] Definition of Done passes.
- [ ] Set this runbook `Status` → `Executed`.
- [ ] Flag the `architect` to set `change-plan/0002` → `Implemented`, update `change-plan/plan.md`, and refresh `docs/hardware.md` (storage table) + `docs/current-state-analysis.md` — those live in the architect's domain.
