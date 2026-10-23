# OpenCode Setup

> [!NOTE]
> #OpenCode #AI #AgenticAi #CLI #Llm #LXC

## 1. Description

OpenCode (`opencode`) is an open-source terminal AI agent deployed on the `ai-tools` node, supporting both cloud model providers and self-hosted OpenAI-compatible local LLM endpoints.

## 2. Infrastructure Setup

Please refer to the [Proxmox LXC Spec](../proxmox-lxc.md) for the specific resource allocation and provisioning details for this node, and [AI Node Security](../security.md) for SSH key management.

## 3. Installation

1. **Install OpenCode**:
   
   ```bash
   curl -fsSL https://opencode.ai/install | bash
   ```

2. **Initial Configuration**:
   
   Navigate to your project directory and run `/connect` to configure a provider.

## 4. Local LLM Providers

Custom OpenAI-compatible endpoints (e.g., [Open WebUI](../../02_Services/open-webui/setup.md)) require explicit mapping in the configuration.

1. **Provider Configuration**: Update `~/.config/opencode/opencode.json`:
   
   ```json
   {
     "provider": {
       "homelab-ai": {
         "npm": "@ai-sdk/openai-compatible",
         "name": "Homelab AI",
         "options": {
           "baseURL": "https://[AI-URL]/api/v1"
         },
         "models": {
           "google/gemma-2-9b": {
             "name": "Gemma 2 9B"
           }
         }
       }
     }
   }
   ```

2. **Authentication**: Store the API key in `~/.local/share/opencode/auth.json`:
   
   ```json
   {
     "homelab-ai": {
       "type": "api",
       "key": "[SECRET]"
     }
   }
   ```
