# Herdr Setup & Administration Guide

> [!NOTE]
> #Herdr #AI #AgenticAi #CLI #Terminal #Multiplexer #Rust

## 1. Description

**Herdr** is an open-source, terminal-native **agent multiplexer** written in Rust. It provides persistent background terminal sessions—ensuring AI coding agent workflows survive SSH connection drops, network sleep, or terminal restarts without halting execution.

Unlike general-purpose multiplexers (`tmux`, `screen`), Herdr is purpose-built to orchestrate and monitor multiple concurrent **AI coding agents** (e.g. OpenCode, Grok, Claude Code, Aider) through native agent state awareness (Working, Blocked, Done) and programmable control sockets.

---

## 2. Key Capabilities & Architecture

* **Daemon Architecture (`herdr-core`):** Runs a lightweight background daemon that keeps sessions, agent processes, and logs alive when SSH connections drop or terminals close.
* **Agent State Awareness:** Continuously analyses agent output and process states, categorising agents into **Working**, **Blocked** (awaiting user prompt/approval), **Idle**, or **Done**.
* **Attention Inbox:** Aggregates blocked or finished agents into a central view, avoiding the need to manually cycle through multiple windows.
* **Agent CLI & Socket API:** Exposes a programmable Unix socket and CLI (`herdr agent`, `herdr pane`, `herdr workspace`) allowing running agents to inspect neighbouring tasks or spawn helper panes.
* **Modern Terminal Support:** Built-in TrueColour (24-bit colour) support, mouse integration (click, drag, resize, scroll), and native tabs/splits.

---

## 3. Installation

Herdr is distributed as a self-contained, standalone Rust binary with zero external dependencies.

### 3.1 Automated Installation

Run the official installer on the target node:

```bash
curl -fsSL https://herdr.dev/install.sh | sh
```

By default, the script downloads the release binary into `~/.local/bin/herdr`.

### 3.2 Canonical System-Wide Placement

To avoid version drift, `PATH` resolution conflicts, and redundant duplicate files, promote the binary to `/usr/local/bin`:

```bash
sudo mv ~/.local/bin/herdr /usr/local/bin/herdr
sudo chmod +x /usr/local/bin/herdr
```

> [!TIP]
> **Single Source of Truth:** Moving the binary rather than copying it ensures a single canonical executable exists on the system. This prevents version desynchronisation between root and standard user shells.

Verify installation:

```bash
which herdr
# Expected output: /usr/local/bin/herdr

herdr --version
```

---

## 4. Usage & Lifecycle Management

### 4.1 Commands Reference

| Operation | Command | Description |
| :--- | :--- | :--- |
| **Launch / Reattach** | `herdr` | Launch a workspace or reattach to active persistent session |
| **Named Session** | `herdr --session <name>` | Launch or attach to a specific named session |
| **List Sessions** | `herdr session list` | View all active and background persistent sessions |
| **Stop Session** | `herdr session stop <name>` | Stop a specific named session |
| **Delete Session** | `herdr session delete <name>` | Delete a stopped session record |
| **Stop Server** | `herdr server stop` | Safely terminate the background daemon (`herdr-core`) and all sessions |
| **List Active Panes** | `herdr pane list` | Inspect active panes, pane IDs, and agent states |
| **Save Pane to Disk** | `herdr pane read <pane-id> > pane.log` | Dump complete terminal scrollback history of a pane to disk |
| **Inspect Status** | `herdr status` | Display status of the local client and running background server |
| **CLI Help** | `herdr --help` | Display comprehensive CLI, socket, and agent command reference |

### 4.2 Detaching, Quitting & Saving Sessions

1. **Detaching vs Quitting:**
   * **Detaching (Preserve Execution):** Disconnect your SSH terminal, close Termius, or shut your laptop. Background agent jobs continue executing in the background daemon.
   * **Reattaching:** Reconnect over SSH and execute:
     ```bash
     herdr
     # or attach to named session:
     herdr --session <name>
     ```
   * **Quitting a Pane:** Inside the TUI, close an individual pane with `Ctrl-w` (or click the close button). When the last pane closes, the session terminates.

2. **Stopping & Destroying Sessions from CLI:**
   ```bash
   # List active sessions
   herdr session list

   # Stop and delete a completed named session
   herdr session stop <name>
   herdr session delete <name>

   # Stop the entire background daemon and all running sessions
   herdr server stop
   ```

3. **Saving Session & Pane Output to Disk:**
   * **Automatic Server Logs:** Herdr automatically records session and server daemon execution logs to:
     ```bash
     ~/.config/herdr/herdr.log
     ~/.config/herdr/herdr-server.log
     ```
   * **Manual Pane Scrollback Capture:** To export the complete terminal output of a specific agent pane:
     ```bash
     # List active panes to find the target pane ID (e.g. w6:p1):
     herdr pane list

     # Dump complete pane terminal history to a log file:
     herdr pane read <pane-id> > ~/agent-session.log
     ```

---

## 5. Mobile Access via Termius (Phone / Tablet)

Herdr works seamlessly over SSH from mobile terminal apps such as **Termius**:

1. **SSH Connection:** Connect to the host (`ai-tools`, `lab-vm`, etc.) via Termius as normal.
2. **Reattach:** Run `herdr` to open your workspace.
3. **Special Characters & Font Setup:**
   * In Termius, navigate to **Settings → Terminal → Font**.
   * Ensure a font with comprehensive **Nerd Font** glyph support is selected (e.g. *Fira Code* or *JetBrains Mono*) so that branch icons, status indicators, and box borders render cleanly.
4. **Mobile Layout Recommendation:**
   * On narrow portrait smartphone screens, multi-pane grids can become cramped. Use full-screen pane focus mode (`herdr pane`) when reviewing agent logs or providing prompt input on mobile.

---

## 6. Configuration & Runtime Paths

* **Binary:** `/usr/local/bin/herdr`
* **Configuration:** `~/.config/herdr/config.toml` (overridable via `HERDR_CONFIG_PATH`)
* **Runtime Logs:** `~/.config/herdr/herdr.log`, `herdr-server.log`, `herdr-client.log`

### 6.1 Clean Removal

To completely remove Herdr from the host:

```bash
herdr server stop
sudo rm -f /usr/local/bin/herdr
rm -rf ~/.config/herdr
```
