# AI Terminal Suite Security

> [!NOTE]
> #Telegram #Security #AiAgent #AiTools #RemoteAccess #Proxmox #LXC

Security model, privilege boundaries, and access control for the Telegram dual-engine agent wrapper. Installation and operations live in [setup.md](setup.md).

## 1. Description

The AI Terminal Suite exposes full interactive control of both Google Antigravity and xAI Grok to Telegram. Because these agent engines possess autonomous tool-execution capabilities (such as running shell commands, modifying system files, and pulling remote resources), the security posture relies on strict account whitelisting, outbound-only network transport, and environment isolation.

## 2. Threat Model & Privilege Boundaries

### Root Execution & Autonomous Tool Approval

The daemon runs as a `systemd` unit under the `root` user to allow package management, container inspection, and service control across the `ai-tools` LXC container:

- **Google Antigravity (`agy`)**: Invoked with `--dangerously-skip-permissions`, bypassing manual terminal confirmation for all tool actions (`run_command`, `write_to_file`, `replace_file_content`).
- **xAI Grok (`grok`)**: Invoked with `--always-approve` and `--permission-mode bypassPermissions`, giving the model full autonomous tool execution.

> [!WARNING]
> **Host Blast Radius**
>
> An authorised Telegram prompt has full root privileges inside the container. Prompts can execute arbitrary shell commands, install software, reconfigure systemd daemons, or delete files. Containment relies entirely on the boundary of the `ai-tools` Proxmox LXC container.

### Subprocess Lifecycle & Process Group Isolation

When executing long-running builds, compilation tasks, or scripts via agent tools, terminating a turn with `/stop` sends a `SIGINT` to the active child process. 

To prevent detached background commands from becoming orphaned or exhausting container memory:
- Processes should be terminated via process groups (`kill -SIGINT -<pid>`).
- Fallback escalation to `SIGTERM` / `SIGKILL` ensures runaway subprocesses do not persist indefinitely.

## 3. Network & Ingress Exposure

### Zero Inbound Ports

The service operates exclusively via long polling to Telegram's official HTTPS gateway (`api.telegram.org:443`):
- No inbound ports are opened on the router.
- The daemon does not bind to any external TCP/UDP socket on the host.
- The service remains inaccessible to external network scanners and internet automated probes.

### Cloud Relay & Data Transit

Prompts, terminal outputs, tool logs, and uploaded files transit Telegram cloud servers:
- **Secret Hygiene**: Do not paste unencrypted credentials, SSH private keys, or API tokens into chat prompts.
- **SOPS & Age Vaults**: Sensitive credentials on the node should remain encrypted at rest via SOPS. Only unlock keys (`ai-key-unlock`) when actively required for administrative workflows, and lock them (`ai-key-lock`) immediately after.

## 4. Authentication & Access Control

```
Telegram User ──> [Chat ID / Sender ID] ──> Authorisation Middleware ──> Agent Runtime
                                                     │
                                            Whitelisted in .env?
                                            ├── Yes: Process Turn
                                            └── No: Drop & Reject
```

### Account Whitelisting

Access is strictly enforced at the middleware layer using Telegram's unique numeric identifiers:
1. Every incoming update is evaluated for `ctx.chat.id` and `ctx.from.id`.
2. Messages originating from IDs not listed in `ALLOWED_CHAT_IDS` are immediately rejected with an unauthorised access notice.
3. Unauthorised messages never trigger agent invocations, filesystem reads, or subshell commands.

### Declarative User Authorisation

Access is managed declaratively via `.env`:
1. Authorisation evaluates exclusively against the sender's individual User ID (`ctx.from.id`), completely preventing group/channel access leakage.
2. On initial deployment with an empty `ALLOWED_CHAT_IDS`, the bot replies with your numeric User ID upon receiving `/start`.
3. Add that User ID to `ALLOWED_CHAT_IDS` in `.env` and restart the daemon.
4. Dynamic PIN pairing (`/pair`) has been permanently retired to eliminate brute-force attack vectors against public bot handles.

### Forum Supergroup Hardening

When deploying within a Telegram supergroup with Forum Topics (Threads):
- Keep the supergroup private (invite-only).
- Restrict invite permissions to administrators only to prevent unauthorised accounts from joining.
- Topic sessions share the same underlying host filesystem; organise topics by task or repository to avoid concurrent file overwrite collisions.

## 5. Filesystem & Command Controls

| Mechanism | Risk | Mitigation |
| :--- | :--- | :--- |
| **`/sh <cmd>`** | Direct arbitrary bash execution as root | Restricted to whitelisted Chat IDs; output clamped to avoid buffer overflows. |
| **`/workspace <path>`** | Navigation into sensitive directories (e.g., `/etc`, `/root/.ssh`) | Keep default workspace focused on working repositories (e.g., `/opt/dev` or `/root`). |
| **`/get <file>`** | Exfiltration of sensitive configuration or keys | File transfers capped at 50 MB; never expose root SSH private keys via chat. |
| **Document Uploads** | Writing untrusted binaries or scripts | Files are saved strictly into the current topic workspace directory. |

## 6. Hardening Recommendations

1. **Keep Secrets Locked**: Ensure SOPS encryption keys are locked when the agent is idle.
2. **Review Telegram Active Sessions**: Regularly audit active Telegram web and desktop sessions in your personal Telegram client under **Settings > Devices**.
3. **Monitor Container Metrics**: Track memory and CPU utilisation via `/status` to detect runaway background processes early.
