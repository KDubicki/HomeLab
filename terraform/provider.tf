terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.1"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.0.102:8006/"
  api_token = var.proxmox_api_token
  insecure  = true
}