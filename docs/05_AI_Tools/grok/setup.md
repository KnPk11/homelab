# Grok CLI Setup

> [!NOTE]
> #Grok #AI #AgenticAi #CLI #LXC

## 1. Description

Grok CLI (`grok`) is xAI's terminal-based coding and infrastructure agent deployed on the `ai-tools` node.

## 2. Infrastructure Setup

Please refer to the [Proxmox LXC Spec](../proxmox-lxc.md) for the specific resource allocation and provisioning details for this node, and [AI Node Security](../security.md) for SSH key management.

## 3. Installation & Usage

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

## 4. Safeguards & Permission Rules

Grok has no `.grokignore` equivalent of `.agignore`. We protect sensitive credentials through native configuration: automatic `.gitignore` suppression, fine-grained `[permission]` deny lists, and `auto` permission mode.

> [!NOTE]
> **Legacy Bubblewrap Sandbox**
> 
> We previously ran Grok with an OS-level `bubblewrap` (bwrap) sandbox profile (`homelab` in `~/.grok/sandbox.toml`). However, following the Grok 1.0 CLI update, Grok enforces a fail-closed check requiring kernel Landlock LSM support. Because `ai-tools` runs inside an unprivileged Proxmox LXC container where Landlock is unsupported, this caused Grok to fail at launch (`error: could not apply the 'homelab' sandbox profile`). Furthermore, orphaned mode-000 stubs (`sandbox-blocked.*`) accumulated whenever sessions terminated abruptly. We therefore set `[sandbox] profile = "off"` and shifted enforcement to Grok's application-level permission engine.

### `~/.grok/config.toml` Setup

Configure `.gitignore` respect, set `permission_mode` to `auto` (avoiding unconstrained YOLO execution), and define explicit `deny` rules for secrets:

```toml
[ui]
permission_mode = "auto"

[tools]
respect_gitignore = true

[permission]
deny = [
  "Read(**/.env)",
  "Read(**/*.env)",
  "Read(**/*.secret)",
  "Read(**/*.key)",
  "Read(**/*.pem)",
  "Read(**/*.pwd)",
  "Read(**/.secrets)",
  "Read(**/.secrets/**)",
  "Read(/opt/dev/secrets_vault/**)",
  "Read(/srv/**/.env)",
  "Read(/srv/**/*.env)",
  "Read(/srv/**/*.secret)",
  "Read(/srv/**/*.key)",
  "Read(/srv/**/*.pem)",
  "Read(/srv/**/*.pwd)",
  "Read(/srv/**/.secrets)",
  "Read(/srv/**/.secrets/**)",
  "Edit(**/.env)",
  "Edit(**/*.env)",
  "Edit(**/*.secret)",
  "Edit(**/*.key)",
  "Edit(**/*.pem)",
  "Edit(**/*.pwd)",
  "Edit(**/.secrets)",
  "Edit(**/.secrets/**)",
  "Edit(/opt/dev/secrets_vault/**)",
  "Bash(rm -rf *)",
]

[sandbox]
profile = "off"
```

> [!IMPORTANT]
> **Safeguard Details**
> 
> - `deny` rules always take precedence over `allow` and cannot be bypassed by permission modes.
> - Example templates (`*.env.example`, `*.secret.template`) are intentionally **unblocked**, allowing agents to safely inspect configuration schemas and debug setups.
> - Direct tools (`read_file`, `grep`, `edit_file`) as well as direct shell invocations (e.g. `cat .env`) are intercepted and rejected by Grok.
> - Live credentials should remain under `/srv` on nodes and dispatched to backup rather than stored long-term in local project clones.
