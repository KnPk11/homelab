# Grafana Setup

> [!NOTE]
> **Tags:** #Grafana #Dashboards #Monitoring #Docker #Loki

---

## 1. Summary
This service is utilised for system monitoring (Glances) and MikroTik syslog analysis. Data is split between InfluxDB (metrics) and Loki (logs).

---

## 2. Setup

### 2.1 Glances & InfluxDB
1. Add the Docker Compose stack to Portainer.
2. In the Grafana web UI, navigate to **Connections** > **Data Sources** and add **InfluxDB**.
   - **Query language:** Flux
   - **URL:** `http://influxdb:8086`
   - **Organisation:** [ORG]
   - **Token:** [SECRET]
   - **Default bucket:** `glances`
3. Import Dashboard ID: `2387`.

> [!TIP]
> If no metrics display, edit the dashboard, navigate to **Variables** > **New variable**. This variable can be hidden from the dashboard view.
> - **Variable type:** Custom
> - **Name:** `DS_QUERY`
> - **Custom options:** `influxdb`

---

### 2.2 Loki
1. Ensure Loki is listening on the LAN interface to receive logs from the reverse proxy.
2. In Portainer, ensure the `ports` mapping is correctly configured:

   ```yaml
   ports:
     - "3100:3100"
   ```

3. In Grafana, navigate to **Connections** > **Data Sources** and add **Loki**.
   - **URL:** `http://loki:3100`
4. Import Dashboard ID: `12611`.

---

## 3. MikroTik Log Collection (Host-Specific)
Promtail must run on the reverse proxy host to ship logs back to the Loki instance.

### 3.1 Installation

   ```bash
   # Download and install binary
   curl -L https://github.com/grafana/loki/releases/download/v2.8.0/promtail-linux-amd64.zip -o promtail.zip
   apt-get update && apt-get install -y unzip
   unzip promtail.zip
   mv promtail-linux-amd64 /usr/local/bin/promtail
   rm promtail.zip

   # Create config directory
   mkdir -p /etc/promtail
   ```

### 3.2 Configuration
Create the configuration file at `/etc/promtail/config.yml`:

   ```yaml
   server:
     http_listen_port: 9080
     grpc_listen_port: 0

   positions:
     filename: /tmp/positions.yaml

   clients:
     - url: http://[HOST-IP]:3100/loki/api/v1/push

   scrape_configs:
   - job_name: mikrotik_logs
     static_configs:
     - targets:
         - localhost
       labels:
         job: mikrotik
         __path__: /mnt/logs/mikrotik/*.log
   ```

### 3.3 Systemd Service
Create the service file at `/etc/systemd/system/promtail.service`:

   ```ini
   [Unit]
   Description=Promtail service
   After=network.target

   [Service]
   Type=simple
   User=root
   ExecStart=/usr/local/bin/promtail -config.file=/etc/promtail/config.yml
   Restart=on-failure

   [Install]
   WantedBy=multi-user.target
   ```

### 3.4 Enable Service

   ```bash
   systemctl daemon-reload
   systemctl enable --now promtail
   ```
