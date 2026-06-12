# LAN Discovery Setup

> [!NOTE]
> **Tags:** #Avahi #Wsdd #Mdns #Discovery #Networking #Lan #DockerCompose

## 1. Avahi Configuration (Linux & MacOS)

> [!NOTE]
> This is required for Linux and MacOS SAMBA network discovery.

1. Edit the Avahi daemon configuration file:

   ```bash
   sudo nano /etc/avahi/avahi-daemon.conf
   ```

2. Disable IPv6 by adding or modifying the following line:

   ```bash
   use-ipv6=no
   ```

3. Create an Avahi services directory:

   ```bash
   mkdir -p /home/services/avahi
   ```

4. Create a Samba service file:

   ```bash
   sudo nano /home/services/avahi/samba.service
   ```

5. Add the following content:

   ```xml
   <?xml version="1.0" standalone='no'?>
   <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
   <service-group>
     <name replace-wildcards="yes">%h</name>
     <service>
       <type>_smb._tcp</type>
       <port>445</port>
     </service>
     <service>
       <type>_device-info._tcp</type>
       <port>0</port>
       <txt-record>model=LinuxSamba</txt-record>
     </service>
   </service-group>
   ```

6. Add LAN-only discovery rules (IPv4):

   ```bash
   sudo ufw allow from [LAN-IP-RANGE] to any port 5353 proto udp
   ```

## 2. WSDD Configuration (Windows)

> [!NOTE]
> This is required for Windows SAMBA network discovery.

1. Add LAN-only discovery rules (IPv4):

   ```bash
   sudo ufw allow from [LAN-IP-RANGE] to any port 3702 proto udp
   sudo ufw allow from [LAN-IP-RANGE] to any port 5357 proto tcp
   ```

## 3. Security Hardening

> [!IMPORTANT]
> Ensure the following security measures are implemented:

- **Restrict UFW discovery rules** to the LAN only (`[LAN-IP-RANGE]`).
- Use your host's IP in Docker `ports:` configuration to avoid wildcard exposure.
