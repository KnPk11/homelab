# CrowdSec Fail2Ban Integration

> [!NOTE]
> **Tags:** #crowdsec #fail2ban #security #linux

This document describes the "Bridge" architecture used to synchronise Fail2Ban detections with the network-wide CrowdSec firewall. Instead of blocking locally only, Fail2Ban delegates enforcement to CrowdSec, which then pushes the ban to the MikroTik Edge router.

## 1. Create the CrowdSec Action

Create the action file at `/etc/fail2ban/action.d/crowdsec.conf`. This script tells Fail2Ban to use the native CrowdSec CLI (`cscli`) to add or remove decisions.

```ini
[Definition]
# Use <ip> and <bantime> (seconds) from Fail2Ban. 
# We use 's' suffix for CrowdSec duration.
actionban = cscli decisions add --ip <ip> --duration <bantime>s --reason 'Fail2Ban: <name>'
actionunban = cscli decisions delete --ip <ip>
```

## 2. Enable the Bridge in Fail2Ban

Update your `/etc/fail2ban/jail.local` to use this new action as the default `banaction`. This ensures that any jail (SSH, Caddy, etc.) automatically pushes its bans to CrowdSec.

```ini
[DEFAULT]
banaction = crowdsec
# ... other default settings
```

## 3. Verify the Integration

### Check Fail2Ban Status
Ensure Fail2Ban has reloaded the configuration:

```bash
sudo fail2ban-client reload
sudo fail2ban-client status
```

### Manual Test
Simulate a ban and verify it appears in CrowdSec:

1.  **Trigger a Manual Ban**:
    ```bash
    sudo fail2ban-client set [JAIL-NAME] banip 1.2.3.4
    ```
2.  **Verify in CrowdSec**:
    ```bash
    sudo cscli decisions list
    ```
    You should see an entry with the reason `Fail2Ban: [JAIL-NAME]`.
3.  **Verify on MikroTik**:
    Check the Address List `CrowdSec_Blacklist` on the router.
4.  **Clean Up**:
    ```bash
    sudo fail2ban-client set [JAIL-NAME] unbanip 1.2.3.4
    ```

---
> [!TIP]
> **Double-Layer Protection**: Detections forwarded via this bridge will be enforced at both the OS level (via the CrowdSec Firewall Bouncer) and the Network level (via the MikroTik Bouncer).
