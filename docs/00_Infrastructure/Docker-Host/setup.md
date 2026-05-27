# Docker Setup & Configuration

> [!NOTE]
> **Tags:** #Docker #Infrastructure #Linux #RaspberryPi

## Installation

```bash
# Download Docker
curl -sSL https://get.docker.com | sh

# Add your user to the Docker group (requires a logout/login)
sudo usermod -aG docker $USER
newgrp docker
```

### Docker Compose
```bash
sudo apt update
sudo apt install docker-compose-plugin
```

**Verify Installation:**
```bash
docker compose version
```

---

## Raspberry Pi Specifics

> [!WARNING]
> **Cgroups on Raspberry Pi OS**
> 
> Raspberry Pi OS historically ships with cgroups memory controller disabled by default. 
> 
> To enable deployment resource management edit `/boot/firmware/cmdline.txt` and add this to the end of the file:
> 
> ```bash
> cgroup_enable=memory swapaccount=1 cgroup_memory=1 cgroup_enable=cpuset
> ```
> 
> Reboot the system:
> 
> ```bash
> sudo reboot now
> ```
> 
> Running `docker info` shouldn't show messages such as:
> ```
> WARNING: No memory limit support
> WARNING: No swap limit support
> WARNING: No kernel memory limit support
> WARNING: No oom kill disable support
> WARNING: No cpu cfs quota support
> WARNING: No cpu cfs period support
> ```
> 
> And running these commands on individual docker services should also confirm the limits:
> 
> ```bash
> docker stats photoprism
> docker inspect photoprism | grep -i "memory"
> ```
> 
> Note that the changes might not apply unless each service is re-deployed with some changes in docker-compose.

---

## Management Tools

### Portainer
Refer to the **Portainer** section in the self-hosted directory.
