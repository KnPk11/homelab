# Privatebin Setup

> [!NOTE]
> **Tags:** #Privatebin #Security #TextSharing #Encrypted #DockerCompose

## 1. Configuration

1. Create a custom configuration file:
   
   ```bash
   sudo nano /srv/privatebin/conf.php
   ```

2. Add the following content, adjusting for your environment:
   
   ```cfg
   [main]
   basepath = "https://privatebin.homelab.local/"
   ; header = "X_FORWARDED_FOR"
   fileupload = true
   sizelimit = 20971520 ; 20 MB
   default = "1day"
   forcehttps = true

   [model]
   ; where to store pastes
   class = Filesystem

   [model_options]
   dir = PATH "data"

   [traffic]
   limit = 5
   ; IPs or subnets that are not subject to the rate limit
   exempted = "[SERVICE-NET], [MANAGEMENT-NET]"

   ; IPs or subnets that are allowed to create
   creators = "[SERVICE-NET], [MANAGEMENT-NET]"
   ```

## 2. Installation

1. Add the Docker Compose stack to Portainer and start it.
2. Set the correct access rights:
   
   ```bash
   sudo chown -R 1000:1000 /srv/privatebin/data
   sudo chmod 700 /srv/privatebin/data
   sudo chmod 644 /srv/privatebin/conf.php
   sudo chmod 644 /srv/privatebin/nginx.conf
   ```

## 3. Nginx Proxy Configuration

1. Edit the Nginx configuration file inside the container:
   
   ```bash
   docker exec -it privatebin sh
   nano /etc/nginx/nginx.conf
   ```

2. Add these lines inside the `http {...}` block to trust the reverse proxy and forward the real IP:
   
   ```conf
   # Trust your reverse proxy's Docker network
   set_real_ip_from [DOCKER-NET];
   set_real_ip_from [PROXY-IP];
   set_real_ip_from 172.17.0.1;
   ```

3. Update the `log_format` line to use `$remote_addr` for the client's real IP:
   
   ```conf
   log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                   '$status $body_bytes_sent "$http_referer" '
                   '"$http_user_agent"';
   ```

> [!WARNING]
> Ensure this configuration is bind-mounted, as setting the container's flag to `read_only` will restore its original state.

## 4. Shared Access

Privatebin does not offer its own authentication system. Two methods exist for allowing specific people to create pastes while maintaining public read access:

1. Add allowed IPs into the Privatebin configuration.
2. Place `POST` requests behind Caddy's basic authentication.

> [!INFO]
> **POST Auth Example**:
> 
> ```caddyfile
> privatebin.example.com {
>     # --- WRITE actions (create / delete / comment) ---
>     @write {
>         method POST
>     }
> 
>     basicauth @write {
>         [USER1] [SECRET]
>         [USER2] [SECRET]
>     }
> 
>     # --- Everything else (READ) is public ---
>     reverse_proxy privatebin:8080
> }
> ```

## 5. Security and Best Practices

- Run via a reverse proxy over HTTPS.
- Use a unique subdirectory or virtual host (avoid `/bin/`).
- Restrict file uploads if they are not required.
- Utilise a `robots.txt` file to prevent indexing.
- Avoid running the image as user 82 if it causes application instability.
