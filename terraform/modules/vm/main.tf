variable "name" {
  type = string
}
variable "vm_id" {
  type = number
}
variable "cores" {
  type = number
}
variable "memory" {
  type = number
}
variable "disk_gb" {
  type = number
}
variable "bridge" {
  type    = string
  default = "vmbr0"
}
variable "ipv4_cidr" {
  type = string # e.g. 192.168.0.180/24, or "dhcp"
}
variable "gateway" {
  type    = string
  default = "192.168.0.1"
}
variable "ssh_keys" {
  type = list(string)
}
variable "agent_enabled" {
  type    = bool
  default = false # flip to true (2nd apply) once Ansible has installed qemu-guest-agent (condition 2)
}

resource "proxmox_virtual_environment_vm" "this" {
  name      = var.name
  vm_id     = var.vm_id
  node_name = "pve"
  agent {
    enabled = var.agent_enabled
  }

  clone {
    vm_id = 9000
    full  = true
  }
  cpu {
    cores = var.cores
    type  = "host"
  }
  memory {
    dedicated = var.memory
  }
  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = var.disk_gb
  }
  network_device {
    bridge = var.bridge
  }

  initialization {
    datastore_id = "local-lvm"
    dns {
      servers = ["192.168.0.1"]
    }
    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.ipv4_cidr == "dhcp" ? null : var.gateway
      }
    }
    user_account {
      username = "debian" # bootstrap user; Ansible creates `deploy`
      keys     = var.ssh_keys
    }
  }
}
output "vm_id" {
  value = proxmox_virtual_environment_vm.this.vm_id
}
