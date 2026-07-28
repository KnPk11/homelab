# Netdata Setup

> [!NOTE]
> #Netdata #SystemStats #Monitoring #DockerCompose

## 1. Description

A real-time health monitoring and performance troubleshooting tool that provides unparalleled insights into everything happening on your systems and applications.

## 2. Installation

1. **Configuration**: Edit the Netdata configuration file:

   ```bash
   sudo nano /home/services/netdata/config/netdata.conf
   ```

2. **Web Settings**: Add the following lines to the `[web]` block to allow connections:

   ```ini
   [web]
       allow connections from = *
       web mode = static-threaded
   ```

## 3. Security

- Exposing Netdata publicly is a significant reconnaissance risk; keep the dashboard on the LAN, or protect it with reverse-proxy basic auth / a secure account.
- If access is LAN-only, other dashboards (e.g. Heimdall) can still scrape metrics via the internal URL: `http://netdata:19999`.
