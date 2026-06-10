# Glances Setup

> [!NOTE]
> **Tags:** #glances #system_stats #monitoring #docker_compose

---

## 1. Configuration

If Dashy widgets refresh too slowly you can disable processes list in `glances.conf`:

```conf
[processlist]
disable=True

[processcount]
disable=True
```

---

## 2. Security

Consider setting up a [password](https://glances.readthedocs.io/en/latest/docker.html):

```yml
environment:
  - GLANCES_OPT="-w --password"
```

Make sure the `glances.pwd` secret has correct permissions for it to work.

However this means Dashy will need to store plaintext password in its config in order to connect to Glances. Another option is to:
- Apply a LAN-only directive via Caddy
- Optionally set up basic auth

> [!NOTE]
> **Port-forwarded setup**
> 
> ```yml
>   glances:
>     ports:
>       - "127.0.0.1:61208:61208"
>       - "[HOST-IP]:61208:61208"
> ```

> [!WARNING]
> **Access to host's system stats**
> 
> I think it makes the dashboard refresh slower.
> 
> ```yml
>     volumes:
>       - /etc/os-release:/etc/os-release:ro
> ```

---

## 3. InfluxDB Integration

> [!WARNING]
> **Glances image type**
> 
> Make sure to use the `nicolargo/glances:latest-full` image.

Change Glances from GUI server mode to export mode by replacing `-w` with:

```yml
- GLANCES_OPT=--export influxdb2
```

Add this in to prevent docker restarts from breaking stats and creating a new hostname in Grafana:

```yml
hostname: HomeLab
```

Then go to `API Tokens` and create a custom one with access to the `glances` bucket.
Add these into the Glances config in `/srv/glances/glances.conf`:

```yml
[influxdb2]
host=influxdb
port=8086
org=homelab
bucket=glances
token=[SECRET]
protocol = http
```

> [!WARNING]
> **Restart Sync**
> 
> Restarting Glances doesn't always make InfluxDB pick up the token, so try restarting both containers. You can check that data is flowing through by selecting the container and running this:
> 
> ```sql
> from(bucket: "glances")
>   |> range(start: -5m)
>   |> last()
> ```
