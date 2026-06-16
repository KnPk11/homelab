# yt-dlp Setup

> [!NOTE]
> **Tags:** #YtDlp #VideoDownloader #Youtube #Media

## 1. Description

A command-line program to download videos from YouTube.com and other video sites.

## 2. Prerequisites

Install `ffmpeg` and other necessary dependencies:

```bash
sudo apt update && sudo apt install -y ffmpeg python3-pip
```

## 3. Installation

1. **Download yt-dlp**: Ensure `curl` is installed and download the latest release of `yt-dlp`:
   
   ```bash
   sudo apt install curl -y
   sudo curl -L https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp -o /usr/local/bin/yt-dlp
   ```

2. **Set Permissions**: Make the downloaded package executable:
   
   ```bash
   sudo chmod a+rx /usr/local/bin/yt-dlp
   ```

## 4. Automation

If required, you can schedule custom scripts utilising `yt-dlp` using `cron`:

```cfg
*10 */3 * * * /data/other/yt-dlp/download_all.sh >> /home/[USER]/crontab/logs/yt_dlp.log 2>&1
```
