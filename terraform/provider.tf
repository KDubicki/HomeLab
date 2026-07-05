variable "pve_endpoint" {
  type = string
}

provider "proxmox" {
  endpoint  = var.pve_endpoint                                # https://192.168.0.113:8006/
  api_token = data.vault_kv_secret_v2.proxmox.data["pve_api_token"] # sourced from Vault (change-log/0005)
  insecure  = true                                            # self-signed PVE cert on the LAN
  # No `ssh` block: download_file + disk.import_from + clone are all API-only
  # (condition 5) — nothing here needs node-level SSH or a root credential.
}
