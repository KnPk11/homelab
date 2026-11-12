# Fleet SSH Access & Key Management Guide

> [!NOTE]
> #SSH #Security #KeyManagement #Infrastructure #Homelab #Authentication

## 1. Overview & Key Archetypes

To maintain strict privilege separation and minimise the blast radius of any lost or compromised device, the homelab enforces a **four-tier SSH key architecture**. Private keys must never be shared or reused across security boundaries.

```text
┌────────────────────────────────────────────────────────────────────────┐
│                        HOMELAB SSH ARCHITECTURE                        │
└────────────────────────────────────────────────────────────────────────┘

 [Personal Handset / Laptop]          [ai-tools Node]            [Automated Jobs]
   id_ed25519_phone / laptop         id_ed25519_ai (God Mode)    id_ed25519_mt_backup
             │                               │                           │
             ▼                               ▼                           ▼
   Ingress to ai-tools/lab-vm         Fleet Administration        Read-Only Router Cron
   (Individual device revoke)        (2h TTL Unlock via Agent)    (Passwordless backup)
```

| Key Archetype | Typical Path | Comment / User | Role & Privilege Boundary |
| :--- | :--- | :--- | :--- |
| **1. Client Ingress Keys** | `~/.ssh/id_ed25519_<device>` | `<user>@<device>` | Generated locally on each phone, tablet, or workstation. Authorised for inbound access to specific hosts (`ai-tools`, `lab-vm`). |
| **2. God Mode Lab Key** | `~/.ssh/id_ed25519_ai` | `svc_ai` | Privileged administrative key on `ai-tools`. Passphrase-protected; loaded into `ssh-agent` with a 2-hour TTL via `ai-key-unlock`. |
| **3. Git Identity Key** | `~/.ssh/id_ed25519` | `git` | Dedicated exclusively to GitHub (`git@github.com`). Passphrase-protected; never reused for homelab infrastructure logins. |
| **4. Automation / Job Keys** | `~/.ssh/id_ed25519_<job>` | `svc_backup` | Highly restricted, unprivileged, passwordless keys utilised strictly by automated background tasks (e.g. MikroTik router config backups). |

---

## 2. Per-Device Client Key Policy

### 2.1 The Golden Rule: Device Isolation
**Never copy, export, or synchronise private SSH keys between devices.**

* Each client device (Android phone running Termux/Termius, MacBook, Windows PC) must generate its own unique keypair locally.
* A private key should never leave the physical device on which it was created.

### 2.2 Key Generation Standard
Always generate modern Edwards-curve Digital Signature Algorithm (Ed25519) keys with explicit device comments:

```bash
# On your client device (phone, laptop, workstation):
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_<device> -C "<user>@<device>"

# Example for a mobile phone:
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_phone -C "k@pixel-phone"
```

### 2.3 Blast Radius & Instant Revocation
By maintaining individual keys per device:
* If a mobile phone is lost, stolen, or factory-reset, you only need to delete its single line from `/root/.ssh/authorized_keys` on target hosts.
* No other client devices, servers, or GitHub credentials need to be rotated or updated.

---

## 3. Fleet Key Distribution & Ingress

### 3.1 Proxmox LXC Automatic Propagation
When provisioning new Proxmox LXC containers, public keys are automatically propagated from the hypervisor's `/root/.ssh/authorized_keys`:
* All LXC creation scripts include:
  ```bash
  --ssh-public-keys /root/.ssh/authorized_keys
  ```
* See [Proxmox Guest Specs](proxmox/guests/README.md) for guest provisioning details.

### 3.2 Authorising a New Client Device
To authorise a newly generated client key on a target node:

```bash
# Append client public key to authorized_keys on target host:
cat id_ed25519_phone.pub >> ~/.ssh/authorized_keys

# Enforce secure permissions (mandatory):
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
```

Verify key syntax and fingerprints on the host:

```bash
ssh-keygen -l -f ~/.ssh/authorized_keys
```

---

## 4. Client Configuration & Mobile Onboarding

To ensure stable connections across mobile networks, Wi-Fi drops, and VPN handoffs, client devices (laptops, workstations, and mobile handsets) should standardise their `~/.ssh/config`.

### 4.1 Standard Client `~/.ssh/config` Template

```sshconfig
Host ai-tools
    HostName 192.168.50.105
    User root
    IdentityFile ~/.ssh/id_ed25519_<device>
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 4

Host lab-vm
    HostName 192.168.50.91
    User k
    IdentityFile ~/.ssh/id_ed25519_<device>
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 4
```

#### Key Directives Explained:
* **`IdentitiesOnly yes`**: Essential when using multiple keys or an SSH agent. Instructs the client to only present the key explicitly specified in `IdentityFile`. Without this, the client will offer all loaded keys in sequence, often exceeding the server's `MaxAuthTries` and triggering `Too many authentication failures`.
* **`ServerAliveInterval 30` & `ServerAliveCountMax 4`**: Sends a keepalive packet every 30 seconds. If 4 consecutive packets fail (120 seconds), the connection terminates cleanly, preventing "frozen" terminal hangs during mobile network transitions.

### 4.2 Mobile Client Walkthrough: Termux (Android)

For setting up command-line SSH access from an Android handset:

1. **Install OpenSSH in Termux**:
   Install Termux from **F-Droid** or the **GitHub release** (do not install from Google Play, as that build is deprecated and its package mirrors fail):
   ```bash
   pkg update
   pkg install openssh
   ```

2. **Generate Handset Keypair**:
   Generate a dedicated device key locally on the handset:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_phone -C "k@phone"
   ```

3. **Authorise on Target Node**:
   Append `id_ed25519_phone.pub` to `/root/.ssh/authorized_keys` on target hosts (e.g. `ai-tools`).

4. **Configure `~/.ssh/config`**:
   Save the template above in `~/.ssh/config` inside Termux, specifying `IdentityFile ~/.ssh/id_ed25519_phone`.

---

## 5. Security & Observability Integration

1. **God Mode TTL Protection:** Privileged lab administration from `ai-tools` is managed via TTL wrappers (`ai-key-unlock`, `ai-key-lock`). See [AI SSH Key Service](../../nodes/ai-tools/services/ai-ssh-key/deployment.md) and [AI Node Security](../05_AI_Tools/security.md).
2. **SSH Doorbell Intrusion Detection:** Successful SSH logins across all Linux fleet nodes trigger an immediate Telegram alert via PAM notifications. See [SSH Doorbell](../../shared/observability/ssh-doorbell/deployment.md).
3. **Fleet SSH Config Reference:** Tracked infrastructure hosts and jump aliases are maintained centrally in [`shared/ssh/config`](../../shared/ssh/config).
