# AI Node Setup

> [!NOTE]
> **Tags:** #Ai #Lxc #Proxmox #Gemini #Grok #OpenCode #AgenticAi #Infrastructure #Security

## 1. Description

A guide for setting up a dedicated AI node as a Proxmox LXC, including the installation and configuration of agentic tools such as Gemini CLI and OpenCode.

## 2. Infrastructure Setup

Please refer to the [Proxmox LXC Spec](proxmox-lxc.md) for the specific resource allocation and provisioning details for this node.

## 3. Agentic Tools Installation

### 3.1. Antigravity Setup

1. **Install Antigravity**:
   
   ```bash
   curl -fsSL https://antigravity.google/cli/install.sh | bash
   ```

2. **Authenticate**:
   Authenticate with Google using the provided code in your terminal.

3. **Usage**:
   - Run the agent using the `agy` command.
   - Use the `/model` command to set the required model.
   - Use the `/usage` command to check model usage.

### 3.2. Grok CLI Setup

1. **Install Grok CLI**:
   
   ```bash
   curl -fsSL https://x.ai/cli/install.sh | bash
   ```

2. **Authenticate**:
   Type `grok` in your terminal and authenticate using the provided code through the xAI website.

3. **Usage**:
   - Run the agent using the `grok` command.
   - Use the `/model` command to set the required model (e.g., Grok 2, Grok 4.3).
   - Use the `/usage` command to check model usage.


### 3.3. OpenCode Setup

1. **Installation**:
   
   ```bash
   curl -fsSL https://opencode.ai/install | bash
   ```

2. **Configuration**:
   Navigate to your project directory and run `/connect` to configure a provider.

#### 3.3.1. Local LLM Providers (OpenCode)

Custom OpenAI-compatible endpoints (e.g., Open WebUI) require explicit mapping in the configuration.

1. **Provider Configuration**: Update `~/.config/opencode/opencode.json`:
   
   ```json
   {
     "provider": {
       "homelab-ai": {
         "npm": "@ai-sdk/openai-compatible",
         "name": "Homelab AI",
         "options": {
           "baseURL": "https://[AI-URL]/api/v1"
         },
         "models": {
           "google/gemma-2-9b": {
             "name": "Gemma 2 9B"
           }
         }
       }
     }
   }
   ```

2. **Authentication**: Store the API key in `~/.local/share/opencode/auth.json`:
   
   ```json
   {
     "homelab-ai": {
       "type": "api",
       "key": "[SECRET]"
     }
   }
   ```


## 4. Security Best Practices

### 4.1. Access Strategy

We utilise a **multi-key** model so privileges stay separated:

1. **Job / automation keys** (passwordless where appropriate): e.g. MikroTik config capture via `svc_backup`, other read-only jobs. **Not** for interactive git or God Mode.
2. **God Mode key** — `~/.ssh/id_ed25519_ai` (comment `svc_ai`): passphrase-protected. Privileged SSH across the homelab (MikroTik `svc_ai`, LXC/VM accounts that trust this key). **Not** left loaded permanently.
3. **Git SSH key** — `~/.ssh/id_ed25519` (comment `git`): passphrase-protected. **GitHub only** (`git@github.com`).

#### Unlock bundle (ai-tools-105)

TTL helpers load **God Mode + Git SSH** into one agent (default **2 hours**, then auto-unload):

```bash
ai-key-unlock           # passphrase per key; starts 2h TTL
ai-key-status           # which keys loaded / remaining time
# AI or shell work — other shells / Grok need:
#   source ~/.ssh/ai-key-agent.sh
ai-key-lock             # unload both early when done
```

| Detail | Location |
|--------|----------|
| Scripts + install | [ai-ssh-key deployment](../../nodes/ai-tools-105/services/ai-ssh-key/deployment.md) |
| Router-side setup (MikroTik users/firewall) | [MikroTik AI SSH access](../01_Network/Mikrotik/ai-ssh-access.md) |

> [!TIP]
> Use `ai-key-unlock` / `ai-key-lock`, not a bare `ssh-add` in a random terminal. Only the unlock script records TTL state so `ai-key-status` and the cron watchdog work.
### 4.2. User Permissions

| Approach | Pros | Cons |
|----------|------|------|
| **Root** | No sudo friction, simplifies automation | Lower traditional security |
| **Dedicated User** | Limited permissions, standard practice | May require `NOPASSWD` sudo setup |

> [!TIP]
> Start with the root user to ensure a smooth initial setup. Once stable, harden the environment by migrating to a dedicated `svc_ai` user with scoped sudo access.

### 4.3. AI Safeguards & Context Boundaries

When deploying autonomous AI agents, it is crucial to establish strict boundaries to prevent unintended access to sensitive information.

#### Antigravity Safeguards (`.agignore`)

Always implement and maintain an `.agignore` file at the root of your projects. This explicitly blocks live secrets while allowing templates so agents can understand configurations without seeing actual credentials.

**Example `/opt/dev/homelab_repo/.agignore`:**

```agignore
# Security & Privacy (Live Secrets)
.env
.env.*
*.secret
*.secrets
.secrets/
credentials.json
*.pem
*.key

# Allow Example/Template Secrets
!.env.example
!.env.template
!*.secret.example
!*.secret.template

# Version Control
.git/
```

#### Grok Safeguards (Bubblewrap Sandbox)

   Grok has no `.grokignore` equivalent of `.geminiignore`. Use config + sandbox instead so tools skip gitignored files and the OS blocks live secrets.

   1. **Install bubblewrap** (required on Linux for sandbox `deny` lists):

      ```bash
      sudo apt install -y bubblewrap
      ```

   2. **`~/.grok/config.toml`** — respect `.gitignore` and default to the homelab sandbox profile:

      ```toml
      [tools]
      respect_gitignore = true

      [sandbox]
      profile = "homelab"
      ```

   3. **`~/.grok/sandbox.toml`** — custom profile that extends `workspace`, allows writes under `/opt/dev`, and kernel-denies the vault / VPN secrets / `/srv` secret globs:

      ```toml
      [profiles.homelab]
      extends = "workspace"
      read_write = ["/opt/dev"]

      deny = [
        "/opt/dev/secrets_vault",
        "/opt/dev/homelab_repo/shared/vpn-configs/.secrets",
        "/srv/**/.env",
        "/srv/**/*.env",
        "/srv/**/*.secret",
        "/srv/**/*.key",
        "/srv/**/*.pem",
        "/srv/**/*.pwd",
        "/srv/**/.secrets",
        "/srv/**/.secrets/**",
        "**/.env",
        "**/*.env",
        "**/*.secret",
        "**/*.key",
        "**/*.pem",
        "**/*.pwd",
        "**/.secrets",
        "**/.secrets/**",
      ]
      ```

> [!IMPORTANT]
> **Grok sandbox caveats**
>
> - Sandbox is fixed at process start. Change profile only on a **new** session (`grok --sandbox off` / `homelab` / `workspace`).
> - Relative globs (`**/…`) are anchored at the **session workspace CWD**. Absolute directory denies (vault, VPN `.secrets`) always apply.
> - Do **not** use a broad absolute pattern like `/opt/dev/**/*.env` if you have project fixtures with a **directory** named `.env` (e.g. dbt under `/opt/dev/projects/`) — bubblewrap can fail closed and refuse to start.
> - Patterns like `*.env` / `*.secret` do **not** match templates (`*.env.example`, `*.secret.example`).
> - Repo secrets policy still lives in `.gitignore` (`*.env`, `*.secret`, `*.key`, `*.pem`, `.secrets/`). Live credentials should stay under `/srv` on nodes and the central vault, not in Git.

#### Auditing

Periodically review the files and permissions available to the AI node to ensure they align with the principle of least privilege.

## 5. Appendix A: Legacy Gemini CLI Reference

> [!WARNING]
> Gemini CLI no longer works with standard Google accounts via OAuth. Google requires installing Antigravity instead. The following instructions are preserved for historical reference only.

### 5.1. Installation & Setup

1. **Install Node.js**:
   
   ```bash
   curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
   sudo apt install -y nodejs
   ```

2. **Install Gemini CLI**:
   
   ```bash
   sudo npm install -g @google/gemini-cli
   ```

3. **Initialise**:
   
   ```bash
   gemini
   ```

4. **YOLO Mode (Optional)**: To allow all permissions without prompts:
   
   ```bash
   gemini --yolo
   ```

### 5.2. Tool Configuration

To enable interactive shell capabilities and allow specific system commands without constant prompts, update your `tools` configuration in `/root/.gemini/settings.json`:

```json
{
  "tools": {
    "shell": {
      "enableInteractiveShell": true
    },
    "allowed": [
      "run_shell_command(ssh)",
      "run_shell_command(ls)",
      "run_shell_command(cd)",
      "run_shell_command(cat)",
      "run_shell_command(grep)",
      "run_shell_command(mkdir)",
      "run_shell_command(cp)",
      "run_shell_command(mv)",
      "run_shell_command(pwd)",
      "run_shell_command(echo)",
      "run_shell_command(find)"
    ]
  }
}
```

### 5.3. Model Assignment & Quotas

If you frequently encounter rate limits on specific models (e.g., Flash), Gemini may continue spawning sub-agents using that model even if other models have available quota. You can force specific model assignments in `settings.json`:

```json
{
  "model": {
    "name": "gemini-3.1-pro-preview",
    "small_model": "gemini-3.1-flash-lite"
  },
  "agent": {
    "general": {
      "model": "gemini-3.1-pro-preview"
    },
    "explore": {
      "model": "gemini-3.1-pro-preview"
    }
  }
}
```

### 5.4. Advanced Features

- **Conseca**: A feature that enhances the agent's ability to maintain state and context across complex tasks.
- **Auto-Edit**: Allows the agent to automatically apply surgical code changes using the `replace` tool, reducing the need for full file rewrites.
