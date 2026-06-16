# Wireguard Setup

> [!NOTE]
> **Tags:** #Wireguard #Vpn #Networking #Docker

## 1. Description

A communication protocol and free and open-source software that implements encrypted virtual private networks (VPNs). In general, a dedicated VPN service should be created for each separate application that requires it.

> [!TIP]
> Refer to the Pinchflat service documentation for a practical example of this configuration.

## 2. Installation

1. **Add the VPN Container**: Add the Wireguard container to your `docker-compose.yml`, mounting the configuration file provided by your VPN provider:
   
   ```yaml
   version: '3.8'

   services:
     vpn-secure-wireguard:
       image: linuxserver/wireguard:arm64v8-latest
       container_name: vpn-secure-wireguard
       cap_add:
         - NET_ADMIN
       volumes:
         - /srv/vpns/vpn-secure-wireguard/[VPN-CONFIG].conf:/config/wg0.conf
       sysctls:
         - net.ipv4.conf.all.src_valid_mark=1
       expose:
         - 8945
       networks:
         - caddy_shared
   ```

2. **Configure the Core Service**: Update the core service to utilise `network_mode`, pointing it at the VPN container. Ensure the `networks` and `expose` sections are removed from the core service:
   
   ```yaml
       network_mode: "service:vpn-secure-wireguard"
       depends_on:
         - vpn-secure-wireguard
       # expose:
       #   - 8945
       # networks:
       #   - caddy_shared
   ```

3. **Reverse Proxy Configuration**: In your `Caddyfile`, redirect traffic to point at the VPN container:
   
   ```caddyfile
   pinchflat.homelab.local {
       import ...
       reverse_proxy vpn-secure-wireguard:8945
   }
   ```

## 3. Verification

Verify the setup by checking the external IP address of the containers:

```bash
docker exec -it vpn-secure-wireguard curl ifconfig.me 
docker exec -it pinchflat curl ifconfig.me
```
