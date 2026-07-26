# Heimdall Setup

> [!NOTE]
> **Tags:** #Heimdall #Dashboard #Portal #DockerCompose

## 1. Description

An application dashboard and portal designed to provide a unified interface for all your self-hosted services.

## 2. Installation

1. **Reverse Proxy**: Add Heimdall to Caddy at the base domain level.
2. **Security**: Set an administrator password, especially if sharing links to sensitive self-hosted services.
3. **Public Access**: Optionally create a public profile without a password to provide a landing page for unauthenticated visitors.

> [!NOTE]
> Heimdall is basic and may not support multi-user environments effectively. There are known compatibility issues with Vaultwarden when using mobile Firefox.
