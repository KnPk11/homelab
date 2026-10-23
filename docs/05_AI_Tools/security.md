# AI Node Security

> [!NOTE]
> #AI #Security #SSH #LXC #Proxmox #Infrastructure

## 1. Description

Node-level security architecture, SSH key privilege separation, and context boundary principles for autonomous AI agents running on the `ai-tools` Proxmox LXC ([Proxmox LXC Spec](proxmox-lxc.md)).

## 2. Access Strategy

We utilise a **multi-key** model so privileges stay separated:

1. **Job / automation keys** (passwordless where appropriate): e.g. MikroTik config capture via `svc_backup`, other read-only jobs. **Not** for interactive git or God Mode.
2. **God Mode key** — `~/.ssh/id_ed25519_ai` (comment `svc_ai`): passphrase-protected. Privileged SSH across the homelab (MikroTik `svc_ai`, LXC/VM accounts that trust this key). **Not** left loaded permanently.
3. **Git SSH key** — `~/.ssh/id_ed25519` (comment `git`): passphrase-protected. **GitHub only** (`git@github.com`).

### Unlock Bundle (ai-tools)

TTL helpers load **God Mode + Git SSH** into one agent (default **2 hours**, then auto-unload):

```bash
ai-key-unlock           # passphrase per key; starts 2h TTL
ai-key-status           # which keys loaded / remaining time
# AI or shell work — other shells / Grok need:
#   source ~/.ssh/ai-key-agent.sh
ai-key-lock             # unload both early when done
```

| Detail | Location |
| :--- | :--- |
| Scripts + install | [ai-ssh-key deployment](../../nodes/ai-tools/services/ai-ssh-key/deployment.md) |
| Router-side setup (MikroTik users/firewall) | [MikroTik AI SSH access](../01_Network/mikrotik/ai-ssh-access.md) |

> [!TIP]
> **TTL Tracking**: Use `ai-key-unlock` / `ai-key-lock`, not a bare `ssh-add` in a random terminal. Only the unlock script records TTL state so `ai-key-status` and the cron watchdog work.

## 3. User Permissions

| Approach | Pros | Cons |
| :--- | :--- | :--- |
| **Root** | No sudo friction, simplifies automation | Lower traditional security |
| **Dedicated User** | Limited permissions, standard practice | May require `NOPASSWD` sudo setup |

> [!TIP]
> **Initial Provisioning**: Start with the root user to ensure a smooth initial setup. Once stable, harden the environment by migrating to a dedicated `svc_ai` user with scoped sudo access.

## 4. AI Safeguards & Context Boundaries

When deploying autonomous AI agents, it is crucial to establish strict boundaries to prevent unintended access to sensitive information. Tool-specific secret ignore rules and permission configurations are documented alongside each agent's setup guide:

- **Antigravity (`.agignore`)**: Refer to [Antigravity Setup](antigravity/setup.md#5-safeguards--context-boundaries).
- **Grok CLI (`~/.grok/config.toml`)**: Refer to [Grok CLI Setup](grok/setup.md#4-safeguards--permission-rules).

### Auditing

Periodically review the files and permissions available to the AI node to ensure they align with the principle of least privilege. Refer to the [Homelab Security Audit Playbook](../03_Maintenance/security-audit-playbook.md) for scheduled verification procedures.
