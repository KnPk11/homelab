# AI Terminal Suite Setup

> [!NOTE]
> #Telegram #Antigravity #Grok #AiAgent #AiTools #RemoteAccess #Proxmox #LXC

## 1. Description

A dedicated, daemonised Telegram bridge for both **Antigravity CLI ([`agy`](file:///root/.local/bin/agy))** and **xAI Grok CLI ([`grok`](file:///root/.local/bin/grok))** on headless Linux hosts. It brings the full functionality of interactive AI agent suites directly to headless CLI environments without requiring an Electron GUI, X11 display, or Chrome DevTools Protocol (CDP).

It provides complete remote control over your AI coding agents from your mobile phone—supporting natural conversational turns, dynamic engine switching between Google Antigravity and xAI Grok, interactive model and effort selectors, workspace switching, implementation planning, and file exchange without VPN or SSH connection drops.

Antigravity Remote Control is another option for that phone access. It does not work well: it always asks for permissions, and each prompt stalls the turn. Phone access settled on this wrapper and a [persistent Termux session](../../01_Network/termux-persistent-ssh.md). Security considerations, threat boundaries, and hardening live in [security.md](security.md).

## 2. Architecture & Mobile Ergonomics

### 2.1. Dual-Engine Architecture
The daemon integrates two agent runtime binaries into a unified Telegram interface:
- **Google Antigravity (`agy`)**: High-capability multi-model reasoning suite utilising Gemini 3.8 Flash, Gemini 3.1 Pro, Claude Sonnet 4.6, Claude Opus 4.6, and GPT-OSS 120B with native tool tracking and skill execution.
- **xAI Grok Build (`grok`)**: High-velocity autonomous agent engine utilising Grok 4.7, Grok 4.7 Fast, Grok 4.6, and Grok 4.5 with NDJSON event streaming and automated permission bypass.
- **Engine Switching**: Seamless toggling at runtime via the `/engine` command with dedicated inline buttons.

### 2.2. Mobile Keyboard & Conversational Typing
Terminal emulators on Android disable autocorrect, spellcheck, swipe typing, and word predictions because they enforce raw character mode. Routing prompts through Telegram restores full conversational typing:
- Full Gboard/SwiftKey swipe typing, word suggestions, and autocorrect.
- Native speech-to-text microphone dictation.
- Mobile clipboard integration.

### 2.3. Network Roaming & Asynchronous Queue
Standard SSH over TCP drops immediately during mobile network handovers (switching cell towers or moving between 4G/5G and Wi-Fi). 
Telegram operates via an **asynchronous store-and-forward queue**:
- Prompts composed during poor reception or transit are queued and delivered automatically upon reconnection.
- Long-running agent coding turns execute server-side in the background.
- Generated code and responses are posted directly to the chat upon completion with live debounced streaming.

### 2.4. Telegram Forum Topics (Threads) & Multi-Session Isolation
In Telegram supergroups with Forum Topics enabled, each thread functions as a completely independent AI session:
- **Session Continuity**: Every topic tracks its own conversation ID (`--conversation` for Gemini/Antigravity, `--resume` for Grok) and active engine. Switching engines keeps the id being left behind. The destination engine resumes its own session when it has one.
- **Topic Memory**: Each turn updates `memory/<chat>_<thread>.md` beside the bot. That brief is attached to the next prompt only when the destination engine has no native session. `/new` archives it and clears both ids.
- **Parallel Turns**: Each topic maintains an independent child process pointer; turns can run simultaneously across separate topics without locking.
- **Per-Topic Workspaces**: Workspaces can be switched independently per topic via `/workspace <path>`.
- **Session State Persistence**: Topic metadata and session identifiers are persisted to `sessions.json`, ensuring continuity across service restarts.

### 2.5. Zero Inbound Exposure
The service establishes outbound HTTPS long-polling connections directly to Telegram API servers (`api.telegram.org`). No inbound firewall ports, reverse proxies, or VPN tunnels are required.

## 3. Installation & Configuration

1. **Obtain Bot Token**:
   - Open Telegram and message [@BotFather](https://t.me/BotFather).
   - Send `/newbot`, name the bot, and copy the HTTP API token.

2. **Deploy Application**:
   Clone the application from [`KnPk11/ai-telegram-suite`](https://github.com/KnPk11/ai-telegram-suite) and install dependencies:

   ```bash
   git clone git@github.com:KnPk11/ai-telegram-suite.git /root/telegram-terminal
   cd /root/telegram-terminal
   npm install
   ```

3. **Configure Environment**:
   Create the runtime environment file `/root/telegram-terminal/.env`:

   ```ini
   BOT_TOKEN=[TELEGRAM-BOT-TOKEN]
   ALLOWED_CHAT_IDS=[TELEGRAM-USER-ID]
   DEFAULT_ENGINE=agy
   DEFAULT_WORKSPACE=/root
   DEFAULT_MODEL=gemini-3.8-flash-high
   DEFAULT_GROK_MODEL=grok-4.7
   ```

4. **Install Systemd Service**:
   Deploy the service unit to ensure automatic startup and restart persistence:

   ```bash
   cp /opt/dev/homelab_repo/nodes/ai-tools/services/telegram-terminal/telegram-terminal.service /etc/systemd/system/
   systemctl daemon-reload
   systemctl enable --now telegram-terminal
   ```

## 4. Authentication & Security

1. **Declarative Allowlist**: Authorisation is strictly scoped to sender user IDs (`fromId`) in `ALLOWED_CHAT_IDS`. Group IDs are rejected.
2. **Account Provisioning**:
   - Message the bot on Telegram with `/start`.
   - If `ALLOWED_CHAT_IDS` is unset in `.env`, the bot will reply with your numeric User ID.
   - Add your User ID to `ALLOWED_CHAT_IDS` in `.env` and restart the daemon.
3. **Security Documentation**: Detailed threat model, root execution boundaries, and process isolation considerations are documented in [security.md](security.md).

## 5. Usage & Operations

### 5.1. Command Reference

| Action | Syntax / Method | Description |
| :--- | :--- | :--- |
| **Chat with AI Agent** | *(Any regular text)* | Every text message is automatically processed by the active engine (`agy` or `grok`) in the active topic with continuous turn streaming. |
| **Topic Sessions** | `/sessions` or `/topics` | Displays a list of all active topics/threads in the chat, their engine, model, and running status. |
| **Topic Label** | `/name <title>` | Views or customises the nickname for the current topic. |
| **Engine Selection** | `/engine` | Displays inline buttons to switch between **Google Antigravity** and **xAI Grok** for the current topic. An engine with no session in the topic receives the topic memory on its next message. |
| **Model Selection** | `/model` | Displays interactive inline buttons tailored to the active engine for the current topic (Antigravity: Gemini/Claude/GPT; Grok: Grok 4.7/4.6/4.5). |
| **Reasoning Effort** | `/effort` | Displays inline buttons to switch reasoning effort (`low`, `medium`, `high`, `max`/`xhigh`). |
| **New Session** | `/new` | Archives the topic memory, clears both engine sessions, and starts fresh on the next prompt. |
| **Implementation Plan** | `/plan <task>` | Runs the active agent in plan-only mode (`--mode plan` / `--permission-mode plan`). |
| **Workspace Navigation** | `/workspace <path>` | Changes the active project directory for subsequent turns in the current topic. |
| **Current Workspace** | `/pwd` | Prints the active working directory for the current topic. |
| **Download File** | `/get <filepath>` | Sends a file from the workspace directly to the Telegram chat. |
| **Upload File** | *Send document/photo* | Uploads file to workspace; if a caption is included, the agent processes it immediately. |
| **Shell Escape** | `/sh <command>` | Runs an occasional bash command directly on the host in the topic workspace. |
| **Abort Task** | `/stop` | Sends `SIGINT` (`Ctrl+C`) to terminate the active agent execution in the current topic (`/stop all` to cancel all). |
| **Usage & Quotas** | `/usage` or `/quota` | Displays model quota table for Antigravity, or detailed token breakdown and session costs for Grok. |
| **Active Skills** | `/skills` | Lists all active Antigravity skills or Grok plugins available in the environment. |
| **Custom Agents** | `/agents` | Lists custom subagents defined on the host (Antigravity). |
| **Credits** | `/credits` | Displays remaining account credits balance (Antigravity). |
| **Universal Slash Fallback** | `/<command>` | Any unmapped slash command is passed directly to the local active agent binary. |
| **System Status** | `/status` | Reports active engine, model, effort, workspace, CPU load, and free RAM. |

## 6. Service Management

```bash
# Check service status
systemctl status telegram-terminal

# View real-time daemon logs
journalctl -u telegram-terminal -f

# Restart daemon
systemctl restart telegram-terminal

# Stop daemon
systemctl stop telegram-terminal
```
