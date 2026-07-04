variable "pve_endpoint" {
  type = string
}
variable "pve_api_token" {
  type      = string
  sensitive = true
}

provider "proxmox" {
  endpoint  = var.pve_endpoint  # https://192.168.0.113:8006/
  api_token = var.pve_api_token # terraform@pve!provider=<secret>
  insecure  = true              # self-signed PVE cert on the LAN
  # No `ssh` block: download_file + disk.import_from + clone are all API-only
  # (condition 5) — nothing here needs node-level SSH or a root credential.
}
