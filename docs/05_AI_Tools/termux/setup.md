# Persistent SSH from Termux

> [!NOTE]
> #Termux #SSH #Tmux #Android #Tailscale #RemoteAccess

## 1. Description

Provides persistent shell access from Android handsets using Termux and `tmux`. It ensures terminal sessions and background jobs survive mobile network drops, Wi-Fi sleep, or app switching without terminating running tasks.

> [!TIP]
> Prefer **[Herdr](../herdr/setup.md)** as a modern, AI-native alternative. It provides real-time agent state awareness (Working, Blocked, Done), native TrueColour support, and an attention inbox, whereas `tmux` is documented below as the lightweight standard fallback.

For smartphone interaction with local AI agents, this persistent SSH workflow acts as the direct terminal companion to the daemonised [Telegram Terminal wrapper](../../02_Services/telegram-terminal/setup.md).

---

## 2. Server Session Lifecycle (`tmux`)

On `ai-tools` (see [inventory.yml](../../../inventory.yml) and `Host ai-tools` in [shared/ssh/config](../../../shared/ssh/config)):

### 2.1 Essential Commands Reference

| Operation | Command (Outside tmux) | Keybinding (Inside tmux) | Description |
| :--- | :--- | :--- | :--- |
| **New Session** | `tmux new -s <name>` | — | Create and attach to a new named session |
| **List Sessions** | `tmux ls` | `Ctrl-b s` | Display all running sessions on the host |
| **Reattach** | `tmux attach -t <name>` | — | Connect to an existing background session |
| **Detach** | `tmux detach` | `Ctrl-b d` | Leave session running in the background |
| **Destroy Session** | `tmux kill-session -t <name>` | `Ctrl-b :kill-session` (or `exit`) | Terminate a session and its child processes |
| **Kill Entire Server**| `tmux kill-server` | — | Stop the tmux daemon and terminate all sessions |
| **Save Buffer to Disk**| `tmux capture-pane -t <name> -p -S - > session.log` | `Ctrl-b :capture-pane -S -` | Dump complete terminal scrollback history to file |

### 2.2 Common Lifecycles & Workflow

1. **Start & Detach:**
   ```bash
   # Launch a persistent session named 'main'
   tmux new -s main

   # Detach cleanly: Press Ctrl-b, then d (or execute 'tmux detach')
   ```

2. **Reattach After Connection Drop:**
   ```bash
   # Check active sessions
   tmux ls

   # Reattach to 'main'
   tmux attach -t main
   ```

3. **Save Session Scrollback to Disk:**
   To capture the full terminal history of a long build, test suite, or agent turn to a file:
   ```bash
   # Capture entire history (-S -) of session 'main' to a log file:
   tmux capture-pane -t main -p -S - > ~/tmux-session.log

   # Alternatively, pipe real-time output into a continuous log file:
   tmux pipe-pane -t main -o 'cat >> ~/tmux-live.log'
   ```

4. **Destroy / Clean Up Sessions:**
   ```bash
   # Kill a specific completed session:
   tmux kill-session -t main

   # Or kill all active sessions and stop the tmux daemon:
   tmux kill-server
   ```

*(Note: `ServerAliveInterval` only shortens how long a dropped connection sits frozen before closing. The newly reconnected SSH connection is empty until you run `tmux attach`).*

Leave Mosh and Eternal Terminal off this host. Neither is installed, and `tmux` already covers connection drops without opening additional daemon ports.

> [!NOTE]
> **Mobile Client Access (Termux on Android):**  
> Configure OpenSSH and your dedicated handset key on Android by following the [Fleet SSH Key Management Guide](../../00_Infrastructure/ssh-key-management.md#42-mobile-client-walkthrough-termux-android). Once connected via `ssh ai-tools`, attach to your running session with `tmux attach -t main`.
