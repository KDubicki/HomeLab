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