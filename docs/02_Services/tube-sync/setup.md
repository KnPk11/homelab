# TubeSync Setup

> [!NOTE]
> **Tags:** #TubeSync #Media #Youtube #VideoDownloader #DockerCompose

## 1. Description

A PVR for YouTube, allowing you to synchronise YouTube channels and playlists to local media storage.

## 2. Installation

1. Add the Docker Compose stack to Portainer and start it.

## 3. Configuration

### Docker Compose Example (Unused)

> [!NOTE]
> The following environment variables can be utilised for authentication and path prefixing:
> 
> ```yaml
> environment:
>   - HTTP_USER=[USER]
>   - HTTP_PASS=[SECRET]
>   - DJANGO_URL_PREFIX=/tubesync/
> ```
