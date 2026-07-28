# Heimdall Setup

> [!NOTE]
> #Heimdall #Dashboard #Portal #DockerCompose

## 1. Description

An application dashboard and portal designed to provide a unified interface for all your self-hosted services.

## 2. Installation

1. **Reverse Proxy**: Add Heimdall to Caddy at the base domain level.
2. **Admin password**: Set one if the dashboard can reach sensitive links.
3. **Public profile** (optional): Create a password-free public profile for unauthenticated visitors, or run a separate read-only landing instance.

> [!NOTE]
> Heimdall is basic and may not support multi-user environments effectively. There are known compatibility issues with Vaultwarden when using mobile Firefox.

## 3. Security

- Prefer a **read-only** container mount if the front page is public — otherwise unauthenticated users may change widgets.
- Widget credentials are stored in **plaintext**; treat Heimdall as low-trust for secrets.
- Login failures may return **HTTP 200**, so do not rely on status codes alone for auth monitoring.
