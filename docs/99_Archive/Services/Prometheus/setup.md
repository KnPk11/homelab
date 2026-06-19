# Prometheus Setup

> [!NOTE]
> **Tags:** #Prometheus #Monitoring #Database #Infrastructure

## 1. Description

A self-hosted monitoring system and time series database used for collecting and querying metrics from various services.

## 2. Configuration

1. Create the necessary directories:
   
   ```bash
   mkdir -p /srv/prometheus
   ```

2. Create and configure the `prometheus.yml` file:
   
   ```bash
   nano /srv/prometheus/prometheus.yml
   ```

3. Add the following configuration, adjusting targets as required:
   
   ```yaml
   global:
     scrape_interval: 15s # How often to grab data. 15s is standard.

   scrape_configs:
     - job_name: 'prometheus'
       static_configs:
         - targets: ['prometheus:9090']

     - job_name: 'glances'
       metrics_path: '/metrics' # Glances puts the data here
       static_configs:
         - targets: ['glances:61208']
   ```
