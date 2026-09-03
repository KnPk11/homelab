# SOPS + age — Master vs node keys (ai-tools)

> [!NOTE]
> #SOPS #Age #Security #Homelab
>
> **Host:** `ai-tools` | **Master TTL:** 15 minutes

God Mode SSH (`ai-key-unlock`) and SOPS (`sops-key-unlock`) are **different keys**. SSH logs you into boxes. Age encrypts files in Git. Unlocking one does not unlock the other.

## Intent

Appliance nodes (Caddy, NAS, …) reboot unattended and must decrypt their own `.env` / `.secret` files. This node is the **operator workstation**: you sit here, paste the Master Admin age key, edit secrets, write plaintext into `/srv/…`. No systemd unit on `ai-tools` calls `sops`.

## Who can open a file

`.sops.yaml` wraps each `nodes/<host>/…` secret for **two** age public keys:

1. **Master Admin** — private key is not stored on disk. `sops-key-unlock` pastes it into `/dev/shm` (~15 min). `~/.config/sops/age/keys.txt` on this host is only a symlink to that RAM file.
2. **That host’s node key** — private key lives at `/root/.config/sops/age/keys.txt` **on that host**, so CrowdSec/Caddy/etc. can decrypt after reboot.

A foothold on `docker-services` can open *docker-services* secrets with the local node key. It cannot open `reverse-proxy` secrets or Master-only files.

`ai-tools` Git secrets (for example Homelab Watch `telegram.env`) are still listed for Master **and** the ai-tools public key, same pattern as other nodes. The matching **private** node key is **not** installed here; you decrypt those files with the Master. If that node private key were ever dropped into a standing `keys.txt` on this box, it could open every file that lists the ai-tools recipient — including operator maps that happen to use the same pair.

Operator-only maps that must stay Master-gated should be encrypted for the **Master recipient only**, and kept off the GitOps clone.

## Commands

```bash
sops-key-unlock    # paste Master Admin AGE-SECRET-KEY-1… into RAM
sops-key-status
sops-key-lock      # or wait for the TTL watchdog
```

Scripts: `sops-key-unlock.sh`, `sops-key-lock.sh`, `sops-key-status.sh`, `sops-key-ttl-watchdog.sh` in this directory.
