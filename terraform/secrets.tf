variable "vault_role_id" {
  type = string
}
variable "vault_secret_id" {
  type      = string
  sensitive = true
}

provider "vault" {
  address          = "https://127.0.0.1:8200" # via the SSH tunnel to edge → vault; see runbooks/0005 Step 10
  ca_cert_file     = pathexpand("~/.vault/vault-ca.crt")
  skip_child_token = true # our AppRole token is already scoped to kv/data/proxmox/* read-only; no auth/token/create privilege granted

  auth_login {
    path = "auth/approle/login"
    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

data "vault_kv_secret_v2" "proxmox" {
  mount = "kv"
  name  = "proxmox/terraform"
}
