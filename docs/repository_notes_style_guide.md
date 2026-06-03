# Homelab Documentation Style Guide

This guide ensures consistency across all documentation in the homelab repository.

## 1. Headings & Structure
- **H1 (#)**: Every document MUST start with exactly one H1 for the document title (Better for GitHub previews).
- **Metadata & Tags**: Place the Tags callout immediately AFTER the H1 title.
  - Use the `[!NOTE]` callout type.
  - Keywords (NOTE, TIP, WARNING, etc.) must be **ALL CAPS**.
  - Format: `**Tags:** #Tag1 #Tag2`
- **H2 (##)**: Major sections (e.g., Installation, Configuration, Storage).
- **H3 (###)**: Sub-sections within major sections.
- Use horizontal rules (`---`) to separate major conceptual blocks if needed.

## 2. Callouts (Admonitions)
Use Obsidian-style callouts for highlights. Keywords must be uppercase.
Supported types: `[!NOTE]`, `[!TIP]`, `[!IMPORTANT]`, `[!WARNING]`, `[!SUCCESS]`.

### Hybrid Titling Rule:
- **Short Titles**: If the title is short, place it on the same line as the content using a colon.
  - *Example*: `> [!TIP] **Firewall**: Ensure port 514 is open.`
- **Long Titles**: If the title is long or requires emphasis, place it on its own line followed by a blank line.
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
- **Project/Repo Names**: Replace personal branding (e.g., "Susnode") with generic terms like "Homelab" or "MyLab".
- **Usernames**: Replace your real username with `[USER]` or `[PERSONAL-USER]`.
- **UUIDs/Secrets**: Use `[DISK-UUID]`, `[VOLUME-ID]`, or `[SECRET]`.
- **IP Addresses**: Use internal ranges (e.g., `192.168.1.x`) or generic examples (e.g., `10.x.x.x`).
- **Domain Names**: Use `.home`, `.local`, or `example.com`.

## 8. Testing & Verification
Prefer keeping extended testing and verification notes to ensure configurations can be validated in the future.
- **Formatting**: If the original verification steps are too messy or contain excessive comments, condense them into a clean, step-by-step format while retaining all critical commands and expected outcomes.
- **Tooling**: Include specific `nmap`, `curl`, or `ping` commands used for verification.

## 9. Language & Spelling
- **Locale**: Use **British English** for all documentation.
  - *Examples*: `utilise` (not utilize), `organise` (not organize), `colour` (not color), `centre` (not center).
