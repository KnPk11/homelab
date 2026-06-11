# Jellyfin Setup

> [!NOTE]
> **Tags:** #jellyfin #media #streaming #video #docker_compose

## 1. Device Identification

Find what video acceleration devices the Raspberry Pi has:

   ```bash
   v4l2-ctl --list-devices
   ```

## 2. Configuration

Update the `docker-compose.yml` with these variables.

> [!NOTE]
> Do not enable or require HTTPS through Jellyfin's admin if utilising Caddy.
> Do not set any base URL; Caddy will handle this.

## 3. Subpath Configuration

Set the base URL under `Networking` if you wish to run Jellyfin in a subpath.

## 4. Deployment

Start the stack in Portainer.

## 5. Port-forwarded Setup (Optional)

If you need to configure Jellyfin with a certificate for direct port forwarding:

1. Copy the certificate archive to the required directory:

   ```bash
   cd home/services/certs
   ```

2. Extract the certificates:

   ```bash
   openssl pkcs12 -export \
     -out jellyfin.pfx \
     -inkey key.pem \
     -in cert.pem \
     -certfile cacert.pem
   ```

3. Set access permissions:

   ```bash
   chmod 750 home/services/certs
   chmod 640 home/services/certs/*
   ```

4. Enable HTTPS and add the certificate through the Jellyfin Admin panel.
5. Enable port forwarding: 8096 TCP.
6. Refer to the Docker Compose snippet for the port-forwarded setup.

   > [!NOTE]- Port-forwarded Docker Compose snippet
   > 
   > ```yml
   >   jellyfin:
   >     image: lscr.io/linuxserver/jellyfin:10.10.7
   >       - /data/certs:/certs:ro # Manually mounted certificate for port-binded setup
   >     ports: # Port-binded setup
   >       - 8096:8096               # HTTP
   >       - 8920:8920               # HTTPS (optional, needs config)
   >       - 7359:7359/udp           # DLNA discovery (optional)
   >       - 1900:1900/udp           # DLNA SSDP (optional)
   >     environment:
   >       - JELLYFIN_PublishedServerUrl=http://[HOST-IP]  # Optional but useful on LAN.
   > ```
