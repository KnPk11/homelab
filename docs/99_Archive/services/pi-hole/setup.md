# Pi-hole Setup

> [!NOTE]
> **Tags:** #PiHole #Dns #Security #Adblock #Networking

## 1. Description

A network-wide ad blocker that acts as a DNS sinkhole, protecting devices from advertisements and tracking without requiring any client-side software.

## 2. Installation

1. **Password Configuration**: Set or change the administrator password:
   
   ```bash
   docker exec -it pihole bash 
   pihole setpassword [SECRET]
   ```

2. **DNS Settings**: In the Pi-hole Web UI (**Settings** -> **DNS**), configure the following:
   - **Interface Settings**: Select **Permit all origins**. This is often required when running Pi-hole in Docker to ensure it responds to queries from different network interfaces.
   - **Advanced DNS Settings**: Optionally review the setting for forwarding reverse lookups for private IP ranges.

3. **Router Configuration**: Update your router's WAN DNS settings to use the device's internal IP as the primary server. Consider setting a reliable secondary DNS provider as a backup.
