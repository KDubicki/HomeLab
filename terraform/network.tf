resource "proxmox_network_linux_bridge" "vmbr1" {
  node_name = "pve"
  name      = "vmbr1"
  comment   = "0004: private subnet, no uplink"
  autostart = true
  # no `ports` — deliberately no physical port, so it never touches the LAN
}

resource "proxmox_virtual_environment_download_file" "debian13_lxc" {
  content_type       = "vztmpl"
  datastore_id       = "local"
  node_name          = "pve"
  url                = "http://download.proxmox.com/images/system/debian-13-standard_13.1-2_amd64.tar.zst"
  file_name          = "debian-13-standard_13.1-2_amd64.tar.zst"
  checksum           = "5ee736fbc37d2068ca6695d7686b7d62"
  checksum_algorithm = "md5"
}
