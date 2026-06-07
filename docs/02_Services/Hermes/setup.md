# Hermes Dashboard

> [!NOTE]
> **Tags:** #Hermes #AI #Dashboard #Proxmox #HomeLab

Hermes is an AI agent dashboard and management system utilised for orchestrating LLM workflows, managing API keys, and interacting with various AI providers.

---

## Installation

### Deployment Environment

- **Host**: Proxmox VE
- **Platform**: Bare-metal Ubuntu VM (OpenClaw VM - `.91`)
- **Method**: Official Hermes installation script

### Initial Setup

The service was installed utilising the standard installation procedure for Linux environments.

```bash
# Executed on the OpenClaw VM
curl -sSL https://hermes.nousresearch.com/install.sh | bash
```

---

## Configuration

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

---

## Dashboard Access & Security

> [!TIP]
> **Authentication**: Hermes uses native `scrypt` authentication to ensure compatibility with password manager auto-fill.

### Access Details

- **URL**: `https://hermes.[DOMAIN]`
- **Username**: `[USER]`
- **Auth Method**: Native Hermes Login (scrypt-hashed)
- **Session Security**: A stable 32-byte secret is utilised for session signing.

### Caddy Configuration

Caddy handles TLS termination and restricts access to the LAN. Authentication is delegated to Hermes.

```caddy
hermes.[DOMAIN] {
    import common-headers
    import common-robots
    import access_policy_lan
    import common-logging-plaintext hermes
    import common-logging hermes

    reverse_proxy [CADDY-IP]:9119 {
        header_up Host [CADDY-IP]:9119
    }
}
```

### Native Authentication Setup

Authentication is configured via environment variables in `~/.hermes/.env` to separate secrets from the main configuration file.

```bash
HERMES_DASHBOARD_BASIC_AUTH_USERNAME=[USER]
HERMES_DASHBOARD_BASIC_AUTH_PASSWORD_HASH=scrypt$16384$8$1$...
HERMES_DASHBOARD_BASIC_AUTH_SECRET=[SECRET]
```

> [!IMPORTANT]
> **Hash Generation**
> 
> The password hash must be generated utilising the internal Hermes utility to ensure the correct `scrypt` format:
> `python -c "from plugins.dashboard_auth.basic import hash_password; print(hash_password('YOUR_PASSWORD'))"`

---

## Verification

To verify the service is running and accessible:

```bash
# Check service status on the VM
systemctl --user status hermes-dashboard.service

# Test internal connectivity
curl -I http://[OPENCLAW-IP]:9119
```
