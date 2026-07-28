# Dozzle Setup

> [!NOTE]
> #Dozzle #Logging #Docker


## 1. Description

Dozzle is a real-time web UI for Docker container logs — follow multiple containers in the browser without `docker logs` on the host.

## 2. Password Generation
Add the Dozzle stack to your container management tool (e.g., Portainer). To enable authentication, you first need to generate a `bcrypt` password hash:

```bash
docker run -it --rm amir20/dozzle generate --name [USER] --email [USER]@example.com --password [PASSWORD]
```

## 3. Configuration
Create the configuration directory and file on your host:

```bash
mkdir -p /srv/dozzle
```

Create a `data/users.yml` file with the following structure, using the hash generated in the previous step:

```yml
users:
  [USER]:
    email: [USER]@example.com
    name: [USER]
    password: "[PASSWORD-HASH]"
    filter: ""
    roles: ""
```

## 4. Deployment
Ensure that authentication is enabled and the configuration is mapped in your Docker Compose file:

```yaml
services:
  dozzle:
    # ... other config
    environment:
      - DOZZLE_AUTH_PROVIDER=simple
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - /srv/dozzle:/data
```
