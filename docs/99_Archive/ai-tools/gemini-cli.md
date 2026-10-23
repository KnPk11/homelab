# Legacy Gemini CLI Setup

> [!NOTE]
> #Gemini #AI #CLI #Archive #Deprecated

## 1. Description

Historical setup and configuration reference for Google's legacy `@google/gemini-cli` utility on the `ai-tools` node.

> [!WARNING]
> **Deprecated Tooling**
> 
> Gemini CLI no longer works with standard Google accounts via OAuth. Google requires installing [Antigravity](../../05_AI_Tools/antigravity/setup.md) instead. The following instructions are preserved for historical reference only.

## 2. Installation & Setup

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

## 3. Tool Configuration

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

## 4. Model Assignment & Quotas

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

## 5. Advanced Features

- **Conseca**: A feature that enhances the agent's ability to maintain state and context across complex tasks.
- **Auto-Edit**: Allows the agent to automatically apply surgical code changes using the `replace` tool, reducing the need for full file rewrites.
