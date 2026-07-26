# MediaMTX Setup

> [!NOTE]
> **Tags:** #MediaMTX #Streaming #Rtsp #Networking #DockerCompose

## 1. Installation

1. Copy the Docker Compose stack to Portainer and start it.

2. Install and configure the `mediamtx.yml` file.

## 2. OBS Configuration

To stream via OBS, use the following settings:

- **URL:** ``rtmp://[HOST-IP]:1935/live`
- **Key:** `stream?user=[USER]&pass=[SECRET]`

## 3. Access URLs

Utilise the following URLs for stream access:

- **HLS Stream:** `http://homelab.local:8888/live/index.m3u8`
- **RTSP Stream:** `rtsp://homelab.local:8554/live`
- **RTSP Stream (VRChat):** `rtspt://homelab.local:8554/live`

## 4. Logging Configuration

1. Create the log directory and file:

   ```bash
   mkdir /srv/mediamtx/logs
   touch /srv/mediamtx/logs/mediamtx.log
   ```

2. Add the following environment variables to the Docker Compose file and mount the logs directory:

   ```yml
         - MTX_LOGDESTINATIONS=stdout,file
         - MTX_LOGFILE=/logs/mediamtx.log
   ```

> [!NOTE]
> These variables should be added to the environment section as they may not function correctly within `mediamtx.yml`.

## 5. Security Hardening

> [!IMPORTANT]
> Ensure the following security measures are implemented to protect your stream:

- **Enable Authentication:** Ensure that authentication is active for all streams.
- **Credential Placement:** When streaming through OBS, include the credentials in the stream key: `stream?user=[USER]&pass=[SECRET]`.
- **Password Hashing:** Consider hashing passwords for enhanced security.
- **Restrict IP Access:**
  - Implement IP-based restrictions within the `mediamtx.yml` configuration.
  - Alternatively, utilise UFW to manage access:

    ```bash
    sudo ufw deny in on eth0 to any port 1935,8554,8888 proto tcp
    ```

- **Reverse Proxy:** Move HTTP control ports (8888, 8889) behind Caddy for TLS and additional security.
- **Router Security:** Limit open ports on your router to only those essential for your services (e.g., RTMP or WebRTC).
