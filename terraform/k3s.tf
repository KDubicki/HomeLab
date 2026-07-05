module "k3s" {
  source        = "./modules/vm"
  name          = "k3s-1"
  vm_id         = 110
  cores         = 3
  memory        = 12288
  disk_gb       = 60
  bridge        = "vmbr1"
  ipv4_cidr     = "10.10.10.20/24"
  gateway       = "10.10.10.1"
  ssh_keys      = [file("~/.ssh/id_ed25519_proxmox.pub")]
  agent_enabled = true # phase 2 — channel hot-plugged (change-log/0003 pattern)
  depends_on    = [proxmox_network_linux_bridge.vmbr1]
}
