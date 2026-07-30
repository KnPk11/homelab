# Homelab Security Audit Playbook

> [!NOTE]
> #Security #Audit #Maintenance #Lynis #DockerBench #CrowdSec #MikroTik

## 1. Description

Periodic **read-only** security audit for a human or AI agent on **ai-tools**. Run checks, reconcile with private baselines, write a short report. Full upgrades and remediations are out of band unless the operator approves.

| Layer | Check with |
| :--- | :--- |
| Host hardening | Lynis + private exception baseline |
| Docker host | Docker Bench + privilege/mount skim |
| Firewalls | Proxmox / Guest VM rules (`nodes/*/scripts`) |
| Edge | MikroTik + isolation |
| IDS | CrowdSec LAPI/bouncers (+ fail2ban bridge) |
| Public surface | Caddy + DSTNAT + monitors |
| Keys / secrets | `ai-key-*`, SOPS, live perms, git hygiene |
| Recovery | Backup *freshness* only → [backup-playbook.md](./backup-playbook.md) |

**Cadence:** monthly light · quarterly deep · ad-hoc after publish/node/router change.

**Rules of engagement**

- Scores secondary; documented exceptions win (private `docs_private/security/*`).
- This file is *how*; private notes are *why we accept X*.
- Snapshot updates only — do not patch the lab mid-audit.
- Host aliases from [shared/ssh/config](../../shared/ssh/config); inventory in [inventory.yml](../../inventory.yml).
- No secret contents in chat/git/report. Audit-only by default. Done = report + filed todos, not better scores.

**Related:** [lynis](../02_Services/lynis/setup.md) · [docker-bench](../02_Services/docker-bench/setup.md) · [docker-host/security](../00_Infrastructure/docker-host/security.md) · [crowdsec](../02_Services/crowdsec/setup.md) · [mikrotik/security](../01_Network/mikrotik/security.md) · [caddy/security](../02_Services/caddy/security.md) · [ai-node-setup](../05_AI_Tools/ai-node-setup.md) · private: `lynis-audit.md`, `mikrotik-firewall-audit.md`, `linux-host-hygiene.md`, `ai-tools-hardening.md`

---

## 2. Agent protocol

```bash
ai-key-unlock && source ~/.ssh/ai-key-agent.sh && ai-key-status
# … audit …
ai-key-lock   # also sops-key-lock if used
```

1. Prefer SSH host aliases; time-box to the agreed mode.
2. Never dump passwords, age keys, tokens, or full secret files.
3. Do not invent baselines — tag `needs-baseline-update` instead.
4. Remediation only with explicit approval.
5. Do not flip `vlan-filtering`, broad filter rules, or run destructive probes without asking.

**Severity:** `fix now` (active exposure / broken control) · `track` · `accept` (baseline) · `needs-baseline-update`

**Out of scope:** full upgrade campaigns, architecture redesign, SIEM/AV everywhere, perfect CIS/Lynis scores, decrypting the secrets estate, destructive firewall experiments.

---

## 3. Scope matrix

● in-scope for that cycle · ○ optional/light · — N/A

Host columns follow [inventory.yml](../../inventory.yml); they are **examples of coverage**, not a closed list — new nodes inherit the same check types for their role. **Updates snapshot** (§5.1) covers four *kinds* of updates (router, OS, Docker images, native services), not a single `apt` pass.

| Check | proxmox-host | docker-services | nas | lab-vm | reverse-proxy | ai-tools | dns | pulse | vpns | pbs | MikroTik |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| Updates snapshot | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● | ● |
| Lynis | ○ | ● | ● | ● | ● | ● | ● | ● | ● | ● | — |
| Docker Bench | — | ● | — | — | — | — | — | — | — | — | — |
| Firewalls | ● | ● | ● | ● | ● | ● | ● | ○ | ○ | ○ | — |
| CrowdSec | — | ● | ○ | ● | ● LAPI | ○ | ○ | — | — | — | ● bouncer |
| Public surface | — | ○ | — | ○ | ● | ○ | — | — | ○ | — | ● |
| Keys / secrets | — | ● | ○ | ○ | ● | ● | ○ | — | — | — | ● users |
| Backup freshness | ○ | ● | ○ | — | — | ● | — | — | — | ● | ● export |

**Monthly light:** CrowdSec + Caddy skim, MikroTik control-plane + DSTNAT/IPv6 spot-check, key status, backup ages, reboot flags on reverse-proxy + docker-services (and any other host that flags `REBOOT_REQUIRED` during the snapshot). Skip full Lynis/Bench unless something changed.

---

## 4. Pre-flight

```bash
ai-key-unlock && source ~/.ssh/ai-key-agent.sh && ai-key-status

for h in proxmox-host docker-services nas lab-vm reverse-proxy dns ai-tools pulse vpns pbs; do
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" 'hostname' && echo "OK $h" || echo "FAIL $h"
done
ssh -o BatchMode=yes -o ConnectTimeout=5 router '/system resource print' | head
```

- Extend the loop if inventory gains nodes; all of them get the updates snapshot when auditing OS posture.
- Skim private baselines if vault is present (`lynis-audit.md`, `mikrotik-firewall-audit.md`).
- Report mode: `monthly-light` | `quarterly-deep` | `ad-hoc:[focus]`.
- Do not commit audit noise without review.

---

## 5. Checklist

### 5.1 Updates snapshot (info only)

Record posture for **each update kind** below. Do not apply upgrades here — only note pending / stale / deferred. Aligns with the maintenance todo: Router · OS · Docker images · Native services.

| Kind | What | Typical where | How to snapshot |
| :--- | :--- | :--- | :--- |
| **Router** | RouterOS packages / firmware channel | MikroTik | Version + available update (no upgrade mid-audit) |
| **OS** | Hypervisor + guest base systems | All inventory hosts | Channel varies: **Proxmox** host UI/`pve`; **guest apt** (often via **Cockpit**); **OMV** UI on nas — those names are channels, not an exhaustive host list |
| **Docker images** | Container image tags actually *running* | Mainly **docker-services** (any other Docker host if present) | Stale/outdated images vs registry; What’s Up Docker / Diun / `docker images` + compose tags |
| **Native services** | Non-container apps installed on the OS (packages, binaries, unit-managed stacks) | Any host that runs them (e.g. CrowdSec, Caddy package, AdGuard, PBS, Hermes/OpenClaw, fail2ban) | Pending package upgrades for those units, or “version last checked” if install is manual/third-party |

**Pass:** each kind is either current, auto-updating, or **consciously deferred** with a reason. No silent multi-month freeze on internet-facing paths (OS *or* images *or* edge native services).

```bash
# --- OS (every inventory host; loop as pre-flight) ---
ssh [HOST] 'echo "=== OS $(hostname) ==="
  command -v needrestart >/dev/null && needrestart -b 2>/dev/null || true
  test -f /var/run/reboot-required && echo REBOOT_REQUIRED || echo reboot_not_flagged
  apt-get -s upgrade 2>/dev/null | tail -n 15 || true'
# Proxmox host: also note pveversion / UI update state if apt alone is incomplete
# nas: note OMV update UI if that is the real channel

# --- Router ---
ssh router '/system resource print; /system package update print'

# --- Docker images (docker-services; awareness only) ---
ssh docker-services 'docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Status}}" 
  docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.CreatedSince}}\t{{.ID}}" | head -n 40'
# Prefer What’s Up Docker / equivalent if deployed — flag tags many months behind

# --- Native services (examples; adapt to host role) ---
ssh [HOST] 'echo "=== native $(hostname) ==="
  for u in caddy crowdsec fail2ban adguardhome openclaw hermes-gateway; do
    systemctl is-active "$u" 2>/dev/null && echo -n "$u: " && systemctl show "$u" -p FragmentPath --value
  done
  dpkg -l 2>/dev/null | grep -iE "caddy|crowdsec|fail2ban" || true'
# Note third-party / non-apt installs (manual binary, vendor repo) as their own line in the report
```

Report rows by **kind**, not only by host (a node can be green on OS and red on Docker images).

### 5.2 Lynis

**Where:** quarterly on all inventory guests in the matrix (incl. pulse, vpns, pbs). Proxmox bare-metal stays optional (○). Setup: [lynis/setup.md](../02_Services/lynis/setup.md).

**Pass:** no *new* high items outside private ACCEPTED/IGNORE; prior FIXED items (dual DNS, debsums, unattended-upgrades, etc.) not regressed.

**Typical accepts (confirm private baseline):** empty in-guest FW if Proxmox FW is real policy; Docker `0.0.0.0` behind hypervisor FW; no rkhunter/AV on every guest.

```bash
ssh [HOST] 'sudo lynis audit system --quick'
ssh [HOST] 'sudo test -f /var/log/lynis-report.dat && sudo grep -E "warning|suggestion" /var/log/lynis-report.dat | tail -n 80'
```

Tag each finding: `fix now` | `track` | `accept` | `needs-baseline-update`. Do not “fix” baseline exceptions without approval.

### 5.3 Docker Bench + privilege/mount skim

**Where:** docker-services. Path may vary — see [docker-bench/setup.md](../02_Services/docker-bench/setup.md).

**Pass:** no unexpected privileged/host-net/host-pid; public apps lack whole-tree private mounts; Bench WARN/FAIL triaged (many acceptable on single-VM + Proxmox FW).

```bash
ssh docker-services 'cd /opt/docker-bench-security 2>/dev/null || cd "$HOME/docker-bench-security"
  sudo sh docker-bench-security.sh'

ssh docker-services 'docker ps -q | xargs -r docker inspect --format \
  "{{.Name}} privileged={{.HostConfig.Privileged}} net={{.HostConfig.NetworkMode}} pid={{.HostConfig.PidMode}}"'
ssh docker-services 'docker ps -q | while read id; do
  docker inspect "$id" --format "{{.Name}} {{range .Mounts}}{{.Source}}->{{.Destination}} {{end}}"
done'
```

### 5.4 Firewalls (Proxmox / UFW / OMV)

**Pass:** only documented internet paths; mgmt (SSH, PVE UI, Winbox, SMB) not on WAN; isolation consistent with §5.5. Authority may be Proxmox-only (empty guest UFW is OK if baseline says so).

```bash
ssh proxmox-host 'pve-firewall status 2>/dev/null; ls /etc/pve/firewall/ 2>/dev/null | head'
ssh [HOST] 'sudo ufw status verbose 2>/dev/null || echo no-ufw'
# Also: nodes/*/scripts/*firewall* or ufw.sh vs live; OMV UI on nas if used
```

Record per host: authority `proxmox` | `ufw` | `omv` | `none+edge` + deltas.

### 5.5 MikroTik + IPv6 + isolation

**Where:** `router` (read-only skim; optional latest vault export). Do not change filter/VLAN state during audit.

```bash
ssh router '/system resource print; /ip service print; /user print'
ssh router '/ip firewall filter print without-paging'
ssh router '/ipv6 firewall filter print without-paging'
ssh router '/ip firewall nat print without-paging'
ssh router '/interface bridge vlan print detail'
ssh router '/ip dhcp-server network print'
```

| Item | Intent |
| :--- | :--- |
| Default-deny | Input/forward catch-alls still drop noise |
| Untrusted isolation | Homelab/guest ↛ private/trusted except narrow docs |
| WAN publish | DSTNAT only for intended services |
| IPv6 | Not weaker than IPv4 intent |
| Control plane | FTP/www/proxy off; Winbox/API/SSH source-limited; `admin` disabled |
| CrowdSec | Bouncer/lists still on input/forward |
| DNS | Clients → AdGuard (failover not permanent public DNS) |
| Bridge VLAN filtering | Still on if that is lab standard |
| Agent users | `svc_backup` / `svc_ai` intact; no orphan full-priv users |

**Optional probes** (operator-approved only): untrusted → private RFC1918 fails; untrusted → WAN works if allowed; WAN → random high ports closed. Else rule-review only.

### 5.6 CrowdSec (+ fail2ban)

**Where:** reverse-proxy = LAPI; sentinels on exposed nodes; MikroTik bouncer.

**Pass:** LAPI up; bouncers connected; expected *roles* registered; metrics show parsing (empty decisions OK on quiet days). Not every LXC needs an agent.

```bash
ssh reverse-proxy 'sudo systemctl is-active crowdsec
  sudo cscli metrics; sudo cscli machines list; sudo cscli bouncers list
  sudo cscli decisions list -l 20; sudo cscli collections list
  sudo fail2ban-client status 2>/dev/null || true'
ssh docker-services 'sudo systemctl is-active crowdsec 2>/dev/null; sudo cscli metrics 2>/dev/null | head'
```

Output: host → agent / bouncer / none + gaps.

### 5.7 Public surface (Caddy + DSTNAT)

**Pass:** live public set ⊆ documented set; admin UIs blocked/VPN/extra-auth; direct forwards still required; monitors not full of ignored reds.

```bash
ssh reverse-proxy 'sudo systemctl is-active caddy
  sudo caddy validate --config /etc/caddy/Caddyfile 2>/dev/null || true
  sudo grep -E "handle |reverse_proxy |basicauth |^[^#[:space:]].*\\{" /etc/caddy/Caddyfile 2>/dev/null | head -n 200'
ssh router '/ip firewall nat print where action=dst-nat'
```

Table: name/port → backend → auth → status.

### 5.8 Keys & secrets hygiene

**Pass:** God Mode/SOPS not left unlocked idle; live secrets ~`600` (doc’d exceptions only); no cleartext secret commits; no unknown SSH keys / MikroTik users.

```bash
ai-key-status
command -v sops-key-status >/dev/null && sops-key-status || true

ssh docker-services 'find /srv -maxdepth 3 \( -name "*.env" -o -name "*.secret" -o -name "*.pwd" \) \
  -printf "%m %u:%g %p\n" 2>/dev/null | head -n 50'
# Repo: git status/diff for accidental cleartext secrets — do not cat values
# High-value hosts: spot-check authorized_keys for unknown entries
```

### 5.9 Backup freshness (not a backup window)

See [backup-playbook.md](./backup-playbook.md). One-liners only:

- Kopia snapshot ages (docker-services)
- PBS last guest backups
- MikroTik export age (ai-tools vault capture)
- Optional: secrets scrape still *runnable* (do not dump vault)

```bash
ssh docker-services 'CFG=/opt/scripts/Backups/Kopia/config/main-repo.config
  sudo kopia --config-file "$CFG" snapshot list 2>/dev/null | tail -n 20'
```

### 5.10 Optional extras (deep / after incident)

| Extra | Why |
| :--- | :--- |
| Inventory vs reality | CTs/VMs/stacks vs `inventory.yml` + deployment.md |
| Image CVE skim | Trivy/Grype on public images (later) |
| `debsums` sample | Package integrity on a few hosts |
| AI-tools backlog | Egress filter, `/tmp` noexec — private hardening note |
| SMB / share ACLs | Public apps lack full private trees |
| Tailscale ACLs | Overlay least-privilege (bypasses VLANs) |

---

## 6. Session wrap-up

1. `ai-key-lock` (+ `sops-key-lock` if used).
2. Fill report template (§7); prefer private vault for raw detail.
3. File open actions with host + severity.
4. Doc fixes (sanitised) if public intent was wrong — not chat-only.
5. No agent scratch/logs into git unless asked.

---

## 7. Report template

```markdown
# Security audit report — [YYYY-MM-DD]

- **Mode:** monthly-light | quarterly-deep | ad-hoc:[focus]
- **Operator / agent:**
- **Hosts in scope:**
- **Key unlock:** yes/no (TTL …)

## Summary
| fix now | track | accept | needs-baseline-update |
| ---: | ---: | ---: | ---: |
|  |  |  |  |

## Updates snapshot
| Kind | Where | Pending / stale? | Channel | Notes |
| :--- | :--- | :--- | :--- | :--- |
| Router | MikroTik |  | RouterOS |  |
| OS | [host…] | reboot? | PVE / apt·Cockpit / OMV |  |
| Docker images | docker-services |  | compose tags / WUD |  |
| Native services | [host + unit…] |  | apt / vendor / manual |  |

## Findings
| ID | Host | Check | Severity | Evidence | Action |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 1 |  |  |  |  |  |

## Public surface
| Name / port | Backend | Auth | Status |
| :--- | :--- | :--- | :--- |
|  |  |  |  |

## CrowdSec
- LAPI:
- Bouncers:
- Gaps:

## Backup freshness
- Kopia:
- PBS:
- MikroTik export:

## Follow-ups
1.
```

---

## 8. Monthly light (copy-paste order)

1. Pre-flight reachability + `ai-key-status`
2. reverse-proxy: CrowdSec metrics/bouncers + Caddy active + quick site skim
3. router: `/ip service print`, DSTNAT, filter tails IPv4 + IPv6
4. Backup ages (Kopia / PBS / MikroTik export)
5. OS reboot flags + quick Docker image / critical native-service skim (not full upgrade work)
6. Short report + file **fix now** only
7. `ai-key-lock`
