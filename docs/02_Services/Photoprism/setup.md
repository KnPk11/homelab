# Photoprism Setup

> [!NOTE]
> **Tags:** #Photoprism #Photos #Ai #Media #DockerCompose

## 1. Installation

Deploy the Docker Compose stack using your preferred method (e.g., Portainer or CLI).

> [!WARNING]
> **Web UI Password**: If the password defined in the secrets file or environment variables does not work, it can be reset manually from within the container:
> 
> ```bash
> docker exec -it photoprism sh
> photoprism passwd [USER]
> ```

