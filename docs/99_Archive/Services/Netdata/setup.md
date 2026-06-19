# Netdata Setup

> [!NOTE]
> **Tags:** #Netdata #SystemStats #Monitoring #DockerCompose

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
