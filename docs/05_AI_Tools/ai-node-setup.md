# AI Node Setup

> [!NOTE]
> **Tags:** #Ai #Lxc #Proxmox #Gemini #OpenCode #AgenticAi #Infrastructure

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

## 4. Advanced Configuration

### 4.1. Local LLM Providers (OpenCode)

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

## 5. Security Best Practices

### 5.1. Access Strategy

It is recommended to create a dedicated service key for the AI node to allow it to interact securely with other homelab services.

### 5.2. User Permissions

| Approach | Pros | Cons |
|----------|------|------|
| **Root** | No sudo friction, simplifies automation | Lower traditional security |
| **Dedicated User** | Limited permissions, standard practice | May require `NOPASSWD` sudo setup |

> [!TIP]
> Start with the root user to ensure a smooth initial setup. Once stable, harden the environment by migrating to a dedicated `gemini` user with scoped sudo access.

## 6. Appendix A: Antigravity & Gemini CLI Tuning & Tips

### 6.1. Tool Configuration

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

### 6.2. Model Assignment & Quotas

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

### 6.3. Advanced Features

- **Conseca**: A feature that enhances the agent's ability to maintain state and context across complex tasks.
- **Auto-Edit**: Allows the agent to automatically apply surgical code changes using the `replace` tool, reducing the need for full file rewrites.

### 6.4. Legacy Gemini CLI Setup

> [!WARNING]
> Gemini CLI no longer works with standard Google accounts via OAuth. Google requires installing Antigravity instead. The following instructions are preserved for historical reference only.

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
