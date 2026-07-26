# Copyparty Setup

> [!NOTE]
> **Tags:** #Copyparty #FileSharing #Storage #DockerCompose

## 1. Description

A lightweight, feature-rich file server and collaboration tool that provides a web interface for uploading, downloading, and managing files with ease. It supports features like image thumbnails, audio/video streaming, and detailed permission controls.

## 2. Installation

1. **Prepare Directories**: Create the necessary directories for configuration and data on the host machine:
   
   ```bash
   sudo mkdir -p /srv/copyparty/{config,data}
   sudo chown -R 1000:1000 /srv/copyparty/
   ```

2. **Configuration**: Optionally, create a `copyparty.conf` file in the `/srv/copyparty/config` directory to define users and permissions.
3. **Deployment**: Add the Docker Compose stack into Portainer and start the service. Ensure your volumes correctly map to the prepared `/srv/copyparty/` directories.
4. **Access**: Access the web UI at the mapped port (default is usually `3923`) or via your configured reverse proxy domain.
