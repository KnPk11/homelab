# Dashy Setup

> [!NOTE]
> **Tags:** #dashy #dashboard #monitoring #docker_compose

## 1. Installation

1. Create a config file for managing widgets and other things

   ```bash
   sudo nano /srv/dashy/config.yml
   ```

   ```bash
   sudo chmod 644 /srv/dashy/config.yml
   ```

2. Create a secure password and hash it

   ```bash
   read -s -p "Enter password: " pass; echo -n "$pass" | sha256sum
   ```

   > [!NOTE]
   > It's safe to expose the hash in the config file. However plaintext passwords would be best moved to another file, but that seems impossible to do.

3. Add the stack in Portainer
4. Add an entry to Caddyfile

## 2. Configuration

> [!NOTE]
> **Password-protected setup**
> 
> Not really needed and exposes the password to the web through Dashy's config - best to make LAN-only.
> 
> ```yml
>     widgets:
>       - type: gl-current-cpu
>         options:
>           label: CPU Usage
>           hostname: https://glances.example.com
>           username: glances
>           password: [SECRET]
>           ignoreErrors: false
>           refreshRate: 2000
>         useProxy: true
> ```

## 3. Security

> [!NOTE]
> **Secret Management**
> 
> Consider moving the hash into `/data/secrets`? Not sure the config supports that. More concerning is the plaintext password for Glances widgets.
