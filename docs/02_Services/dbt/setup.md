# dbt

> [!NOTE]
> **Tags:** #dbt #data_modelling #analytics #docker_compose

## 1. Installation

1.  Add the stack in your container management tool (e.g., Portainer).

2.  When setting up for the first time ensure this command is present to verify the configuration:

    ```yml
    command: ["dbt", "debug"]
    ```

3.  Once verified, swap the command to the following to ensure the dbt container remains active in the background:

    ```yml
    command: ["tail", "-f", "/dev/null"]
    ```

    > [!NOTE]
    > **GCP Configuration**: If utilised with BigQuery, ensure you set up a service account with appropriate `edit` permissions in GCP. Set up billing alerts and disable the key once your work is complete.

4.  Run a sample model:

    ```bash
    docker exec -it dbt dbt run --select +fact_orders
    ```

## 2. Profiles

Ensure your `profiles.yml` is correctly configured in the service directory (`nodes/docker-services/services/dbt/profiles.yml`).

### BigQuery Example

```yaml
bigquery_profile:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: [GCP-PROJECT-ID]
      dataset: analytics
      threads: 2
      keyfile: /root/.dbt/gcp-creds.json
```

### Postgres Example

```yaml
postgres_profile:
  target: dev
  outputs:
    dev:
      type: postgres
      host: [DATABASE-HOST]
      user: [USER]
      password: [SECRET]
      port: 5432
      dbname: [DB-NAME]
      schema: public
      threads: 2
```
