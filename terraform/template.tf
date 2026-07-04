resource "proxmox_virtual_environment_download_file" "debian13" {
  content_type = "import" # PVE's disk-import content type, not "iso" (condition 5); already enabled on `local`
  datastore_id = "local"
  node_name    = "pve"
  # Direct mirror, not cloud.debian.org: its geo-redirect took ~56s on 2026-07-04,
  # exceeding Proxmox's download-url read timeout. This mirror answers in <1s.
  url       = "https://saimei.ftp.acc.umu.se/images/cloud/trixie/latest/debian-13-genericcloud-amd64.qcow2"
  file_name = "debian-13-genericcloud-amd64.qcow2"
}

resource "proxmox_virtual_environment_vm" "debian13_template" {
  name      = "debian13-cloud"
  vm_id     = 9000
  node_name = "pve"
  template  = true
  started   = false

  agent { enabled = true } # declared for clones; not queried at build time

  cpu {
    cores = 1
    type  = "host"
  }
  memory {
    dedicated = 1024
  }

  disk {
    datastore_id = "local-lvm"
    import_from  = proxmox_virtual_environment_download_file.debian13.id
    interface    = "scsi0"
    size         = 8
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization { # cloud-init drive baked as a device only; values set per-clone
    datastore_id = "local-lvm"
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
  }

  serial_device {} # required by the Debian cloud image console
}
