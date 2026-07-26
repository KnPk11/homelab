# InfluxDB Setup

> [!NOTE]
> **Tags:** #InfluxDB #Metrics #Data #Docker

## 1. Installation

Deploy the InfluxDB stack using Portainer or Docker Compose. This service is primarily utilised to gather metrics from Glances.

## 2. Configuration

Navigate to the Web UI to finalise the configuration.

### 2.1 Buckets

The `glances` bucket should be created automatically during initialisation. You may optionally configure a retention policy for this bucket.

### 2.2 Account Credentials

> [!IMPORTANT]
> InfluxDB v2 requires the CLI to change user passwords.

To change a user's password, execute the following command:

   ```bash
   influx user password \
     --name [USER] \
     --password [SECRET]
   ```

## 3. Useful Commands

To check the storage usage of the InfluxDB container:

   ```bash
   docker exec -it influxdb du -sh /var/lib/influxdb2
   ```
