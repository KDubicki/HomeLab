resource "proxmox_virtual_environment_vm" "worker_node" {
  vm_id     = 110
  name      = "worker-01"
  node_name = "pve"

  # Newer syntax for cloning in bpg provider
  clone {
    vm_id = 9000
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 2048
  }

network_device {
    bridge   = "vnet1"
    firewall = true #
}

  disk {
    datastore_id = "nvme-data"
    interface    = "scsi0"
    size         = 20
  }

  # Cloud-init initialization
initialization {
    datastore_id = "nvme-data"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
  }
}

resource "proxmox_virtual_environment_firewall_rules" "worker_firewall" {
  # Fix 1: Explicitly provide both node_name and vm_id
  node_name = proxmox_virtual_environment_vm.worker_node.node_name
  vm_id     = proxmox_virtual_environment_vm.worker_node.vm_id

  rule {
    type    = "in"
    # Fix 2: Actions must be UPPERCASE
    action  = "ACCEPT"
    proto   = "tcp"
    dest    = "22"
    source  = "192.168.0.0/24"
    comment = "Allow SSH from home network"
  }

  rule {
    type    = "in"
    action  = "DROP"
    comment = "DROP ALL OTHER INBOUND TRAFFIC"
  }
}