# NVIDIA Build data boundary

> [!NOTE]
> #AI #Security #Nvidia #Grok #Antigravity #ChatGPT #Claude

## 1. Description

Where the free NVIDIA Build key (`https://integrate.api.nvidia.com/v1`) may run, and how that differs from ChatGPT, Antigravity, Claude Code, Grok Build on the `ai-tools` node.

Checked against the [NVIDIA API Trial Terms of Service](https://assets.ngc.nvidia.com/products/api-catalog/legal/NVIDIA%20API%20Trial%20Terms%20of%20Service.pdf) (19 September 2025). Re-read those terms before relying on this page; NVIDIA can change them on publication.

## 2. Rule

Keep the NVIDIA Build key off any agent that can see homelab SSH keys, env files, or the `ai-tools` checkout.

Antigravity and Grok on this node stay on a plan that does not train on prompts. NVIDIA sees only text you would post in public, from a machine that does not hold homelab secrets.

If the same open weights need to run inside the homelab, run them locally. The gaming PC path is [LM Studio on the gaming PC](lm-studio/setup.md). The free Build key is remote inference.

## 3. Why the free key is different

NVIDIA's trial terms say prompts and model outputs are collected, without tying them to your account, to improve NVIDIA products and services, including AI models (section 3.3). The same terms tell you not to send confidential, personal, financial, health, or government data (sections 2.6 and 4.3). There is no training opt-out on this key. Stripping the account id does not strip a key or a database URL out of the prompt.

A paid commercial API is a different contract: process the request, keep it for a short abuse-review window (often about 30 days), and do not train on it unless you opt in. That is the published position for the xAI API, Claude Team / Enterprise / the Anthropic API, and the paid Gemini API.

The coding agent is still the larger live risk. It has the shell, the files, and the SSH keys, so a bad command happens on this machine. NVIDIA only receives what the request contains, unless you give that model the same tools.

## 4. What a paid login does not guarantee

| Surface | Training on what you send | Notes |
| :--- | :--- | :--- |
| NVIDIA Build free key | Yes, per the trial terms | Trial use only. Do not point a tool-using agent at it. |
| Claude Free, Pro, Max, including Claude Code on those accounts | Only while "Help improve our AI models" is on | On: sessions can be kept for up to 5 years. Off: about 30 days. |
| Claude Team, Enterprise, Anthropic API | No, unless you opt in | Standard retention about 30 days. Feedback you submit can still be used. |
| Grok consumer app | While "Improve the model" is on | Separate from the API. |
| xAI API and Grok Build on API terms | No, unless you give permission | Default keep is about 30 days. Zero Data Retention is a separate switch. |
| Gemini API, free / AI Studio | Yes, used to improve Google's products | Do not send homelab secrets. |
| Gemini API, paid | No | Abuse logging still applies. |

Confirm the account the CLI is signed into. Claude Code follows the plan on that login, not the repository you open.

> [!WARNING]
> **Client uploads**
>
> A model call and the CLI (eg. OpenCode, Antigravity, Grok Build) are not the same pipe. In July 2026, public reports said an early Grok Build build uploaded the whole git repository, history included, and that turning off model-improvement did not stop it. Before an agent runs on this node, check the current retention and upload settings for that CLI.

## 5. Safe use of the NVIDIA key

1. Run it on a scratch host or VM. No home-directory mount, no `ssh-agent`, no `~/.ssh`, no kubeconfig, no Docker socket, no homelab `.env` files, and no route to management networks that would matter without credentials.
2. Put the NVIDIA key only on that host, in its own file.
3. From `ai-tools`, call NVIDIA as text in, text out. The local agent cuts a snippet; NVIDIA rewrites that snippet; the local agent applies the result. Do not set Grok, Antigravity, or Claude Code's model router to `integrate.api.nvidia.com` on this checkout.
4. Spend the paid allowance on the live tree, logs, and deploy config. Spend NVIDIA on boilerplate, one pasted function, public code, and greenfield experiments.

A secret scanner in front of the NVIDIA host is a backstop. It does not make it safe to point a tool-using agent at this machine.
