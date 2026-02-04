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
    bridge = "vmbr0"
  }

  disk {
    datastore_id = "nvme-data" # Lexar NM790 storage
    interface    = "scsi0"
    size         = 20
  }

  # Cloud-init initialization
  initialization {
    datastore_id = "nvme-data"

    ip_config {
      ipv4 {
        address = "192.168.0.110/24"
        gateway = "192.168.0.1"
      }
    }

    user_account {
      username = "ubuntu"
      keys     = [var.ssh_public_key]
    }
  }
}