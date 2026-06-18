# Legacy Linux Setup

> [!NOTE]
> **Tags:** #Linux #Setup #Xscreensaver #Display #Infrastructure

## 1. Description

An archive of deprecated Linux system setup procedures and utilities previously utilised in the homelab, mostly from the early days when it was run on a Raspberry Pi running Debian Desktop OS.

## 2. Xscreensaver

Xscreensaver is used to properly blank the screen, ensuring it remains off even after remote connections.

### 2.1. Installation

```bash
sudo apt update
sudo apt install xscreensaver
```

### 2.2. Configuration

In the advanced settings, set the **Stand By**, **Suspend**, and **Screen Off** values to approximately 20, 25, and 30 minutes respectively.

> [!NOTE]
> **RDP Compatibility**: There is a known issue where users are unable to log in via RDP when Xscreensaver is active.
