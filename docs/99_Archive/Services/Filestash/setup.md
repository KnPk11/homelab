# Filestash Setup

> [!NOTE]
> **Tags:** #Filestash #Files #Media #DockerCompose

## 1. Description

A web-based file manager that allows you to connect to multiple backends, such as SFTP, S3, FTP, WebDAV, and more, providing a unified interface for your data.

## 2. Installation

1. **Directory Preparation**: Create the necessary configuration directories:
   
   ```bash
   sudo mkdir -p /home/services/filestash/config
   ```

2. **Permissions**: Set the correct ownership for the configuration directory:
   
   ```bash
   sudo chown -R 1000:1000 /home/services/filestash/config
   ```

3. **Deployment**: Start the stack in Portainer.
