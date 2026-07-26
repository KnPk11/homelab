# File Browser Setup

> [!NOTE]
> **Tags:** #FileBrowser #FileManager #Media #DockerCompose

## 1. Description

A self-hosted web file manager that allows you to manage your files via a clean and simple interface, supporting multiple users and fine-grained permissions.

## 2. Installation

1. **Prepare Directories**: Create the necessary directories and set ownership:
   
   ```bash
   sudo mkdir -p /home/filebrowser/config
   sudo chown -R $(id -u):$(id -g) /home/filebrowser
   ```

2. **Initialise Database**: Create the required database file:
   
   ```bash
   touch /home/filebrowser/database.db
   ```

3. **Configuration**: Create a new configuration file:
   
   ```bash
   cat > /home/filebrowser/.filebrowser.json <<EOF
   {
     "port": 80,
     "baseURL": "/",
     "address": "",
     "log": "stdout",
     "database": "/database.db",
     "root": "/srv"
   }
   EOF
   ```

4. **Default Credentials**: Use the default credentials to log in for the first time:
   - **Username**: `admin`
   - **Password**: `admin`
