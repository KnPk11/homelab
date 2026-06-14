# qBittorrentVPN Setup

> [!NOTE]
> **Tags:** #Torrent #Downloader #Media #Vpn #Openvpn #DockerCompose

## 1. Description

A VPN enabled torrent client that includes a kill switch.

## 2. Installation

1. Add the Docker Compose stack to Portainer and start it.
2. Set up service account credentials via a VPN provider of choice.
3. Drop the OpenVPN configuration file under:
   
   ```cfg
   /srv/qbittorrentvpn/openvpn
   ```

4. For VPN Secure also drop these files in the same location:
   
   ```text
   ca.crt
   [USER].crt
   [USER].key
   [USER].ovpn
   dh2048.pem
   ```

5. Then add this line into `[USER].ovpn`:
   
   ```text
   askpass openvpn_password.txt
   ```

6. `openvpn_password.txt` is meant to store the user password for VPN Secure. Secure it by:
   
   ```bash
   chmod 600 /srv/qbittorrentvpn/openvpn/openvpn_password.txt
   ```

7. Check that it is utilising the VPN's IP by comparing it to the host IP:
   
   ```bash
   docker exec -it qbittorrentvpn curl ifconfig.io
   curl ifconfig.io
   ```

8. Use the following temporary credentials:
   - User: `[USER]`
   - Password: Found in `/srv/qbittorrentvpn/config/supervisord.log`

## 3. Security

- Ensure GUI authentication is enabled.
- Bind to LAN interface.
- Make sure to utilise service account credentials from VPN provider.
- Make sure to test that it is utilising the VPN.
