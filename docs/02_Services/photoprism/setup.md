# Photoprism Setup

> [!NOTE]
> #PhotoPrism #Photos #AI #Media #DockerCompose


## 1. Description

PhotoPrism is a self-hosted photo management app with AI labelling, search, and a web gallery over your existing image library on disk.

## 2. Installation

Deploy the Docker Compose stack using your preferred method (e.g., Portainer or CLI).

> [!WARNING]
> **Web UI Password**: If the password defined in the secrets file or environment variables does not work, it can be reset manually from within the container:
> 
> ```bash
> docker exec -it photoprism sh
> photoprism passwd [USER]
> ```
