# Vaultwarden Setup

> [!NOTE]
> **Tags:** #Vaultwarden #Passwords #Security #Bitwarden #Docker

## 1. Description

**Vaultwarden** is a lightweight, open-source password manager written in Rust that is fully compatible with official Bitwarden clients, designed to be self-hosted on your own hardware or server.

## 2. Directory Preparation

Create the necessary directories for data persistence:

```bash
sudo mkdir -p /srv/vaultwarden
```

## 3. Permissions

Set appropriate access rights for the data directory:

```bash
sudo chown [USER]:[USER] /srv/vaultwarden/
sudo chmod 700 /srv/vaultwarden
```

## 4. Reverse Proxy Configuration

Add a reverse proxy rule for Caddy to manage external access.

## 5. Admin Token Security

Hash the admin access token for enhanced security:

```bash
docker exec -it vaultwarden /vaultwarden hash
```

## 6. Initial Configuration

Modify the following options in the `docker-compose.yml` for the initial setup:

```yaml
      - SIGNUPS_ALLOWED=true # default false
      - SIGNUPS_VERIFY=false # default true
```

## 7. Account Management

To change the account email, navigate to `vaultwarden.homelab.local/admin` and utilise the vault password as the admin token.

> [!IMPORTANT]
> **Security Measures**
> 
> Ensure appropriate security measures are set in the `environments` Docker directive. Set rate limits, block access to the `/admin` page in Caddy, and optionally configure 2FA.

> [!NOTE]
> **SMTP Settings**
> 
> SMTP settings are not essential and can be configured afterwards if required.

> [!TIP]
> **Backups**
> 
> Ensure the bound directory is backed up occasionally, or export the vault as a password-protected file.
> 
> A useful method to test backups is to spin up a temporary Vaultwarden image and point it at the backup directory.
