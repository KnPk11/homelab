# Lab-VM-91 Master Bootstrap Guide

This node (`lab-vm`, `192.168.50.91`, Proxmox VM 103) is the primary application, developer, and AI agent workload host.

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit tracked configurations directly on the server. Instead, push updates to Git, pull them on the server (`auto_pull_repo.sh`), and restart the respective services.

If this machine ever suffers a catastrophic failure, follow the deployment guides below in this exact order to nuke-and-pave it back to a working state.

---

## 1. System Bootstrap & User Linger

1. **Universal Bootstrap:** Follow the **[Universal Node Bootstrap Guide](../../shared/docs/universal-node-bootstrap.md)** to install base prerequisites and link GitOps.
2. **Cron Offset:** Stagger `auto_pull_repo.sh` at minute **36**:
   ```bash
   (crontab -l 2>/dev/null; echo '36 * * * * /opt/homelab-repo/shared/scripts/auto_pull_repo.sh >> /var/log/auto_pull.log 2>&1') | sort -u | crontab -
   ```
3. **User Process Linger:** Required for user-level systemd daemons (`hermes`, `openclaw`) to persist across terminal logouts:
   ```bash
   sudo loginctl enable-linger k
   ```
4. **Firewall Script:** Apply [`scripts/firewall.sh`](scripts/deployment.md).

---

## 2. Paperclip Service

App guide & reverse proxy: [docs/02_Services/paperclip/setup.md](../../docs/02_Services/paperclip/setup.md).

* **Runtime Path:** `/opt/paperclip/data/instances/default/` (owned by `k:k`).
* **Secrets:** Decrypted directly from the repo using SOPS:
  ```bash
  # 1. Provision directories
  sudo install -d -o k -g k /opt/paperclip /opt/paperclip/data /opt/paperclip/data/instances/default/secrets

  # 2. Decrypt env and keys
  sops -d nodes/lab-vm/services/paperclip/.env > /opt/paperclip/data/instances/default/.env
  sops -d nodes/lab-vm/services/paperclip/secrets/master.key.secret | jq -r .data > /opt/paperclip/data/instances/default/secrets/master.key
  sops -d nodes/lab-vm/services/paperclip/secrets/decision-signing.key.secret | jq -r .data > /opt/paperclip/data/instances/default/secrets/decision-signing.key

  # 3. Secure permissions & start
  chmod 600 /opt/paperclip/data/instances/default/.env /opt/paperclip/data/instances/default/secrets/*
  chown -R k:k /opt/paperclip/data/instances/default
  sudo systemctl daemon-reload && sudo systemctl enable --now paperclip
  ```

---

## 3. Hermes Agent Service

App guide: [docs/02_Services/hermes/setup.md](../../docs/02_Services/hermes/setup.md).

* **Runtime Path:** `/home/k/.hermes/` (owned by `k:k`).
* **Secrets & Config:** Restored from `secrets_vault/configs_and_secrets/lab-vm/home/k/.hermes/` (`config.yaml`, `.env`, `auth.json`). Reference blueprint: [`services/hermes/hermes.reference.yaml`](services/hermes/hermes.reference.yaml).
* **Systemd User Units:** Link tracked service units to `~/.config/systemd/user/`:
  ```bash
  mkdir -p /home/k/.config/systemd/user
  ln -sf /opt/homelab-repo/nodes/lab-vm/services/hermes/hermes-gateway.service /home/k/.config/systemd/user/
  ln -sf /opt/homelab-repo/nodes/lab-vm/services/hermes/hermes-dashboard.service /home/k/.config/systemd/user/
  systemctl --user daemon-reload
  systemctl --user enable --now hermes-gateway
  ```

---

## 4. OpenClaw Service

App guide: [docs/02_Services/openclaw/setup.md](../../docs/02_Services/openclaw/setup.md).

* **Runtime Path:** `/home/k/.openclaw/` (owned by `k:k`).
* **Secrets & Config:** Restored from `secrets_vault/configs_and_secrets/lab-vm/home/k/.openclaw/openclaw.json`. Reference blueprint: [`services/openclaw/openclaw.reference.json`](services/openclaw/openclaw.reference.json).
* **Systemd User Unit:** Link tracked unit:
  ```bash
  mkdir -p /home/k/.config/systemd/user
  ln -sf /opt/homelab-repo/nodes/lab-vm/services/openclaw/openclaw-gateway.service /home/k/.config/systemd/user/
  systemctl --user daemon-reload
  systemctl --user enable --now openclaw-gateway
  ```
