# Portainer Setup

> [!NOTE]
> **Tags:** #Portainer #Docker #ContainerManagement #Infrastructure #DockerCompose

## 1. Installation

### 1.1. Preparation

1. Navigate to the deployment directory:

```bash
cd /data/other/portainer/
```

2. Create the Docker Compose file:

```bash
nano docker-compose.yml
```

3. Create the Portainer volume for persistent data:

```bash
docker volume create portainer_data
```

### 1.2. Deployment

1. Start the Portainer container:

```bash
docker compose up -d
```

2. Access the web interface at `[HOST-IP]:9443`.

## 2. Security and Connectivity

### 2.1. Stack Management

It is recommended to split stacks into individual Docker Compose files to isolate services for modularity and reduce the potential blast radius of configuration errors.

### 2.2. Remote Host Management

If Portainer is managing only the local Docker engine, enabling SSH is unnecessary. SSH or the Portainer Agent is only required when:
- Managing multiple Docker nodes.
- Connecting Portainer to **remote Docker hosts**.

> [!IMPORTANT] Certificates
> Avoid importing certificates unless you are explicitly connecting to a remote host.

### 2.3. Connection Modes

Portainer supports two primary methods for managing remote environments:
- **Agent Mode**: Utilizing the Portainer Agent container on the remote host (recommended for performance and feature support).
- **Standalone Docker host via SSH**: Connecting directly to the Docker engine over an SSH tunnel.
