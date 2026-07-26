> [!NOTE]
> **Tags:** #Windows #Docker #Infrastructure #Setup

# Windows Docker Setup Guide

This guide covers the installation and configuration of Docker and Portainer on Windows using WSL2.

---

## Docker Installation

### Steps
1. **Install WSL**: Ensure Windows Subsystem for Linux is installed and updated.
2. **Install Docker Desktop**: Download and run the Docker Desktop installer.
3. **Enable WSL2 Mode**:
   - Open Docker Desktop settings.
   - Navigate to **General** → **Use the WSL 2 based engine**.

---

## Portainer Configuration

> [!TIP]
> Use Portainer to manage local and remote Docker environments through a simplified graphical interface.

### 1. Create Data Volume
Create a persistent volume to store Portainer's configuration and data.
```powershell
docker volume create portainer_data
```

### 2. Deploy Portainer Container
Run the following command to start the Portainer Community Edition container.
```powershell
docker run -d -p 8000:8000 -p 9443:9443 --name portainer --restart always -v \\.\pipe\docker_engine:\\.\pipe\docker_engine -v portainer_data:C:\data portainer/portainer-ce:lts
```

### 3. Access the Dashboard
Once the container is running, access the Portainer web interface at:
`https://localhost:9443`

