# Piped Setup

> [!NOTE]
> **Tags:** #Piped #Media #Youtube #VideoDownloader #DockerCompose

## 1. Description

A privacy-friendly, alternative frontend for YouTube which is efficient by design.

## 2. Setup

### Official Installation Method

Alternatively, follow the [official self-hosting guide](https://docs.piped.video/docs/self-hosting/):

1. **Clone Repository**:
   
   ```bash
   sudo git clone https://github.com/TeamPiped/Piped-Docker
   sudo chown -R [USER]:[USER] Piped-Docker/
   cd Piped-Docker
   ```

2. **Configure Instance**:
   
   ```bash
   ./configure-instance.sh
   ```

### Docker Compose Troubleshooting

If the backend reports a `java.sql.SQLException: The url cannot be null` error, ensure all database connection strings are correctly defined in the environment variables.