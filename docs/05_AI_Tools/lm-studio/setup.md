# LM Studio on the gaming PC

> [!NOTE]
> #LMStudio #LocalLlm #Grok #Antigravity #GamingPc

## 1. Description

The gaming PC (with an RTX 5090 GPU) serves local models through LM Studio's OpenAI-compatible API. Sections 4 and 5 outline how a CLI can call that API.

Prompts to this server stay on the LAN. They do not go to the NVIDIA Build free key. See [NVIDIA Build data boundary](../nvidia-build.md). Chat-only use from Open WebUI is in [Open WebUI Setup](../../02_Services/open-webui/setup.md#5-lm-studio-integration).

## 2. Turn the server on

On the gaming PC, in LM Studio:

1. **App Settings** → **Developer** → enable **Local LLM Service (headless)**.
2. **Developer** (top-left) → **Server Settings**. Enable the server and start it. The default port is `1234`.
3. Load a model that LM Studio marks as able to call tools and preferably fits fulle on the RTX 5090 card.
4. Leave the PC awake while agents are using it. Grok and Antigravity must keep a cloud model as the parent so a powered-off PC does not stop the session.

From `ai-tools` (`192.168.50.105`):

```bash
curl -sS http://192.168.50.248:1234/v1/models
```

Copy the `id` of the loaded model. That string is the `model` value in section 4.

> [!WARNING]
> **Do not publish port 1234**
>
> Serving on the LAN makes the API reachable by every host that can route to the PC. Do not forward `1234` on the router. LM Studio may keep request logs on the gaming PC disk, so treat that PC as inside the trust boundary.

## 3. Firewall

Allow TCP `1234` only from the hosts that call it:

- `ai-tools`: `192.168.50.105`
- the Open WebUI host (`docker-services`), if that chat UI should keep using the same server

On Windows, as Administrator, after you have confirmed the PC's current address:

```powershell
New-NetFirewallRule -DisplayName "LM Studio ai-tools" -Direction Inbound -Protocol TCP -LocalPort 1234 -RemoteAddress 192.168.50.105 -Action Allow
```

Add a second rule for the Open WebUI host's address. Do not use `-RemoteAddress Any`.

## 4. Several models in one CLI

OpenCode, Grok Build, and any other CLI that stores a base URL on each model can list LM Studio next to its cloud providers. Each entry keeps its own URL, so a turn on the gaming PC leaves the cloud model in place for everything else.

The field list for Grok is the one in [How to Run Grok Build with Local Models](https://imya.ai/blog/grok-build-local-inference). The block below is a sketch for this server. It is not in `~/.grok/config.toml` on `ai-tools`.

1. Copy the model `id` from the curl in [section 2](#2-turn-the-server-on).
2. Add one entry per provider. For Grok, on the host that runs it:

   ```toml
   [model.gaming-pc]
   model = "<id from /v1/models>"
   base_url = "http://<gaming-pc>:1234/v1"
   name = "Gaming PC"
   api_backend = "chat_completions"
   context_window = 32768
   ```

3. Set `context_window` to the length LM Studio loaded for that model. Restart Grok. `/model` lists **Gaming PC**. Leave the default model on Grok, and select **Gaming PC** for a turn that should run on the card.
4. For OpenCode, add a provider the same way as in [OpenCode Setup](../opencode/setup.md#4-local-llm-providers). `baseURL` is `http://<gaming-pc>:1234/v1`. The model keys are the ids from `/v1/models`. If OpenCode asks for a key, any placeholder works for this server.
5. For any other CLI with per-model base URLs, add one entry and point that entry's URL at port `1234`.

A loaded model that cannot emit tool calls will fail when the CLI asks it to edit or run commands. Keep those turns on the cloud model, or use the skill in the next section for text-only jobs.

Grok's secret deny rules still apply when the model is local. See [Grok CLI Setup](../grok/setup.md#4-safeguards--permission-rules).

## 5. One catalog per session

Antigravity, on `ai-tools`, and Claude Code keep the session on their own catalog. A custom `model` there names a catalog model. Two ways to still reach the gaming PC are below.

### Hermes or Paperclip

Hand LM Studio to a tool that already keeps more than one provider. Antigravity or Claude Code stays on its catalog.

- **Hermes.** Add the gaming PC as another OpenAI-compatible endpoint (`http://<gaming-pc>:1234/v1`) beside the providers in [Hermes Dashboard](../../02_Services/hermes/setup.md), then select that model in Hermes.
- **Paperclip.** A run starts a local harness. Paperclip does not call the model API itself. Point an OpenCode or Hermes agent at the same URL. Custom gateways already work that way for NVIDIA Build. See [Paperclip Setup](../../02_Services/paperclip/setup.md).

### Custom skill

The CLI stays the parent. A skill tells it to shell out for small text jobs. The pattern is [How I Taught Claude Code to Offload Grunt Work to a Local 4B Model](https://pub.towardsai.net/claude-code-skill-local-qwen-3c6bb5d051bd). That post uses llama.cpp. Here the script targets LM Studio.

1. Add a skill the CLI loads when the task matches its description. Limit that description to short, self-contained text: a summary, a reword, a list of names. Leave out code edits, secrets, and anything that needs the repo.
2. Add a script beside the skill. It reads a prompt on stdin, POSTs it to `http://<gaming-pc>:1234/v1/chat/completions` with the model id from section 2, and prints the reply text.
3. The skill tells the CLI to pipe the prompt into the script and to check the reply before using it.
4. Restart the CLI. From a shell, `echo 'Reply with the single word pong.' | <script>` should print `pong` before you try it inside the CLI.

The script sees only the text the parent passes in. For Antigravity, put the same instructions on a custom agent under `~/.gemini/config/agents/` and leave `model` on a catalog model. For Claude Code, the skill folder in that write-up is `~/.claude/skills/<name>/`.

> [!WARNING]
> Setting the CLI's own base URL to LM Studio sends every turn to the gaming PC, including the ones that should stay on the catalog model. Call LM Studio from the script only.

## 6. What belongs on the local model

If you adopt one of the options above:

| Work | Where |
| :--- | :--- |
| A turn you are willing to run on the card | A CLI from section 4, with that turn on the gaming PC model |
| A short pasted snippet: summary, reword, names | The skill in section 5, or Hermes / Paperclip pointed at LM Studio |
| Live tree, deploy config, credentials, refactors that apply patches | The cloud parent |

## Checks

These check the server. The client options in sections 4 and 5 are not configured, so there is nothing further to verify until one of them is tried.

1. `curl -sS http://192.168.50.248:1234/v1/models` from `ai-tools` returns the loaded id, and the same curl from a host that is not in the firewall rule fails.
2. Power the gaming PC off and confirm the parent CLI still runs.
