# SMB `logs` share

> [!NOTE]
> #SMB #Backup

Read-only Windows backup of `/mnt/logs`, same idea as reverse-proxy `\\…\logs`.

```bash
sudo /opt/homelab-repo/nodes/syslog/services/smb/deploy.sh
sudo smbpasswd -a loguser   # same password as //reverse-proxy/logs
```

`\\192.168.50.89\logs` → `/mnt/logs` (`auth/<host>/auth.log`). User **`loguser`**. Firewall group `file-svc` (main LAN / VPN / win11), not `file-svc-logs` (Spark).
