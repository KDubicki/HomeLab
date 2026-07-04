module "edge" {
  source           = "./modules/lxc"
  name             = "edge"
  vm_id            = 101
  cores            = 1
  memory           = 512
  disk_gb          = 4
  template_file_id = proxmox_virtual_environment_download_file.debian13_lxc.id
  ssh_keys         = [file("~/.ssh/id_ed25519_proxmox.pub")]
  network_interfaces = [
    {
      name         = "eth0"
      bridge       = "vmbr0"
      ipv4_address = "192.168.0.10/24"
      ipv4_gateway = "192.168.0.1"
    },
    {
      name         = "eth1"
      bridge       = "vmbr1"
      ipv4_address = "10.10.10.1/24"
    },
  ]
  depends_on = [proxmox_network_linux_bridge.vmbr1]
}
