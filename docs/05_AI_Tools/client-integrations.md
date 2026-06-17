# Client Integrations

> [!NOTE]
> **Tags:** #Ai #Integrations #AnyType #Obsidian #VsCode #Mcp #LmStudio

## 1. Description

A consolidated reference for connecting personal productivity tools and development environments to self-hosted AI services and local LLM providers.

## 2. AnyType Integration

Utilise the **AnyType MCP (Model Context Protocol)** to allow LLMs to interact with your AnyType vault.

1. **API Configuration**:
   - Navigate to **Settings** -> **Vault** -> **API Keys**.
   - Generate a new API key.
2. **Installation**: Install the AnyType MCP plugin globally:
   
   ```bash
   npm install -g @anyproto/anytype-mcp
   ```
3. **LM Studio Setup**:
   - Enable **Server Mode** in LM Studio.
   - Navigate to **Chats** -> **Integrations**.
   - Select **Install** -> **Edit mcp.json**.
   - Paste the sample snippet from the official repository and provide your AnyType API key.
4. **Usage**: Create a new chat and ensure the `mcp/anytype` toggle is active.

## 3. Obsidian Integration

Connect Obsidian to your local AI node for enhanced note-taking and analysis.

1. **Host Configuration**:
   - Ensure LM Studio is running in **Server Mode**.
   - Verify the binding IP in `.lmstudio\.internal\http-server-config.json` if using mesh networks (e.g., Tailscale).
2. **Plugin Setup**:
   - Install the **Private AI** extension from the Obsidian community marketplace.
   - Update the API and Embedding endpoints to point at your node:
     - Chat completions: `http://[AI-IP]:1234/v1/chat/completions`
     - Embeddings: `http://[AI-IP]:1234/v1/embeddings`

## 4. VS Code (Continue) Integration

Integrate your self-hosted LLMs directly into your development workflow using the **Continue** extension.

1. **Preparation**:
   - Enable API keys in your **Open WebUI** profile settings.
   - Generate a new API key under **Settings** -> **Account** -> **API keys**.
2. **Extension Setup**:
   - Install the **Continue** extension in VS Code.
   - Navigate to **Settings** -> **Configs** -> **Local Config**.
3. **Configuration**: Add your local models to the `models` array:
   
   ```yaml
   models:
     - name: "Local LLM"
       provider: openai
       model: "[MODEL-ID]"
       apiBase: "https://[AI-URL]/api/v1"
       apiKey: "[SECRET]"
       roles:
         - chat
         - edit
   ```

4. **Autocomplete Verification**: Navigate to the **Models** section in the Continue UI and ensure the correct model is selected under the **Autocomplete** heading.
5. **Further Reference**: Refer to the [official quick-start guide](https://docs.continue.dev/ide-extensions/quick-start) for advanced usage and features.

> [!TIP]
> **Autocompletion**: Ensure the chosen model is compatible with code autocompletion. Set the preferred model under the **Autocomplete** section in the Continue settings menu.

## 5. Appendix A: Sample Continue Configuration

A sanitised template for the `config.yaml` / `config.json` used by the **Continue** extension.

```yaml
name: Local Config
version: 1.0.0
schema: v1
models:
  - name: "Self-Hosted GPT"
    provider: openai
    model: "[MODEL-ID]"
    apiBase: "https://[AI-URL]/api/v1"
    apiKey: "[SECRET]"
    roles:
      - chat
      - edit

  - name: "Local Llama (LM Studio)"
    provider: openai
    model: "[MODEL-ID]"
    apiBase: "http://[LOCAL-IP]:1234/v1"
    apiKey: "not-needed"
    roles:
      - chat
      - edit

  - name: "Local Autocomplete"
    provider: openai
    model: "[MODEL-ID]"
    apiBase: "https://[AI-URL]/api/v1"
    apiKey: "[SECRET]"
    roles:
      - chat
      - edit
      - autocomplete
    useLegacyCompletionsEndpoint: false
    requestOptions:
      stream: true
      responseFormat: text
      extraBodyProperties:
        think: false
        
context:
  - provider: code
  - provider: docs
  - provider: diff
  - provider: terminal
  - provider: problems
  - provider: folder
  - provider: codebase
```
