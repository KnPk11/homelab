# WAN saturation (ai-tools)

Minute timer on **ai-tools**. Reads `pppoe-out1` via `mikrotik-backup` (no God Mode). Homelab Watch if RX or TX stays at **85%** of the circuit for **two** samples; clears at 70%. One message up, one when it drops back.

This is “the pipe is full,” not a DDoS label. A family download can trip it. CrowdSec still will not see volumetric floods.

Circuit defaults: **900 Mbps down / 110 Mbps up**. Edit `/etc/default/wan-saturation` if the ISP rate changes.

```bash
sudo /opt/dev/homelab_repo/nodes/ai-tools/services/wan-saturation/deploy.sh
wan-saturation --dry-run
```

Do not threshold `ether1` (1G to the modem). The PPPoE session is the circuit.
