module "tf_test" {
  source    = "./modules/vm"
  name      = "tf-test"
  vm_id     = 999
  cores     = 1
  memory    = 1024
  disk_gb   = 8
  ipv4_cidr = "192.168.0.180/24"
  ssh_keys  = [file("~/.ssh/id_ed25519_proxmox.pub")]
}
