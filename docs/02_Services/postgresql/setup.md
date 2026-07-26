# PostgreSQL Setup

> [!NOTE]
> **Tags:** #PostgreSQL #Database #Sql #DataIngestion #Etl #DockerCompose

## 1. Installation

1. Install the Docker Compose stack in Portainer and start it.
2. Leave the `data_loader` image running for some time; it does not start downloading immediately.

## 2. Verification

1. Access the database container:
   
   ```bash
   docker exec -it postgresql_db bash
   ```

2. Confirm successful ingestion directly from the container:
   
   ```bash
   psql -U [USER] -d [DATABASE]
   ```

3. Run the following SQL queries to verify data:
   
   ```sql
   SELECT COUNT(*) FROM yellow_taxi_trips;
   SELECT * FROM yellow_taxi_trips LIMIT 5;
   ```
