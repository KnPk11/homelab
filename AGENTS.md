# Homelab Repository: Project Mandates

This document serves as the primary instruction set for all AI agents (Antigravity, Grok, OpenCode) and any human contributors. It defines the current project phase, deployment philosophy, and technical standards.

## 🚀 Repository Model: GitOps & Documentation
This repository (`github.com:KnPk11/homelab.git`) is live across the homelab fleet via on-demand GitOps (`sync-nodes` → `auto-pull-repo.sh`).

1. **Sanitised Documentation (`docs/`)**: All files in `docs/` MUST be sanitised (public domains, public IPs, secrets, host secrets paths) according to the [Style Guide](./docs/style-guide.md).
2. **Infrastructure as Intent (`nodes/` & `shared/`)**: Operational scripts, Compose stacks, systemd units, and concrete node runbooks live in `nodes/` and `shared/`. Do not edit tracked files directly on target nodes; commit on `ai-tools`, push to `main`, and sync via `sync-nodes`.
3. **Git History**: Use normal Git commits for versioning. Do NOT create duplicate `_v1`/`_v2` script or config copies alongside active files.

## 📂 Deployment & Secrets Strategy

### 1. Secrets Management (SOPS + `age` & Runtime-Only Vault)
- **Active System**: SOPS with `age` keys is configured in [`.sops.yaml`](./.sops.yaml) for key-bearing appliance nodes (`pve1`, `docker-services`, `nas`, `lab-vm`, `reverse-proxy`, `ai-tools`, `dns`, `pulse`, `vpns`, `pbs`). Nodes without a local `age` key (`ops`, `k8s`, `scratch-pc`, `syslog`) fall back to the Master Admin recipient or keep credentials out of Git in `/srv/<service>/`.
- **Security Architecture**:
  - God Mode SSH and SOPS `age` are separate unlocks. See [`nodes/ai-tools/services/sops-key/deployment.md`](./nodes/ai-tools/services/sops-key/deployment.md).
  - Key-bearing appliance nodes keep a private `age` key at `/root/.config/sops/age/keys.txt` so services can decrypt after reboot.
  - `.sops.yaml` wraps `nodes/<host>/…` secrets for **that node plus the Master Admin** public key. A node key cannot open another node’s files.
  - `ai-tools` does **not** keep a standing node `keys.txt`; the path symlinks to the Master key in RAM (`sops-key-unlock`, 15-min TTL).
  - AI agents on `ai-tools` can ENCRYPT secrets, but CANNOT DECRYPT secrets unless the Master key is unlocked by a human admin.
- **Secret File Types**:
  - **Environment Variables (`.env`)**: SOPS-encrypted in Git where tracked, or stored runtime-only under `/srv/<service>/` (and backed up off-repo via `scrape-configs-and-secrets.sh`). Note that internal RFC 1918 IP addresses used in firewall scripts are NOT classified as secrets and are committed in plain text (per [`.agents/AGENTS.md`](./.agents/AGENTS.md) §3).
  - **Standalone Secret Files (`.secret`, `.pwd`, `.json`)**: Single-value credentials (e.g. `gcp-creds.json`, `airflow_fernet_key.secret`, `glances.pwd`, `vaultwarden_admin_token.secret`) are SOPS-encrypted in Git where tracked.
  - **Third-Party Static Assets (VPN Profiles)**: Bulk raw WireGuard/OpenVPN `.conf` profiles reside outside Git (`/opt/dev/secrets_vault/vpn-configs/` and `/srv/vpns/`) and are backed up off-repo via `scrape-configs-and-secrets.sh`.
- **File Permission Rules**:
  - **In Git (`/opt/homelab-repo/`)**: Files keep standard Git permissions (`644` for files, `755` for scripts).
  - **In Live Runtime (`/srv/<service>/`)**: Decrypted/runtime secret files receive `600` permissions upon deployment (except `glances.pwd`, `mediamtx/.env`, and `nextcloud_hpb_secrets.env`, which use `644` for unprivileged container processes).
- **Configuration File Secret Strategy**:
  1. **Primary Strategy (Default)**: Extract sensitive values into `.env` files (encrypted with SOPS) and use `${VAR}` substitution inside `.yml` / `.yaml` application configs. Keep config files clean and unencrypted in Git.
  2. **Fallback Strategy**: For applications that do not support environment variable substitution, use SOPS `encrypted_regex` to encrypt specific YAML fields in-place.

### 3. Naming & Directory Conventions
- **Lowercase Kebab-Case**: All service directories across all nodes MUST follow lowercase `kebab-case` naming (e.g. `caddy`, `crowdsec`, `dashy`, `fail2ban-monitor`, `gatus`, `anytype-sync-logic`).
- **Single Source of Truth**: Never duplicate service folders with title-case vs lowercase names.

### 4. AI Agent Authentication
- **SSH Access**: Prefer dedicated service users where configured (`svc_ai` / `svc_backup` on MikroTik; root or node-specific users on LXCs/VMs per [`shared/ssh/config`](./shared/ssh/config)).
- **God Mode key (`~/.ssh/id_ed25519_ai`)**: Passphrase-protected identity for **privileged** AI/admin SSH across the homelab (MikroTik, LXCs, VMs — not router-only). On ai-tools: unlock with `ai-key-unlock` (default 1h TTL), check `ai-key-status`, unload with `ai-key-lock`. Before SSH that needs this key, `source ~/.ssh/ai-key-agent.sh`. See [`nodes/ai-tools/services/ai-ssh-key/deployment.md`](./nodes/ai-tools/services/ai-ssh-key/deployment.md) and [`docs/05_AI_Tools/security.md`](./docs/05_AI_Tools/security.md).

## 🎨 Standards & Conventions
All documentation must adhere to the formatting and linguistic rules defined in:
👉 **[Homelab Documentation Style Guide](./docs/style-guide.md)**
