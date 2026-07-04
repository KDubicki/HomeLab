module "priv_test" {
  source     = "./modules/vm"
  name       = "priv-test"
  vm_id      = 998
  cores      = 1
  memory     = 1024
  disk_gb    = 8
  bridge     = "vmbr1"
  ipv4_cidr  = "dhcp"
  ssh_keys   = [file("~/.ssh/id_ed25519_proxmox.pub")]
  depends_on = [module.edge]
}
