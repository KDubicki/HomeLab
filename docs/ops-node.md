# Ops-Node Configuration & IaC Workflow

## 1. Overview
**Ops-Node (CT 210)** is the central management unit for the entire HomeLab. It acts as a Bastion Host from which all Infrastructure as Code (IaC) operations are performed.

## 2. Technical Stack
- **OS**: Debian 13 (Standard Template)
- **Terraform**: v1.14.x (via HashiCorp Repo)
- **Ansible**: core 2.19.x
- **Python**: 3.13+
- **Version Control**: Git (linked to GitHub via SSH)

## 3. Connectivity & Access
- **Internal IP**: `10.10.0.10`
- **Gateway**: `10.10.0.2`
- **DNS**: `8.8.8.8`, `1.1.1.1`

### Remote Access (VS Code)
To manage the lab from a Windows machine, use the **Remote - SSH** extension:
- **Host**: `10.10.0.10`
- **Auth**: SSH Key
- **Working Dir**: `/root/infrastructure`

## 4. GitOps Workflow
The project is synchronized with `HomeLab` on GitHub.

## 5. Maintenance Commands
- **Re-provision**: `bash/ops-node/provision-ops-node.sh`
- **Check Tools**:
  - `terraform -version`
  - `ansible --version`