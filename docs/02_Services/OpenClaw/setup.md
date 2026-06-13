# OpenClaw Setup

> [!NOTE]
> **Tags:** #OpenClaw #Ai #Docker #Automation

## 1. Installation Methods

### 1.1. Docker Compose

**Repository**: [OpenClaw GitHub](https://github.com/openclaw/openclaw)

1. Clone the repository and run the setup script:

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
./docker-setup.sh
```

2. Connect the reverse proxy (e.g., Caddy) to the OpenClaw network:

```bash
docker network connect openclaw_default caddy
```

**Gateway Access for Reverse Proxy**:
- Docker DNS: `openclaw-openclaw-gateway-1:18789`
- Configuration file: `/home/[USER]/.openclaw/openclaw.json`

**Allowed Origins** (in `openclaw.json`):

```json
"allowedOrigins": [
  "http://openclaw.homelab.local",
  "https://openclaw.homelab.local"
]
```

**Device Management**:

```bash
docker exec -it openclaw-openclaw-gateway-1 sh
openclaw devices list --token [SECRET]
openclaw devices approve [PENDING_REQUEST_ID] --token [SECRET]
```

### 1.2. Bare Metal Setup

1. **Prerequisites**:

```bash
sudo apt install git curl build-essential procps file
```

2. **Homebrew Installation**:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> ~/.profile
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
```

3. **Node.js Installation**:

```bash
curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
sudo apt install -y nodejs
echo 'export PATH="$HOME/.npm-global/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

4. **OpenClaw Installation**:

```bash
sudo loginctl enable-linger [USER]
curl -fsSL https://openclaw.ai/install.sh | bash
```

5. **Onboarding**:

```bash
openclaw onboard --install-daemon
```

> [!TIP]
> **Dashboard Access**: Running the dashboard command from a terminal in VS Code allows access to `http://127.0.0.1:18789/#token=` without requiring explicit SSH tunnelling.

## 2. Configuration

### 2.1. Core Settings

Example `openclaw.json` configuration with multiple models:

```json
"agents": {
  "defaults": {
    "model": { "primary": "homelab/gpt-oss-20b" },
    "models": {
      "homelab/gpt-oss-20b": { "alias": "gpt-oss-20b" },
      "homelab/qwen2.5-coder-3b-instruct": { "alias": "qwen-3b-instruct" },
      "homelab/llama-3-8b-lexi-uncensored": { "alias": "llama-3-8b-uncensored" }
    },
    "workspace": "/home/[USER]/.openclaw/workspace",
    "compaction": { "mode": "safeguard" },
    "maxConcurrent": 4,
    "subagents": { "maxConcurrent": 8 }
  }
}
```

**Context Window**:

```yaml
"contextWindow": 16000,
"maxTokens": 131072
```

**Disabling Sandbox**:

```bash
openclaw config set agents.defaults.sandbox.mode off
openclaw gateway restart
```

### 2.2. Channels (Telegram Example)

> [!TIP]
> **Telegram Security**: When configured with the `pairing` DM policy, unknown senders must be approved via a short code before their messages are processed. Refer to [this](https://docs.openclaw.ai/gateway/security) guide.

```bash
openclaw pairing approve telegram [PAIRING_CODE]
```

```yaml
"channels": {
  "telegram": {
    "enabled": true,
    "dmPolicy": "pairing",
    "botToken": "[SECRET]",
    "groupPolicy": "allowlist",
    "groups": {
      "-1003723622533": { "requireMention": false }
    },
    "streaming": "off"
  }
}

**Message Reactions**:

```yaml
"messages": {
  "ackReaction": "👀",
  "ackReactionScope": "group-all",
  "removeAckAfterReply": true
}
```

### 2.3. Network and Security

**Gateway Settings**:

```yaml
"gateway": {
  "port": 18789,
  "mode": "local",
  "bind": "loopback", # Change to "lan" for subdomain access
  "controlUi": {
    "allowedOrigins": [
      "http://127.0.0.1:18789",
      "http://localhost:18789",
      "http://openclaw.homelab.local",
      "https://openclaw.homelab.local"
    ]
  }
}
```

## 3. Skills Management

Find pre-made skills on [ClawHub](https://clawhub.ai/).

- **ClawHub Installation**:

```bash
clawhub install [SKILL_NAME]
```

- **Manual Installation**:
  Place skill archives in `/home/[USER]/.openclaw/skills/`.

> [!TIP]
> **Claw Docs:** [clawddocs](https://clawhub.ai/nicholasspisak/clawddocs) is a good starter skill to ensure OpenClaw know how to effectively configure itself.

## 4. Updates and Maintenance

To check for updates:

```bash
openclaw update status
```

If an update is available, re-run the initial setup method or utilise the update button in the Web UI under **Config**.

## 5. Troubleshooting

- **Process Hanging**:

```bash
pkill -f openclaw && openclaw dashboard
```

- **Service Not Found**:
  If the system reports `Unit openclaw-gateway.service could not be found`, re-run the setup script.

- **Repair**:

```bash
openclaw doctor --repair
```

## 6. Multi-Node Setup (Experimental)

To pair a secondary node to the main gateway:

```bash
export OPENCLAW_GATEWAY_TOKEN="[SECRET]"
openclaw node run --host [SERVICE-IP] --port 18789 --display-name "Homelab-Node"
```

## 7. Resources

- [OpenClaw Linux Server Installation 2026](https://vpn07.com/en/blog/2026-openclaw-install-linux-ubuntu-debian-server-tutorial.html): Complete Ubuntu & Debian Tutorial - both methods of installation fail for me
- **VPN/Subdomain Guide**: [2026 OpenClaw Install Tutorial](https://vpn07.com/en/blog/2026-openclaw-install-linux-ubuntu-debian-server-tutorial.html)
- **Free API keys** from [Nvidia](https://build.nvidia.com/): [OpenClaw with NVIDIA](https://www.tienle.com/2026/02-14/openclaw-with-free-models-from-nvidia.html)
