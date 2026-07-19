# Dashy Setup

> [!NOTE]
> **Tags:** #dashy #dashboard #monitoring #docker_compose

## 1. Installation

### Option A: Docker (Portainer)

1. Create a secure password and hash it:
   ```bash
   read -s -p "Enter password: " pass; echo -n "$pass" | sha256sum
   ```
2. Create a config file (`/srv/dashy/config.yml`) and insert your configuration and hash.
3. Deploy the `lissy93/dashy:latest` image via Portainer stack, mounting your config file to `/app/user-data/conf.yml`.
4. Add a `reverse_proxy` entry to your Caddyfile pointing to the container's port.

### Option B: Static Build (Bare Metal / LXC)

For resource-constrained nodes, Dashy can be compiled into a static site and served directly by a web server like Caddy. This eliminates the need for Node.js at runtime.

1. **Build the application** (on a node with Node.js installed):
   ```bash
   git clone --depth 1 https://github.com/lissy93/dashy.git
   cd dashy
   npm install
   npm run build
   ```
2. **Transfer the files** to your target node (e.g., into `/srv/dashy/dist/`).
3. **Template the configuration:** Create a `config.yml.tmpl` replacing secrets with variables (e.g., `${DASHY_AUTH_HASH}`), and inject real values from a `.env` file using `envsubst`:
   ```bash
   envsubst < config.yml.tmpl > /srv/dashy/dist/conf.yml
   ```
4. **Configure Caddy:** Add a block in your Caddyfile to serve the static directory:
   ```caddy
   home.example.com {
       root * /srv/dashy/dist
       try_files {path} /index.html
       file_server
   }
   ```

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
