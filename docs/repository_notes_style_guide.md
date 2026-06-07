# Homelab Documentation Style Guide

This guide ensures consistency across all documentation in the homelab repository.

## 1. Headings & Structure
- **H1 (#)**: Every document MUST start with exactly one H1 for the document title (Better for GitHub previews).
- **Metadata & Tags**: Place the Tags callout immediately AFTER the H1 title.
  - Use the `[!NOTE]` callout type.
  - Keywords (NOTE, TIP, WARNING, etc.) must be **ALL CAPS**.
  - Format: `**Tags:** #Tag1 #Tag2`
- **H2 (##) & H3 (###)**: Major sections (e.g., Installation, Configuration, Storage).
- **Sequential Steps**: Setup or installation steps that must be followed in order MUST use numbered subheadings (e.g., `## 1. Installation`, `## 2. Configuration`) to visually imply a "Happy Path" and ensure resumability. Reference or troubleshooting sections should remain unnumbered.
- Use horizontal rules (`---`) to separate major conceptual blocks if needed.

## 2. Callouts (Admonitions)
Use Obsidian-style callouts for highlights. Keywords must be uppercase.
Supported types: `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!SUCCESS]`.

### Hybrid Titling Rule:
- **Spacing**: ALWAYS place the content on a new line after the callout type (e.g., `> [!NOTE]` followed by a newline).
- **Short Titles**: If the title is short, place it on the next line using a colon.
  - *Example*:
    ```markdown
    > [!NOTE]
    > **Firewall**: Ensure port 514 is open.
    ```
- **Long Titles**: If the title is long or requires emphasis, place it on its own line followed by a blank line and then the content.
  - *Example*:
    ```markdown
    > [!WARNING]
    > **Proxmox Snapshot Flag**
    > 
    > To prevent data loss...
    ```

## 5. Code Blocks
Always specify the language for syntax highlighting.
```bash
sudo apt update
```

## 6. Tables
Use tables for comparing options or listing configuration parameters.

| Option | Recommendation | Description |
| :--- | :--- | :--- |
| Feature | ✅ Enabled | Why it is enabled |
| Legacy | ❌ Disabled | Why it is disabled |

## 7. Data Sanitization
Before committing, ensure all sensitive or personal information is replaced with generic placeholders.
- **Format**: Use square brackets and uppercase for user-specific variables (e.g., `[DISK-UUID]`, `[PERSONAL-USER]`).
- **Project/Repo Names**: Replace personal branding (e.g., "Homelab") with generic terms like "Homelab" or "MyLab".
- **Usernames**: Replace your real username with `[USER]` or `[PERSONAL-USER]`.
- **UUIDs/Secrets**: Use `[DISK-UUID]`, `[VOLUME-ID]`, or `[SECRET]`.
- **IP Addresses**: 
  - Use generic internal ranges (e.g., `192.168.1.x`) for general examples.
  - **Specific Nodes**: For specific host IP addresses, ALWAYS use bracketed placeholders (e.g., `[SERVICE-IP]`, `[CADDY-IP]`, `[LAPI-IP]`) instead of numeric values.
- **Domain Names**: Use `.home`, `.local`, or `example.com`.

## 8. Testing & Verification
Prefer keeping extended testing and verification notes to ensure configurations can be validated in the future.
- **Formatting**: If the original verification steps are too messy or contain excessive comments, condense them into a clean, step-by-step format while retaining all critical commands and expected outcomes.
- **Tooling**: Include specific `nmap`, `curl`, or `ping` commands used for verification.

## 9. Language & Spelling
- **Locale**: Use **British English** for all documentation.
  - *Examples*: `utilise` (not utilize), `organise` (not organize), `colour` (not color), `centre` (not center).

## 10. Service Documentation
- **File Separation**: Keep `setup.md` and `security.md` as separate files for each service.
- **Exception**: If the security section is very small and simple, it may be included within the `setup.md` file to avoid unnecessary file clutter.

## 11. Project Workflow & Secrets
- **Docs First**: The primary repository focus is on sanitised documentation (`docs/`). Operational scripts and compose files are maintained but are secondary during the migration phase.
- **Script History**: We intentionally maintain multiple versioned files (e.g., `Caddyfile_v1`, `Caddyfile_v2`) in the operational `nodes/` directories to artificially recreate a basic commit history when they are eventually pushed to source control.
- **SOPS Integration**: Operational files in `nodes/` are intentionally left un-sanitised as they act as the true source for homelab deployments. They are excluded from initial public commits and will be encrypted via **SOPS (Secrets OPerationS)** in the future prior to being committed.
