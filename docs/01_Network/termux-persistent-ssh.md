# Persistent SSH from Termux

> [!NOTE]
> #Termux #SSH #Tmux #Android #Tailscale

## 1. Description

A Wi-Fi nap kills one SSH connection. It does not have to kill the shell. Run the work inside `tmux` on the server, then reconnect from Termux and attach. `tmux` is already installed on `ai-tools`. No extra server package is required.

Antigravity Remote Control is the other way to drive an agent from the phone. It always asks for permissions, so it stayed unused. This session and the [Telegram terminal wrapper](../02_Services/telegram-terminal/setup.md) are the phone path instead.

## 2. Server session

On `ai-tools` (see [inventory.yml](../../inventory.yml) and `Host ai-tools` in [shared/ssh/config](../../shared/ssh/config)):

```bash
tmux new -s main
```

Detach on purpose with `Ctrl-b` then `d`. After the link dies, SSH in again and attach:

```bash
tmux ls
tmux attach -t main
```

`ServerAliveInterval` only shortens how long a dead session sits frozen. The new SSH connection is empty until `tmux attach`.

Leave Mosh and Eternal Terminal off this host. Neither is installed, and `tmux` already covers the drop.

## 3. Termux client

Install Termux from F-Droid or the GitHub release. The Play Store build is frozen, and its package mirrors fail.

```bash
pkg update
pkg install openssh
```

Use a phone key. Do not copy `~/.ssh/id_ed25519_ai` onto the handset.

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_phone -C termux-phone
```

Append the public key to `authorized_keys` for the `ai-tools` account (`User root` in the shared SSH config). `~/.ssh/config` on the phone:

```sshconfig
Host ai-tools
    HostName 192.168.50.105
    User root
    IdentityFile ~/.ssh/id_ed25519_phone
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 4
```

Then `ssh ai-tools` and `tmux attach -t main`.
