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

## 4. Configuration

### Turbo / Auto-Approval Mode

To enable unattended auto-approval ("turbo mode") for tools and commands without prompting for interactive confirmation each time, configure [`~/.gemini/antigravity-cli/settings.json`](file:///root/.gemini/antigravity-cli/settings.json):

```json
{
  "toolPermission": "always-proceed",
  "mode": "accept-edits",
  "allowNonWorkspaceAccess": true
}
```

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
