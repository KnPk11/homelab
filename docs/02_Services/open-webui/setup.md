# Open WebUI Setup

> [!NOTE]
> **Tags:** #OpenWebUI #Llm #Ai #DockerCompose

## 1. Basic Installation

1. Create a subdomain record and configure the reverse proxy (e.g., Caddy).
2. Deploy the Docker Compose stack using the preferred method (e.g., Portainer).
3. Navigate to `https://ai.homelab.local` and create an administrative account.

## 2. User Management

1. To create additional users, navigate to the **Admin Panel**.
2. To make models visible to these users, go to **Admin Panel** -> **Models** and adjust the visibility settings for each model.

## 3. ChatGPT Integration

1. Obtain an API key from the [OpenAI Platform](https://platform.openai.com/settings/organization/api-keys).
2. Ensure the account has sufficient balance via the [Billing Overview](https://platform.openai.com/settings/organization/billing/overview).

## 4. LM Studio Integration

1. Enable developer access in LM Studio by navigating to **App Settings** -> **Developer** and selecting **Local LLM Service (headless)**.
2. Close the settings, click on **Developer** in the top-left bar -> **Server Settings**, enable the relevant sections, and start the server.
3. In Open WebUI, navigate to **Admin Panel** -> **Settings** and add the connection: `http://[SERVICE-IP]:1234/v1` (no authentication required).

> [!TIP]
> **Multiple Computing Devices**: If utilising multiple computers for better availability, add each as a separate OpenAI API connection. Consider prefixing model names to identify which device is serving them.

## 5. ComfyUI Integration

1. In ComfyUI, go to **Settings** -> **Comfy** and enable **Dev mode**.
2. Under **Server-Config**, change the host to `0.0.0.0`.
3. Export the workflow: **File** -> **Export (API)**.
4. In Open WebUI, go to **Admin Panel** -> **Settings** -> **Images**.
5. Enable **Image Generation**, configure the parameters, and choose **ComfyUI**.
6. Upload the exported workflow JSON and map the ComfyUI Workflow Nodes according to the JSON file.
7. Repeat the process in the **Edit Image** section.

Once configured, you can instruct the LLM to generate or edit images by toggling **Integration** -> **Image** under the chat text box.

> [!WARNING]
> **Generation Errors**: If the LLM refuses to generate or edit, ensure the workflow IDs for the model are correct. The ID may be removed if it is not a required field.

## 6. Text-to-Speech (TTS) Integration

Open WebUI can integrate with OpenAI-compatible TTS services like Kokoro.

### 6.1. Custom Image for Hardware Compatibility

For specific hardware support, a custom Dockerfile may be required:

```dockerfile
FROM ghcr.io/remsky/kokoro-fastapi-gpu:latest

USER root

# 1. Install pip
ADD https://bootstrap.pypa.io/get-pip.py /tmp/get-pip.py
RUN /app/.venv/bin/python /tmp/get-pip.py

# 2. Install specific PyTorch versions for hardware support
RUN /app/.venv/bin/pip uninstall -y torch torchvision torchaudio && \
    /app/.venv/bin/pip install --pre torch torchvision torchaudio --index-url https://download.pytorch.org/whl/nightly/cu128

RUN rm /tmp/get-pip.py

USER appuser
```

### 6.2. Deployment and Configuration

1. Build and run the image:

```bash
docker build -t kokoro-custom .
docker run --gpus all -p 8880:8880 kokoro-custom
```

2. In Open WebUI, go to **Admin Panel** -> **Settings** -> **Audio**.
3. Under **Text-to-Speech**, select **OpenAI**.
4. Set the API URL to `http://[SERVICE-IP]:8880/v1`, use a dummy value for the key, and set the model to `kokoro`.

## 7. Security Guidelines

> [!IMPORTANT]
> When exposing LM Studio or ComfyUI servers on the network (listening on `0.0.0.0`), tighten firewall rules to only allow connections from the machine hosting Open WebUI to prevent unauthorised access.

