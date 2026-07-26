# Immich Setup

> [!NOTE]
> **Tags:** #Immich #Photos #Backup #AI #Media #Docker

## 1. Hardware Acceleration

Immich supports hardware acceleration for both transcoding and machine learning tasks. 

### 1.1 Transcoding

To utilise hardware acceleration for transcoding, extend the `immich-server` service with the appropriate profile (e.g., `nvenc`, `quicksync`, `vaapi`) in your `docker-compose.yml`:

   ```yaml
   immich-server:
     extends:
       file: hwaccel.transcoding.yml
       service: cpu # Change 'cpu' to one of [nvenc, quicksync, rkmpp, vaapi, vaapi-wsl]
     volumes:
       - ${UPLOAD_LOCATION}:/data
   ```

### 1.2 Machine Learning

For accelerated inference, use the appropriate image tag and extend the `immich-machine-learning` service:

   ```yaml
   immich-machine-learning:
     # Example tag for NVIDIA GPUs: ${IMMICH_VERSION:-release}-cuda
     extends:
       file: hwaccel.ml.yml
       service: cpu # Change 'cpu' to one of [armnn, cuda, rocm, openvino, openvino-wsl, rknn]
     env_file:
       - .env
   ```

## 2. Storage Configuration

Configure the storage locations in your `.env` file rather than modifying the `docker-compose.yml` directly.

### 2.1 Media Storage

The media storage location is defined by the `UPLOAD_LOCATION` variable.

### 2.2 Database Storage

The database storage location is defined by the `DB_DATA_LOCATION` variable. 

   ```yaml
   immich_db:
     environment:
       - DB_STORAGE_TYPE=HDD # Uncomment if the database is stored on HDDs instead of SSDs
     volumes:
       - ${DB_DATA_LOCATION}:/var/lib/postgresql/data
   ```
