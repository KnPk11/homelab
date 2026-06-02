> [!NOTE]
> **Tags:** #MikroTik #Logging #Syslog #rsyslog

# Set Up Syslog Receiver

## 1. Install rsyslog
(Likely pre-installed on most Linux distributions):
```bash
sudo apt install rsyslog
```

## 2. Enable UDP Listener
Modify `/etc/rsyslog.conf` to enable the UDP listener:
```
# Uncomment or add these lines
module(load="imudp")
input(type="imudp" port="514")
```

## 3. Create MikroTik Configuration
Create a configuration file at `/etc/rsyslog.d/mikrotik.conf`:
```
# Capture logs from your MikroTik IP
if $fromhost-ip == '[ROUTER-IP]' then {
    action(type="omfile" file="/mnt/logs/mikrotik/mikrotik.log")
    stop
}
```

## 4. Initialise Directory and Restart
```bash
sudo mkdir -p /mnt/logs/mikrotik
sudo systemctl restart rsyslog
```

## 5. Configure MikroTik RouterOS
Run the following commands on your MikroTik router:
```bash
/system logging action
add name=remote-syslog target=remote remote=[SYSLOG-SERVER-IP] port=514 bsd-syslog=yes

/system logging
add action=remote topics=info
add action=remote topics=warning
add action=remote topics=error
add action=remote topics=critical
```

> [!TIP]
> **Firewall**: Ensure your host firewall allows UDP port `514`.

> [!WARNING]
> **Log Volume**: Enabling logging for all rules is not recommended as it adds CPU overhead and generates excessive noise.

---

# Enable Logrotate (Optional)

Create `/etc/logrotate.d/mikrotik`:
```
/mnt/logs/mikrotik/*.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 syslog adm
    sharedscripts
    postrotate
        systemctl kill -s HUP rsyslog.service
    endscript
}
```

### Verification
```bash
sudo logrotate -d /etc/logrotate.d/mikrotik  # Dry run
sudo logrotate -f /etc/logrotate.d/mikrotik  # Force rotate now
```
