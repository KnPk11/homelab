# Airflow

> [!NOTE]
> **Tags:** #airflow #data_orchestration #analytics #docker_compose #python

## 1. Setup

Create the env file:

```bash
echo -e "AIRFLOW_UID=$(id -u)" > .env
```

Add GID to it:

```env
AIRFLOW_UID=1000
AIRFLOW_GID=0
```

Create the required directories:

```bash
mkdir -p /srv/airflow
cd /srv/airflow
mkdir -p ./dags ./logs ./plugins ./config
```

Set correct ownership for the directory:

```bash
sudo chown -R $(id -u):0 /srv/airflow
```

For the docker compose setup, either `airflow.cfg`, or environmental variables under `x-airflow-common:` can be used to specify variables.

> [!NOTE]
> **Volume Mounts**: Make sure `/dags` and `/logs` and other relevant directories are mounted on host for the DAG processor, API server, scheduler, worked, CLI containers:
> 
> ```yml
>     volumes:
>       - /srv/airflow/dags:/opt/airflow/dags
>       - /srv/airflow/logs:/opt/airflow/logs
>       - /mnt/external/Downloads/yt-dlp:/opt/airflow/downloads
> ```

Run the setup with these commented out to make sure the default user is not created - best to add one manually with a strong password.

```yml
_AIRFLOW_WWW_USER_USERNAME: ${_AIRFLOW_WWW_USER_USERNAME:-airflow}
_AIRFLOW_WWW_USER_PASSWORD: ${_AIRFLOW_WWW_USER_PASSWORD:-airflow}
```

Verify no users exist:

```bash
docker exec -it airflow_apiserver airflow users list
```

Create a new admin user with a strong password:

```bash
docker exec -it airflow_apiserver airflow users create \
    --username [USER] \
    --firstname [USER] \
    --lastname [USER] \
    --role Admin \
    --email [EMAIL]
```

## 2. Reverse Proxy Setup

Add this variable to the compose:

```yml
AIRFLOW__WEBSERVER__BASE_URL=http://example.com/airflow
AIRFLOW__WEBSERVER__ENABLE_PROXY_FIX: 'True'
```

## 3. Docker Operator Integration

Find the group Docker runs on:

```bash
getent group docker
```

Update Airflow's `.env` file to reflect the correct group:

```bash
AIRFLOW_GID=0
```

Change file permissions on host:

```bash
sudo chown -R 1000:991 /srv/airflow/dags /srv/airflow/logs /srv/airflow/plugins /srv/airflow/config
sudo chmod -R 775 /srv/airflow/dags /srv/airflow/logs /srv/airflow/config /srv/airflow/plugins
```

Add this to Airflow's docker compose below `users`:

```yml
  user: "${AIRFLOW_UID:-1000}:0"
  group_add:
    - "991"
```

Update and launch the stack.

> [!NOTE]
> **Docker operator**: Airflow has an operator specifically for Docker - the proper way to execute docker commands, such as execute dbt models through calling the separate dbt container.

> [!TIP]
> **Optional Services**: Additional services like **Flower** (for Celery monitoring) are available as separate compose fragments in the implementation directory: `nodes/homelab-95/services/airflow/docker-compose.flower.yml`.

## 4. Security

- Make sure to delete the default user and create a new one with a strong password.
- Airflow **does not** natively support restricting access by IP or subnet. That kind of network-level filtering needs to happen in your **reverse proxy** (Caddy) or firewall.
