# OpenCloud Setup

> [!NOTE]
> **Tags:** #OpenCloud #Cloud #Productivity #Files #Collaboration #DockerCompose

## 1. Description

A self-hosted personal cloud storage and collaboration platform, focusing on security and performance for file management.

## 2. Initial Setup

1. **Prepare Directories**: Create the necessary directories and set ownership:
   
   ```bash
   sudo mkdir -p /srv/opencloud/{config,data}
   sudo chown -R 1000:1000 /srv/opencloud/
   ```

2. **Deploy Container**: Add the Docker Compose stack into Portainer.
   
   > [!NOTE]
   > **First Run Initialisation**: On the first execution, use this entrypoint to initialise OpenCloud and generate the admin password:
   > 
   > ```yaml
   > services:
   >   opencloud:
   >     entrypoint: ["/bin/sh", "-c"]
   >     command: ["opencloud init || true; opencloud server"]
   > ```
   > 
   > Once initialisation is complete, remove the custom entrypoint and restart the container.

3. **Administration**: Start the container; an initial admin password will be created automatically.
4. **Configuration Persistence**: Copy the generated configuration to a persistent location:
   
   ```bash
   sudo cp /srv/opencloud/config/opencloud.yaml /srv/opencloud/opencloud.yaml
   ```

5. **Bind Mounts**: Ensure the configuration is bind-mounted so credentials persist across restarts.
6. **User Management**: Log in as `admin` and create additional users as required.

   > [!WARNING]
   > The `opencloud.yaml` file contains machine credentials. When you run `init`, it generates this file to ensure the system can restart with the same credentials. If you change the admin password in the app, the file will be updated automatically.

## 3. Usage Tips

- **Public Sharing**: Share files publicly without a password by opening the file and selecting **Remove password**.

## 4. Known Limitations

- **External Storage**: Currently not supported; any mounted folders must be re-imported manually after container restarts.
	- [Official page](https://docs.opencloud.eu/docs/admin/configuration/storage/storage-posix)
	- [Reddit discussion](https://www.reddit.com/r/opencloud/comments/1jml73b/external_folders/) 
	- [Feature request list](https://github.com/opencloud-eu/opencloud/issues/2004)
- **Features**: The app list and feature set are currently limited compared to mainstream alternatives.
- **Encryption**: No server-side encryption support is available.
