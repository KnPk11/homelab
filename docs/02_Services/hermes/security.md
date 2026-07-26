# Hermes Security

> [!NOTE]
> **Tags:** #Security #Firewall #UFW #Proxmox #HomeLab

The Hermes service is protected by a multi-layered security architecture ensuring that the dashboard and the underlying API keys are shielded from unauthorised access.

---

## Security Layers

### 1. Perimeter Defence (Router)
The **MikroTik Router** acts as the primary barrier. 
- No port forwarding rules are configured for the Hermes dashboard port (`9119`).
- Direct access from the public internet is completely blocked at the edge.

### 2. Hypervisor Firewall (Proxmox)
The **Proxmox VE Firewall** provides a second layer of isolation at the guest network interface level.
- **Rule Policy**: Only the Caddy Reverse Proxy is permitted to communicate with the Hermes port on the OpenClaw VM.
- All other internal traffic to the dashboard port is dropped before it reaches the VM.

### 3. Guest Firewall (UFW)
The **Uncomplicated Firewall (UFW)** is active on the OpenClaw VM itself.
- Restricted to internal trusted subnets (`[LAN-TRUSTED].0/24` and `[LAN-SERVERS].0/24`).
- Provides a final internal check for all incoming packets.

### 4. Application Access Policy (Caddy)
The Caddy reverse proxy enforces a LAN-only access policy.
- Requests from non-local IP addresses are rejected with a `403 Forbidden` response.
- This ensures that even if the domain name is known, the dashboard cannot be reached from outside the trusted network.

---

## Service Binding

> [!IMPORTANT]
> **Safety Justification**
> 
> The Hermes dashboard is bound to `0.0.0.0` within the VM to allow communication with the reverse proxy. While binding to `0.0.0.0` is typically less secure, it is safe in this environment due to the **Proxmox Firewall** and **MikroTik** perimeter, which ensure that only the verified reverse proxy container can physically reach the port.

---

## Authentication & Hardening

### Native Authentication
Hermes utilises a native authentication gate for non-loopback binds. This is configured utilising:
- **Username**: Configured via environment variables.
- **Password Hashing**: Utilises `scrypt` hashing for high resistance to brute-force attacks.
- **Session Signing**: A stable 32-byte secret ensures session integrity across service restarts.

### Hardening Recommendations
- **Localhost Binding**: If the Proxmox firewall is ever disabled, the service should be re-bound to `127.0.0.1` or restricted via UFW specifically to the Caddy LXC IP.
- **Credential Rotation**: Regularly rotate the dashboard password and the session secret utilised for signing tokens.
