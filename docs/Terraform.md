# 1: Infrastructure as Code (Terraform Setup)

## Objective
To automate resource management on the Proxmox VE hypervisor (Dell Optiplex) using Terraform, moving away from manual UI configuration.

## Tasks Completed

### 1. API Authentication
* Created a dedicated PVE user: `terraform@pve`.
* Assigned the `PVEVMAdmin` role to ensure sufficient permissions for VM management.
* Generated a secure API Token (Token ID and Secret) for headless authentication.

### 2. Terraform Project Initialization
* Initialized the directory structure with `provider.tf` and `variables.tf`.
* Configured the `bpg/proxmox` provider to communicate with the host at `192.168.0.102`.
* Implemented a `.gitignore` file to prevent sensitive `.tfstate` and API secrets from being committed to GitHub.

### 3. Environment & Verification
* Resolved a shell-specific issue: switched from Bash `export` to PowerShell `$env:` syntax for setting sensitive environment variables.
* Successfully ran `terraform plan` to verify connectivity between the local machine and Proxmox.

## Technical Notes
* **Provider**: `bpg/proxmox` (v0.66.1)
* **Connection**: Insecure mode enabled (self-signed SSL)
* **Target Storage**: `nvme-data`

## Next Steps
* Create a Cloud-Init Ubuntu template for rapid VM cloning.
* Provision the first virtual machine via Terraform.

---
**Git Commit:** `feat(terraform): setup init`

# 2. Virtual Machine Deployment (Cloud-Init & Scaling)

## Objective
To automate the provisioning of virtual machines on the Dell hypervisor, ensuring consistent resource allocation on the NVMe and immediate accessibility via SSH.

## Tasks Completed

### 1. Resource Provisioning & Hardware Mapping
* Implemented the `proxmox_virtual_environment_vm` resource using the `bpg/proxmox` provider (v0.66.1).
* Allocated hardware resources for `worker-01`: 2 vCPUs (host type) and 2048MB of dedicated RAM.
* Successfully mapped VM virtual disks to the `nvme-data` (LVM-Thin) storage pool on the NVMe drive.

### 2. Cloud-Init Configuration
* Enabled automated post-install configuration via Cloud-Init.
* Defined the default `ubuntu` user account and injected the local public SSH key (`id_ed25519.pub`) for passwordless authentication.
* Assigned a static IPv4 address (`192.168.0.110/24`) and gateway to the VM instance.

### 3. Security & Variables Management
* Decoupled sensitive credentials (API tokens, SSH keys) from the core logic into a `secret.tfvars` file.
* Verified that the `.gitignore` correctly prevents tracking of `*.tfvars` and `.tfstate` files.

## Technical Notes
* **Provider**: `bpg/proxmox` (v0.66.1).
* **Source Template**: Ubuntu 24.04 Cloud-Init Image (VM ID 9000).
* **Verification**: Confirmed successful SSH handshake via `ssh ubuntu@192.168.0.110`.

### Next Steps
* Configure Proxmox SDN (Simple Zone) to create an isolated laboratory network (`vnet1`).
* Move from standard bridge (`vmbr0`) to the new SDN for improved security and micro-segmentation.

---

**Git Commit:** `feat(iac): implement cloud-init vm deployment with sensitive var separation`