# Hermes Dashboard

> [!NOTE]
> #Hermes #AI #Dashboard #Proxmox #HomeLab

## 1. Description

Hermes is an AI agent dashboard and management system utilised for orchestrating LLM workflows, managing API keys, and interacting with various AI providers.

## 2. Installation

### Deployment Environment

- **Host**: Proxmox VE
- **Platform**: Debian 13 VM (`lab-vm` - `192.168.50.91`, VM 103)
- **Method**: Official Hermes installation script
- **GitOps Runbook**: [Hermes Host Deployment Guide](../../../nodes/lab-vm/services/hermes/deployment.md)

### Initial Setup

The service was installed utilising the standard installation procedure for Linux environments.

```bash
# Executed on lab-vm under user k
curl -sSL https://hermes.nousresearch.com/install.sh | bash
```

## 3. Configuration

### AI Providers & Models

Hermes is configured to utilise multiple high-performance providers:

- **NVIDIA Build**: Integrated to leverage specialised model endpoints.
- **OpenAI**: Configured with API keys for access to GPT-4o and other models.
- **Grok (xAI)**: Authenticated via OAuth (requires **SuperGrok Subscription**). This enables high-performance access to **Grok 4.3** with native Vision and Text-to-Speech (TTS) capabilities.
- **Dynamic Model Fetching**: The system is configured to dynamically fetch and update the model list from the providers to ensure access to the latest versions.

### Setup Commands

After installation, the following commands were utilised to configure the providers:

```bash
# Select and authenticate Grok OAuth
hermes model
# Then select 'xAI Grok OAuth (SuperGrok Subscription)'
```

### API Key Management

API keys are stored securely within the `~/.hermes/.env` file and managed via the dashboard interface.

### Dashboard URL

- **URL**: `https://hermes.[DOMAIN]`
- **Auth**: native Hermes login (see [security.md](security.md) for hashing, Caddy, and perimeter layers)

## 4. Verification

To verify the service is running and accessible:

```bash
# Check service status on lab-vm
systemctl --user status hermes-gateway.service hermes-dashboard.service

# Test internal dashboard connectivity
curl -I http://127.0.0.1:9119
```
