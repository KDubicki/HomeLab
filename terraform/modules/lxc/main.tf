variable "name" {
  type = string
}
variable "vm_id" {
  type = number
}
variable "cores" {
  type    = number
  default = 1
}
variable "memory" {
  type    = number
  default = 512
}
variable "disk_gb" {
  type    = number
  default = 4
}
variable "template_file_id" {
  type = string
}
variable "unprivileged" {
  type    = bool
  default = true
}
variable "network_interfaces" {
  # one entry per NIC, in order — ipconfigN maps 1:1 to netN by declaration order
  type = list(object({
    name         = string
    bridge       = string
    ipv4_address = string           # CIDR, or "dhcp"
    ipv4_gateway = optional(string) # omit/null when ipv4_address = "dhcp"
  }))
}
variable "ssh_keys" {
  type = list(string)
}

resource "proxmox_virtual_environment_container" "this" {
  node_name     = "pve"
  vm_id         = var.vm_id
  unprivileged  = var.unprivileged
  started       = true
  start_on_boot = true

  operating_system {
    template_file_id = var.template_file_id
    type             = "debian"
  }
  cpu {
    cores = var.cores
  }
  memory {
    dedicated = var.memory
  }
  disk {
    datastore_id = "local-lvm"
    size         = var.disk_gb
  }

  dynamic "network_interface" {
    for_each = var.network_interfaces
    content {
      name   = network_interface.value.name
      bridge = network_interface.value.bridge
    }
  }

  initialization {
    hostname = var.name
    dynamic "ip_config" {
      for_each = var.network_interfaces
      content {
        ipv4 {
          address = ip_config.value.ipv4_address
          gateway = ip_config.value.ipv4_address == "dhcp" ? null : ip_config.value.ipv4_gateway
        }
      }
    }
    user_account {
      keys = var.ssh_keys
    }
  }
}

output "vm_id" {
  value = proxmox_virtual_environment_container.this.vm_id
}
