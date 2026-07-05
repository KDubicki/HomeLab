module "vault" {
  source           = "./modules/lxc"
  name             = "vault"
  vm_id            = 102
  cores            = 1
  memory           = 1024
  disk_gb          = 8
  data_disk = {
    datastore_id = "ssd-data"
    size_gb      = 5
    path         = "/vault/data"
  }
  template_file_id = proxmox_virtual_environment_download_file.debian13_lxc.id
  ssh_keys         = [file("~/.ssh/id_ed25519_proxmox.pub")]
  network_interfaces = [
    {
      name         = "eth0"
      bridge       = "vmbr1"
      ipv4_address = "10.10.10.10/24"
      ipv4_gateway = "10.10.10.1"
    },
  ]
  depends_on = [proxmox_network_linux_bridge.vmbr1]
}
