# n8n Setup

> [!NOTE]
> **Tags:** #N8n #Automation #Workflow #SelfHosted

## 1. Directory Preparation

Create the necessary directories for n8n data:
```bash
mkdir -p /srv/n8n/data
```

## 2. Permissions

Set the correct ownership and permissions for the data directory:
```bash
chown -R 1000:1000 /srv/n8n/data
chmod 700 /srv/n8n/data
```

## 3. Encryption Key Generation

Generate a random 32-character encryption key to secure the installation:
```bash
openssl rand -base64 32
```

## 4. Deployment

Deploy the Docker Compose stack using the preferred method (e.g., Portainer or CLI). Ensure that the generated secret key is placed in `/srv/n8n/data/config`.

