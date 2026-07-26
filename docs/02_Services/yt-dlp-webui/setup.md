# yt-dlp Web UI Setup

> [!NOTE]
> **Tags:** #YtDlp #VideoDownloader #Youtube #Media

## 1. Description

A web-based user interface for `yt-dlp` to manage video downloads through a browser.

## 2. Installation

The image does not seem to be persistent out of the box. To make subscriptions work between restarts, copy the config out of the image:

```bash
docker cp yt-dlp-webui:/config /srv/yt-dlp-webui
```

Ensure this config is bind-mounted in the Docker Compose for persistent storage.
