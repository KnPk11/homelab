# Homelab Repository: Project Mandates

This document serves as the primary instruction set for all AI agents (Antigravity, Grok, OpenCode) and any human contributors. It defines the current project phase, deployment philosophy, and technical standards.

## 🚀 Current Project Phase: Documentation Migration
We are currently in the **Documentation & Sanitisation Phase**.

1.  **Docs First**: The immediate priority is migrating and sanitising documentation from `docs_temp/` to `docs/`.
2.  **Sanitisation Protocol**: All files in `docs/` MUST be sanitised (domains, IPs, secrets) according to the [Style Guide](./docs/repository_notes_style_guide.md).
3.  **Scripts Second**: Operational scripts and configurations in the `nodes/` directory are to be organised but **NOT** pushed to public source control yet. They will be handled in the next phase using **SOPS** for secret management.

## 📂 Deployment & History Strategy

### 1. Script Versioning
We are intentionally maintaining multiple versions of operational files (e.g., `Caddyfile_v1`, `Caddyfile_v2`).
- **Goal**: This is a deliberate strategy to allow for the reconstruction of a basic commit history when we eventually move these scripts to a Git repository.
- **Rule**: Do NOT delete legacy versions of files in the `nodes/` directory unless explicitly instructed.

### 2. Secrets Management (Future)
- **SOPS**: We intend to utilise SOPS (Secrets Operations) for the `nodes/` directory. 
- **Current State**: Until SOPS is implemented, keep real credentials in the `nodes/` folder but ensure it is excluded from public pushes (or handled via force-pushes if accidents occur).

### 3. AI Agent Authentication
- **SSH Access**: Prefer dedicated service users where configured (`svc_ai` / `svc_backup` on MikroTik; root or node-specific users on LXCs/VMs per [`shared/ssh/config`](./shared/ssh/config)).
- **God Mode key (`~/.ssh/id_ed25519_ai`)**: Passphrase-protected identity for **privileged** AI/admin SSH across the homelab (MikroTik, LXCs, VMs — not router-only). On ai-tools-105: unlock with `ai-key-unlock` (default 1h TTL), check `ai-key-status`, unload with `ai-key-lock`. Before SSH that needs this key, `source ~/.ssh/ai-key-agent.sh`. See [`nodes/ai-tools-105/services/ai-ssh-key/deployment.md`](./nodes/ai-tools-105/services/ai-ssh-key/deployment.md) and [`docs/05_AI_Tools/ai-node-setup.md`](./docs/05_AI_Tools/ai-node-setup.md).

## 🎨 Standards & Conventions
All documentation must adhere to the formatting and linguistic rules defined in:
👉 **[Homelab Documentation Style Guide](./docs/repository_notes_style_guide.md)**

---
*Last Updated: Saturday, June 6, 2026*
