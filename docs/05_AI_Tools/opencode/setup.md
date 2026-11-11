# OpenCode Setup

> [!NOTE]
> #OpenCode #AI #AgenticAi #CLI #Llm #LXC

## 1. Description

OpenCode (`opencode`) is an open-source terminal AI agent deployed on the `ai-tools` node, supporting both cloud model providers and self-hosted OpenAI-compatible local LLM endpoints.

## 2. Infrastructure Setup

Please refer to the [Proxmox LXC Spec](../../00_Infrastructure/proxmox/guests/ai-tools.md) for the specific resource allocation and provisioning details for this node, and [AI Node Security](../security.md) for SSH key management.

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

## 5. Context window

Each local model needs an explicit window. LM Studio's `/v1/models` list does not tell OpenCode how long a context the model was loaded with.

```json
"google/gemma-2-9b": {
  "name": "Gemma 2 9B",
  "limit": { "context": 125000, "output": 8192 }
}
```

`limit.context` is the window OpenCode plans for, including the prompt and tool output. `limit.output` is the reply budget it requests. 8192 leaves the rest of the 125000 for the prompt.

On this install, a model with no `limit` is treated as a window of 0, so OpenCode does not compact, and the reply request falls back to 32000 tokens.

Load that model in LM Studio at 125000 tokens, and only keep models that can hold it. See [Context length](../lm-studio/setup.md#7-context-length). The Telegram wrapper does not pass a context length.
