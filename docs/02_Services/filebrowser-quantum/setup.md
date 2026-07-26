# File Browser Quantum Setup

> [!NOTE]
> **Tags:** #FileBrowser #FileManager #Media #Docker

---

## 1. Directory Structure
Create the required directories:

   ```bash
   mkdir -p /srv/filebrowser-quantum/db_data
   mkdir -p /tmp/filebrowser_tmp
   cd /srv/filebrowser-quantum
   ```

Create the initial database file:

   ```bash
   touch /srv/filebrowser-quantum/db_data/database.db
   ```

Set the appropriate permissions:

   ```bash
   sudo chown -R [USER-ID]:[GROUP-ID] /srv/filebrowser-quantum
   sudo chown -R [USER-ID]:[GROUP-ID] /tmp/filebrowser_tmp
   ```

---

## 2. Configuration
Create a `config.yaml` file and populate it with the following configuration:

   ```yaml
   server:
     port: 8080
     baseURL: "/"
   
     database: /home/filebrowser/db_data/database.db
     
     cacheDir: /home/filebrowser/tmp
   
     sources:
       - path: /home/filebrowser/public
         name: "Shared Files"
         config:
           defaultEnabled: false
   
       - path: /home/filebrowser/private
         name: "My Private Data"
         config:
           defaultEnabled: false
   
     logging:
       - output: stdout
         levels: "info|warning|error|debug"
   ```

---

## 3. Installation
Deploy the stack using Portainer or Docker Compose.

> [!WARNING]
> Setting the admin password via environment variables (e.g., `FILEBROWSER_ADMIN_PASSWORD`) may not work as expected. The default credentials might still be applied.

Log in via the Web UI using the default credentials and change them immediately:
- **Username:** `admin`
- **Password:** `admin`

---

## 4. Security

> [!IMPORTANT]
> Change the default admin password immediately after the first login.

- Deny new user sign-up in the settings.
- Restrict access by only mounting the specific directories required by the service, rather than providing access to the entire disk.
