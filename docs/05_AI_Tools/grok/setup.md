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

Grok has no `.grokignore` equivalent of `.agignore`. We protect sensitive credentials through native configuration: `[tools] respect_gitignore` (search and read tools skip gitignored files), fine-grained `[permission]` deny lists, and `auto` permission mode.

> [!NOTE]
> **Legacy Bubblewrap Sandbox**
> 
> We previously ran Grok with an OS-level `bubblewrap` (bwrap) sandbox profile (`homelab` in `~/.grok/sandbox.toml`). However, following the Grok 1.0 CLI update, Grok enforces a fail-closed check requiring kernel Landlock LSM support. Because `ai-tools` runs inside an unprivileged Proxmox LXC container where Landlock is unsupported, this caused Grok to fail at launch (`error: could not apply the 'homelab' sandbox profile`). Furthermore, orphaned mode-000 stubs (`sandbox-blocked.*`) accumulated whenever sessions terminated abruptly. We therefore set `[sandbox] profile = "off"` and shifted enforcement to Grok's application-level permission engine.

### Permission Modes

The default is `[ui] permission_mode` in `~/.grok/config.toml`. That key accepts `"default"`, `"ask"`, `"auto"`, and `"always-approve"`. In the TUI, `Shift+Tab` cycles Normal, Plan, Auto-review, and Always-approve. `/auto` and `/always-approve` toggle those two modes.

1. **Auto-review (`"auto"`) - Recommended**:
   - A classifier checks tool calls before they run. Routine local work proceeds on its own.
   - A call the classifier will not allow prompts in the TUI. In non-interactive runs (`grok -p`) that call is blocked and reported to the model.
   - `[permission] deny` rules always win. A dangerous command that matches no deny rule can still be allowed.

2. **Always-approve (`"always-approve"` / `--always-approve`, alias `--yolo`)**:
   - Tool calls run without an interactive prompt. This suits unattended runs.
   - Antigravity's unattended mode is Turbo (`--dangerously-skip-permissions`). Grok's flag for that job is `--always-approve`.
   - `deny` rules still apply. So do hooks, and shell `ask` rules that match a command segment.

3. **Ask (`"ask"`, also `"default"`)**:
   - Read-only tools and built-in read-only shell commands (`ls`, `cat`, `git status`, `git diff`, and similar) run without a prompt.
   - File edits and other bash commands wait for confirmation.

`--permission-mode` also accepts `dontAsk` (anything outside the pre-approved and built-in read-only sets is refused), `plan` (edits outside the session plan file are rejected), and `acceptEdits` (file edits run without a prompt).

### `~/.grok/config.toml` Setup

Configure `.gitignore` respect, set `permission_mode` to `auto` (avoiding unconstrained `--yolo` execution), and define explicit `deny` rules for secrets:

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

  # SSH identity: deny reads of id_* (includes id_*.pub) and any edit under .ssh
  "Read(/root/.ssh/id_*)",
  "Read(**/.ssh/id_*)",
  "Edit(/root/.ssh/**)",
  "Edit(**/.ssh/**)",

  # WireGuard configs hold inline private keys. Reads are denied; edits follow the permission mode.
  "Read(/etc/wireguard/**)",

  # Common rm / git spellings. Gaps are listed under Safeguard Details.
  "Bash(rm -rf *)",
  "Bash(rm -fr *)",
  "Bash(rm -r -f *)",
  "Bash(rm -r /*)",
  "Bash(git push *--force*)",
  "Bash(git push *-f *)",
  "Bash(git push *-f)",
  "Bash(git reset --hard*)",
]

[sandbox]
profile = "off"
```

> [!IMPORTANT]
> **Safeguard Details**
> 
> - `deny` rules always take precedence over `allow` and cannot be bypassed by permission modes.
> - Example templates (`*.env.example`, `*.secret.template`) are intentionally **unblocked**, allowing agents to safely inspect configuration schemas and debug setups.
> - A `deny` rule blocks Grok's file tools and a simple command that names the file, such as `cat .env`. A Python one-liner that opens the same file still runs. The sandbox is off, so the kernel will not stop it either.
> - SSH: reading keys named `id_*` is blocked, including `id_ed25519.pub`. A private key with another filename can still be read. `config`, `known_hosts`, and `ai-key-agent.sh` can still be read. Files under `.ssh` cannot be edited.
> - WireGuard files in `/etc/wireguard/` cannot be read. They can still be edited. In `auto` mode that edit asks first.
> - Blocked command forms: `rm -rf`, `rm -fr`, `git push --force` (this includes `--force-with-lease`), `git push -f`, and `git reset --hard`. `rm -r /any/absolute/path` is blocked too.
> - These still reach the permission mode: `sudo rm -rf`, `rm -rfv`, `git push -uf`, `git push origin +main`, and `git reset HEAD --hard`.
> - Keep live credentials under `/srv` on the nodes and back them up from there. Do not leave them in project clones.
