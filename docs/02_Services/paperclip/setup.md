# Paperclip Setup

> [!NOTE]
> #Paperclip #AI #Agents #BareMetal #ScratchPc

## 1. Description

Paperclip (`paperclipai`) is a self-hosted app for hiring and running coding agents. This lab runs it on `lab-vm`, behind the reverse proxy, at `https://paperclip.[DOMAIN]`. The site is LAN-only.

The installed release is `paperclipai@2026.1023.0` on Node `v24.21.0`. The official container image is not used.

## 2. Installation

1. **Install Node 24** under `/opt/node-v24` and leave `/usr/bin/node` and Hermes's Node 22 untouched.

2. **Install Paperclip** with that Node on `PATH`:

   ```bash
   export PATH=/opt/node-v24/bin:$PATH
   npm install -g paperclipai@2026.1023.0
   ```

   npm 11 on Node 24 skips some dependency install scripts unless `--allow-scripts` is set. Claude Code still runs here without re-running those scripts. The `paperclipai` shim is `#!/usr/bin/env node`, so invoke it as `/opt/node-v24/bin/node /opt/node-v24/bin/paperclipai` or with `PATH=/opt/node-v24/bin` first. A login shell as `k` will otherwise pick Node 22 and fail with `env: ‘node’: No such file or directory`.

3. **Create the data directory** and give it to `k`:

   ```bash
   install -d -o k -g k /opt/paperclip /opt/paperclip/data
   ```

4. **Do not** run a second managed copy with `paperclipai install` into `/opt/paperclip/data/cli`. That duplicates the global package. A partial tree with no `install.json` makes `paperclipai doctor` refuse to start.

## 3. Configuration

Deployment is authenticated and private. The hostname from the public URL must be allowed, and the auth base URL is explicit so links use `https://paperclip.[DOMAIN]` rather than the bind address.

`paperclipai onboard --yes` without `--bind` forces loopback and ignores the reachability settings. The non-interactive private-network form is `--yes --bind lan`. This host's resulting `config.json` (`/opt/paperclip/data/instances/default/config.json`) has:

| Key | Value |
| :--- | :--- |
| `server.deploymentMode` | `authenticated` |
| `server.exposure` | `private` |
| `server.bind` | `lan` |
| `server.host` / `port` | `0.0.0.0` / `3100` |
| `server.allowedHostnames` | `paperclip.[DOMAIN]` |
| `server.serveUi` | `true` |
| `auth.baseUrlMode` | `explicit` |
| `auth.publicBaseUrl` | `https://paperclip.[DOMAIN]` |
| `auth.disableSignUp` | `false` (still open after the first admin claim) |
| `database.mode` | `embedded-postgres` |
| Backup | every 60 minutes, keep 30 days |

Secrets are managed via Mozilla SOPS under `nodes/lab-vm/services/paperclip/`. For the host secrets decryption and deployment runbook, refer to the [Lab-VM Bootstrap & Deployment Guide](../../../nodes/lab-vm/deployment.md#2-paperclip-service-deployment).

Embedded Postgres is localhost-only. A `database_backup_missing` warning on `/api/health` is expected until the first hourly backup lands.

## 4. Service

System unit `/etc/systemd/system/paperclip.service`, enabled, user `k`. A user service was not used. Doctor reports no systemd user manager when `XDG_RUNTIME_DIR` is unset, even though linger is enabled for `k`.

```ini
[Unit]
Description=Paperclip
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=k
Group=k
WorkingDirectory=/opt/paperclip
Environment=HOME=/home/k
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PAPERCLIP_PUBLIC_URL=https://paperclip.[DOMAIN]
Environment=PAPERCLIP_UPDATE_CHECK=0
Environment=PAPERCLIP_NO_BROWSER=1
Environment=OPENCODE_ALLOW_ALL_MODELS=true
Environment=PAPERCLIP_OPENCODE_PRINT_LOGS=true
ExecStart=/usr/bin/node /usr/bin/paperclipai run --data-dir /opt/paperclip/data
Restart=on-failure
RestartSec=5
TimeoutStartSec=180

[Install]
WantedBy=multi-user.target
```

`HOME=/home/k` matters. Subscription logins for the agent CLIs are read from that home, not from root.

The OpenCode environmental variables configured for runtime:

- **`OPENCODE_ALLOW_ALL_MODELS=true`**: Bypasses OpenCode's internal `models.dev` catalogue validation. Paperclip dynamically wraps custom and gateway providers (such as NVIDIA Build) under an internal `"paperclip"` provider and passes `--model paperclip/<model_id>` to OpenCode. Without this variable, OpenCode's pre-flight check rejects unrecognised models before routing requests upstream.
- **`PAPERCLIP_OPENCODE_PRINT_LOGS=true`**: Instructs Paperclip to surface OpenCode's stderr output in the systemd journal for streamlined diagnostics.

Agent CLIs installed for the adapters, on the service `PATH`, with symlinks in `/usr/local/bin` so a login shell can find them:

| Command | Version | Package |
| :--- | :--- | :--- |
| `claude` | 2.1.312 | `@anthropic-ai/claude-code` |
| `codex` | 0.165.0 | `@openai/codex` |
| `gemini` | 0.66.0 | `@google/gemini-cli` |
| `opencode` | 1.19.5 | OpenCode installer, binary `~/.opencode/bin/opencode` |
| `grok` | 1.0.70 | `@xai-official/grok`, binary `~/.grok/bin/grok` |
| `gh` | distro package | `/usr/bin/gh` |

> [!WARNING]
> **OpenCode Version & Background Daemon Port Conflict**
>
> OpenCode v2.2.0 introduced a managed background service (`opencode serve --service`) binding port `49374`. Because Paperclip executes pre-flight checks and agent turns in isolated temporary directories (`/tmp/paperclip-opencode-config-XXXXXX`), subsequent CLI runs cannot read the active daemon's state file, attempt to bind port `49374` again, and fail with:
> `Server process exited with code 1 Error: Managed service port 49374 on 127.0.0.1 is already in use by PID ...`
>
> To avoid this collision, pin or install the stable v1.19.5 release (`curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path`), which defaults to ephemeral ports (`--port 0`) without running a shared background daemon. If utilising v2.2+, global `--standalone` mode must be passed before subcommands.

## 5. Reverse Proxy

Paperclip is routed via Caddy in `nodes/reverse-proxy/services/caddy/Caddyfile` with LAN-only access. Do not rewrite the `Host` header as Paperclip verifies it against `allowedHostnames`. `flush_interval -1` prevents buffering agent streaming output and SSE:

```caddyfile
paperclip.{$DOMAIN_NAME} {
    import access_policy_lan
    reverse_proxy 192.168.50.91:3100 {
        flush_interval -1
    }
}
```

> [!TIP]
> Operational logging and Caddy reload procedures are detailed in [Caddy Deployment Notes](../../../nodes/reverse-proxy/services/caddy/deployment.md).

## 6. First login and the onboarding caveat

Open `https://paperclip.[DOMAIN]` from the LAN. The first account claims the instance admin. Bootstrap on this host is already `ready`, and the one-time invite is not active. Sign-up is still enabled (`auth.disableSignUp` is `false`) until an admin turns it off in the app.

> [!IMPORTANT]
> **Connect a model only offers Claude and OpenAI**
>
> In `paperclipai@2026.1023.0` the first-agent wizard step **Connect a model** shows two tiles, **Claude** and **OpenAI**. Those are the recommended harnesses (Claude Code and Codex). The continue button stays disabled until that provider's login or API key passes an environment test. There is no skip. The overlay has no working close control, so Escape does not dismiss it.
>
> The wizard is shown again when the company has **zero agents** and you open the dashboard, and whenever the path is `/onboarding` or `/[PREFIX]/onboarding`. This company's prefix is `KHO` (`K homelab`). Creating any agent clears that gate. The server hire API does not repeat the wizard's Claude/OpenAI test. The block is only in that screen.

To leave the wizard without a Claude or OpenAI account, load one of these URLs directly (type it and press Enter, so it is a fresh page load):

- Agents: `https://paperclip.[DOMAIN]/KHO/agents/all`
- Connections: `https://paperclip.[DOMAIN]/KHO/company/settings/connections`

On **Agents**, use **New agent** and pick **Grok Build**, **OpenCode**, or **Hermes**, then save. That screen lists every loaded adapter. One saved agent is enough for the dashboard to stop opening the wizard. Visiting the dashboard before that save brings the wizard back.

## 7. Model providers after the wizard

### Grok

**Settings → Connections** lists **xAI** on the main provider list, described as "Grok subscription or API key". The agent adapter is **Grok Build**, not one of the two wizard tiles.

A Grok subscription is a login of the `grok` CLI on `lab-vm`, stored in `/home/k/.grok`. It is not the in-browser button used for Claude and ChatGPT. On this headless host:

```bash
sudo -u k grok login --device-auth
```

Leave that process running, open the printed URL on a machine with a browser, and enter the code. The service only sees the binary if it is on the unit `PATH` (`/opt/node-v24/bin` or `/usr/local/bin`). The official installer puts `grok` in `~/.grok/bin`, which this unit does not search. `npm install -g @xai-official/grok` with Node 24 on `PATH` lands on the service `PATH`. An xAI API key (`XAI_API_KEY`) is the other method on the same xAI card and does not need `grok login`. The Grok Build harness still runs the `grok` binary.

### NVIDIA Build

NVIDIA Build is not a named provider. Add it under **Settings → Connections → Advanced providers → Custom gateway**:

| Field | Value |
| :--- | :--- |
| Provider URL | `https://integrate.api.nvidia.com/v1` |
| API format | Chat Completions · OpenCode, Hermes |
| Authentication | Bearer token |
| API key | the key from build.nvidia.com, pasted into the form |

> [!IMPORTANT]
> **Endpoint and Model Naming Caveats**
>
> - **Provider URL**: Must be `https://integrate.api.nvidia.com/v1`. Do **not** append `/chat/completions` (OpenAI-compatible client libraries automatically append this path; adding it results in a 404 Not Found error).
> - **Model ID**: Enter the exact model name without duplicate provider prefixes (e.g. `nvidia/nemotron-3-ultra-550b-a55b`).
> - **`paperclip/` Prefix**: Paperclip automatically prepends `paperclip/` to the configured model in its runtime configuration (e.g. `paperclip/nvidia/nemotron-3-ultra-550b-a55b`). This behaviour is intentional: OpenCode matches the `paperclip/` prefix to the dynamically injected provider definition and strips it before dispatching the request to the NVIDIA endpoint.

Chat Completions connections are applied to **OpenCode** and **Hermes** agents. Codex speaks the OpenAI Responses API, and Claude speaks Anthropic Messages, so the two wizard tiles do not use this endpoint. Set the model id from the NVIDIA model page on the OpenCode or Hermes agent (ids look like `nvidia/llama-3.3-nemotron-super-49b-v1` or `nvidia/nemotron-3-ultra-550b-a55b`).

## 8. Verification

On `lab-vm`:

```bash
systemctl is-active paperclip.service hermes-gateway.service
curl -fsS http://127.0.0.1:3100/api/health
```

From the LAN:

```bash
curl -fsS https://paperclip.[DOMAIN]/api/health
```

`deploymentMode` is `authenticated` and `deploymentExposure` is `private`. The UI is served as HTML on `/`.

## Troubleshooting

- **Onboarding Wizard Locked to Claude/OpenAI:** Navigate directly to `https://paperclip.[DOMAIN]/KHO/agents/all` and save any other adapter (such as Grok Build, OpenCode, or Hermes) to dismiss the onboarding lock (see [Section 6](#6-first-login-and-the-onboarding-caveat)).
- **NVIDIA Gateway Errors:**
  - *404 Not Found:* Ensure the Custom Gateway Provider URL is set strictly to `https://integrate.api.nvidia.com/v1` without `/chat/completions` appended.
  - *Tile Incompatibility:* Do not paste NVIDIA keys into the OpenAI/Codex tile. Route NVIDIA models through OpenCode or Hermes agents via Chat Completions (see [Section 7](#7-model-providers-after-the-wizard)).
- **OpenCode Runtime Gotchas:**
  - *Port 49374 Conflict:* Caused by OpenCode v2.2+ background daemon collisions. Pin to stable v1.19.5 or run with `--standalone` (see [Section 4](#4-service)).
  - *Model Rejected / Unavailable:* Ensure `OPENCODE_ALLOW_ALL_MODELS=true` is set in `/etc/systemd/system/paperclip.service`.
  - *Filewatcher Timeout:* If project directory scanning times out, set `OPENCODE_DISABLE_FILEWATCHER=true` in the systemd unit.
- **Node Environment & CLI Discovery:**
  - *`env: ‘node’: No such file or directory`:* The `paperclipai` shim requires Node 24 on PATH. Ensure `ExecStart` in the unit explicitly invokes `/usr/bin/node`.
  - *Doctor Fails on Managed CLI:* Remove `/opt/paperclip/data/cli` if `install.json` is missing.
