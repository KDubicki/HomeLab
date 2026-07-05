# Security Conventions

Rules that keep sensitive material out of this repository — **treat the repo as public.** Every skill and every commit honours these.

## Golden rule
**No secret value ever lands in a tracked file.** Not in `change-plan/`, `change-log/`, `runbooks/`, `docs/`, Terraform/Ansible source, or commit messages. Artifacts reference secrets by **name and location**, never by value.

## What must never be committed
- API tokens / secret values (e.g. the Proxmox `terraform@pve!provider` token), passwords, TLS/private keys.
- Vault unseal keys and root token, `vault operator init` output.
- Terraform state (`*.tfstate*`), plan files (`*.plan`), and any `*.tfvars` / `*.auto.tfvars` holding secrets — plans can embed resolved sensitive attribute values just like state (gap found and closed in change-log/0006).
- kubeconfigs, SSH private keys (`id_*`), SOPS/age private keys, `.env` files.

`.gitignore` covers these as a **safety net** — but the net is not the rule. The rule is "don't write them down in a tracked file."

## Where secrets actually live
- **Now (bootstrap)**: only in **gitignored** files on the workstation (e.g. `terraform/secrets.auto.tfvars`) or offline (Vault unseal keys, printed/stored in a password manager).
- **Target**: **HashiCorp Vault** (`change-plan/0005`) — KV + dynamic credentials. Once Vault exists, bootstrap secrets migrate there and the gitignored copies are removed.
- Docs describe the **wiring** (which identity, which role, where the secret is stored) — never the secret itself.

## Pre-commit secret scan (run before every commit / archive / delete)
```
git diff --cached | grep -EIno \
 'BEGIN [A-Z ]*PRIVATE KEY|[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}|(password|secret|token|api[_-]?key)[[:space:]]*[:=][[:space:]]*[A-Za-z0-9/_.-]{12,}' \
 && echo 'REVIEW: possible secret — DO NOT COMMIT until cleared' || echo 'scan clean'
```
Field *names* and documented *placeholders* (e.g. `MINIO_ROOT_PASSWORD={{ from_vault }}`) are fine; real *values* are not. When in doubt, do not commit.

## Per-skill duties
- **architect / architect-docs / devops**: never paste a scanned secret into a plan, runbook, change-log entry, or doc — reference it by name + store location.
- **executer**: a step may print a secret to the terminal (e.g. a freshly minted token) — that goes to the **operator**, never into a tracked file; capture only to a gitignored file or offline.
- **tester**: read-only; never echo secret values into reports.

## On archive / delete
When an Implemented plan moves to `change-log/` and its runbook is deleted, confirm neither carried a secret value before committing the change.
