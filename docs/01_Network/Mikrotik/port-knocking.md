> [!NOTE]
> **Tags:** #MikroTik #Security #PortKnocking #SSH

# Port Knocking Configuration

Port knocking acts as an emergency backdoor to your router. It allows you to temporarily whitelist your current IP address to access management services (like SSH or the Web UI) from the internet.

## RouterOS Firewall Rules

```bash
# Stage 1: First knock
/ip firewall filter add chain=input protocol=tcp dst-port=[KNOCK-PORT-1] \
    connection-state=new \
    action=add-src-to-address-list \
    address-list=knock_stage1 \
    address-list-timeout=5s \
    comment="Port Knock: Stage 1" \
    place-before=[find where comment~"rate-limited SSH"]

# Stage 2: Second knock (must have passed stage 1)
/ip firewall filter add chain=input protocol=tcp dst-port=[KNOCK-PORT-2] \
    connection-state=new \
    src-address-list=knock_stage1 \
    action=add-src-to-address-list \
    address-list=knock_stage2 \
    address-list-timeout=5s \
    comment="Port Knock: Stage 2" \
    place-before=[find where comment~"rate-limited SSH"]

# Stage 3: Third knock → grants access for 30 min
/ip firewall filter add chain=input protocol=tcp dst-port=[KNOCK-PORT-3] \
    connection-state=new \
    src-address-list=knock_stage2 \
    action=add-src-to-address-list \
    address-list=knock_allowed \
    address-list-timeout=30m \
    comment="Port Knock: Stage 3 - Access granted" \
    place-before=[find where comment~"rate-limited SSH"]

# Allow SSH from knocked IPs (BEFORE "Drop ALL other SSH")
/ip firewall filter add chain=input protocol=tcp dst-port=22 \
    src-address-list=knock_allowed \
    action=accept \
    comment="Port Knock: Allow SSH" \
    place-before=[find where comment~"rate-limited SSH"]

# Allow Web UI from knocked IPs
/ip firewall filter add chain=input protocol=tcp dst-port=8443 \
    src-address-list=knock_allowed \
    action=accept \
    comment="Port Knock: Allow Web UI" \
    place-before=[find where comment~"rate-limited SSH"]
```

## Test Sequence

From an external machine (e.g., a phone hotspot):

### Windows (PowerShell)

```powershell
@for %p in ([KNOCK-PORT-1] [KNOCK-PORT-2] [KNOCK-PORT-3]) do @(echo Knocking port %p & start /b powershell -c "(New-Object System.Net.Sockets.TcpClient).BeginConnect('[DDNS_NAME].sn.mynetname.net', %p, $null, $null)" >nul 2>&1 & timeout /t 2 /nobreak >nul)
```

### Linux (Bash)

```bash
# 1. Confirm SSH is blocked before knocking
nc -zv [DDNS_NAME].sn.mynetname.net 22

# 2. Perform the knock
for port in [KNOCK-PORT-1] [KNOCK-PORT-2] [KNOCK-PORT-3]; do
    nmap -Pn --max-retries 0 -p $port [DDNS_NAME].sn.mynetname.net >/dev/null 2>&1
    sleep 1
done

# 3. Confirm SSH now works
ssh [USER]@[DDNS_NAME].sn.mynetname.net
```

### Verification

While testing, monitor the address lists in real-time from a WinBox session:

```bash
/ip firewall address-list print where list~"knock"
```

## Road Emergency Tips

Install a port knock app on your phone (**"Port Knocker"** on Android, **"Knock on Ports"** on iOS). Save your sequence and the router's DDNS URL.

> [!TIP]
> Ensure you allow enough time between each knock (e.g., 1 second) to account for network latency.
