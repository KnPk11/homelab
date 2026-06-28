# Pi-desktop Setup

> [!NOTE]
> **Tags:** #PiDesktop #Linux #VNC #DockerCompose #DesktopEnvironment

## 1. Description

A self-hosted, containerised Linux desktop environment running Ubuntu Jammy with LXQt. This allows you to access a full graphical Linux desktop environment remotely via a VNC client.

## 2. Initial Setup

1. **Deploy Container**: Add the Docker Compose stack into Portainer or deploy it directly via docker-compose.
   
2. **Access via VNC**: Use a VNC client (e.g., RealVNC, TigerVNC, or built-in OS tools) to connect to the container.
   - **Address**: `[HOST_IP]:5901`
   - **Default Resolution**: 1920x1080 (configurable in the compose file via `RESOLUTION`).

3. **Data Persistence**: A Docker volume (`desktop-home`) is automatically created and mounted to `/home/pi` to ensure your files and settings survive container restarts.

## 3. Usage Tips

- **Custom User**: You can configure the standard user by changing the `USER` environment variable in the `docker-compose.yml`. The default user is usually `ubuntu:ubuntu` or `user`.
- **Performance**: For a smoother experience, ensure you are on a fast local network, as VNC performance is heavily dependent on network latency and bandwidth.
