# Antigravity Setup

> [!NOTE]
> #Antigravity #Gemini #AI #AgenticAi #CLI #LXC

## 1. Description

Google Antigravity (`agy`) is an agentic AI CLI tool deployed on the `ai-tools` node for autonomous infrastructure management, code editing, and workflow orchestration.

## 2. Infrastructure Setup

Please refer to the [Proxmox LXC Spec](../proxmox-lxc.md) for the specific resource allocation and provisioning details for this node, and [AI Node Security](../security.md) for SSH key management.

## 3. Installation & Usage

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
   - Use `agy --remote-control` or the `agy remote-control` daemon for web/cloud dashboard management.
   - For remote mobile control without SSH/VPN dropouts, refer to the [Telegram Terminal Setup](../../02_Services/telegram-terminal/setup.md).

## 4. Execution Modes & Configuration

### Runtime Execution Modes (`Shift + Tab`)

Rather than maintaining rigid permission configurations in `settings.json`, the Antigravity CLI features dynamic runtime execution modes. You can cycle through these modes at any time during an interactive session by pressing **Shift + Tab** inside the prompt box, or by specifying the mode at startup via the `--mode` CLI flag (e.g., `agy --mode auto` or `agy -c --mode auto`):

1. **Auto (`auto`) - Recommended**:
   - The standard autonomous mode. Workspace file edits are automatically accepted, whilst shell commands are evaluated by a background safety-reviewer agent. Safe, routine, and reversible commands execute automatically without prompting, whilst potentially destructive, sensitive, or irreversible actions pause for interactive user confirmation.
2. **Plan (`plan`)**:
   - Analysis, research, and planning mode. The agent inspects codebases, reads files, and formulates step-by-step implementation plans without modifying files or executing state-altering shell commands.
3. **Accept Edits (`accept-edits`)**:
   - Code edits and file creations within the workspace are applied automatically without approval prompts, whilst all shell/terminal commands pause and require interactive approval.
4. **Default (`default`)**:
   - Standard balanced interactive mode. Prompts for confirmation before modifying files or executing shell commands outside standard read-only operations.

### Fully Autonomous Unattended Execution (`--dangerously-skip-permissions`)

For fully autonomous, unattended background tasks or headless scripts where zero interactive prompts are desired, launch `agy` with the `--dangerously-skip-permissions` flag:

```bash
agy --dangerously-skip-permissions
```

This auto-approves all tool and command permission requests without prompting, eliminating confirmation fatigue during automated workflows.

### Making Unattended Permissions Permanent (`settings.json`)

Because `--dangerously-skip-permissions` is an ad-hoc CLI flag (and hidden from the interactive `/config` menu), you do not need to manually edit `settings.json` for daily operation. The sole exception is if you wish to make unrestricted auto-approval stick permanently across all sessions on the node without needing to pass the CLI flag every time.

To persist this behaviour, configure [`~/.gemini/antigravity-cli/settings.json`](file:///root/.gemini/antigravity-cli/settings.json):

```json
{
  "toolPermission": "always-proceed",
  "allowNonWorkspaceAccess": true
}
```

- **`toolPermission: "always-proceed"`**: Permanently disables interactive prompts, auto-approving both tool executions and shell commands across all sessions.
- **`allowNonWorkspaceAccess: true`**: Permits the agent to read and edit files outside the directory where `agy` was launched (e.g. accessing `/opt/dev` or system files when running from `/root`), preventing out-of-workspace boundary errors.
- **`mode` is omitted**: You no longer need `"mode": "accept-edits"` because `always-proceed` already auto-approves all actions, and leaving `mode` out allows you to freely switch between `auto`, `plan`, and other runtime modes via **Shift + Tab**.

### Remote Control Functionality (`agy remote-control`)

Antigravity provides native remote control capabilities, linking headless CLI sessions running on the node directly to Google's official web console ([antigravity.google.com](https://antigravity.google.com)) or desktop client. This enables real-time monitoring and control of long-running agent workflows without maintaining an open SSH session.

- **Manage Background Daemon**:
  
  Register and start the persistent user systemd service ([`antigravity-cli-daemon.service`](file:///root/.config/systemd/user/antigravity-cli-daemon.service)) executing `agy remote-control serve`:
  
  ```bash
  # Register and enable boot-persistent daemon with an instance name
  agy remote-control start --name ai-tools

  # Verify operational status and dashboard instance link
  agy remote-control status

  # Inspect daemon service logs
  journalctl --user -u antigravity-cli-daemon.service -n 50 -f

  # Stop and unregister daemon
  agy remote-control stop
  ```

  > [!NOTE]
  > **Session-Scoped Daemon**: Use the `--session` flag (`agy remote-control start --session`) if you only wish to run the daemon for the duration of the current login session rather than persisting across reboots.

- **Ad-hoc CLI Session Remote Control**:
  
  To attach a remote connection directly to an interactive CLI session on launch:
  
  ```bash
  agy --remote-control
  ```

## 5. Safeguards & Context Boundaries

### Antigravity Ignore (`.agignore`)

Always implement and maintain an `.agignore` file at the root of your projects (as well as `/opt/dev/.agignore` to protect `/opt/dev/secrets_vault/`). This explicitly blocks live secrets while allowing templates so agents can understand configurations without seeing actual credentials.

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

### Permission Deny Guards (`settings.json`)

To enforce hard guardrails that remain active even when running in Auto or Turbo (`--dangerously-skip-permissions` / `always-proceed`) mode, define explicit `deny` entries under `"permissions"` in [`~/.gemini/antigravity-cli/settings.json`](file:///root/.gemini/antigravity-cli/settings.json). This blocks access to sensitive credential stores and destructive shell commands:

```json
{
  "permissions": {
    "deny": [
      "read_file(/opt/dev/secrets_vault)",
      "write_file(/opt/dev/secrets_vault)",
      "read_file(/root/.ssh/id_ed25519)",
      "read_file(/root/.ssh/id_ed25519_ai)",
      "write_file(/root/.ssh)",
      "command(rm -rf /)",
      "command(git push --force)",
      "command(git push -f)",
      "command(git reset --hard)"
    ]
  }
}
```
