terraform {
  required_version = ">= 1.9"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66"
    }
    vault = {
      source  = "hashicorp/vault"
      version = ">= 4.0"
    }
  }
}
