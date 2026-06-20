---
name: Migrate Homelab Scripts
description: Automates the migration of local homelab script drafts (e.g., _v1, _v2) into a version-controlled Git history, stripping secrets to .env templates and documenting deployment symlinks.
---

# Homelab Script Migration Workflow

When the user asks to migrate a script or directory of scripts, execute the following exact workflow to artificially recreate the script's evolution in Git:

## 1. Production State Sync
- SSH into the relevant production machine to retrieve the current, live version of the scripts.
- Compare the live scripts against the drafts in the repository.
- If the live version differs from the latest draft, create a new draft (e.g., `_vX+1`) with the production content before beginning the migration to ensure the Git history concludes accurately.

## 2. File Naming & Secrets
## 2. File Naming & Secrets
- The final script must be committed without version suffixes (e.g., `script_name.sh` or `config.yaml`).
- Extract any hardcoded paths, IPs, IDs, or secrets into a safe `script_name.env.example` template.
- **For Bash Scripts:** Ensure the script dynamically sources the `.env` file using the `readlink` method so it won't break when symlinked on the host:
  ```bash
  SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
  source "$SCRIPT_DIR/script_name.env"
  ```
- **For YAML / Config Files:** Configuration files (like CrowdSec or Prometheus configs) usually do not natively support dynamic `.env` sourcing. Replace secrets with standard bash variables (e.g. `${API_KEY}`). You must write a `deploy_app.sh` script that uses `envsubst` to inject the `.env` variables into the YAML templates and output them directly to the destination path (e.g. `/etc/app/config.yaml`). Do NOT symlink them.

## 3. Sequential Commits (Iterate through all versions)
- Identify all draft versions of the script in the target directory (e.g., `_v1`, `_v2`, `_v3`, etc.) and process them in chronological order.
- **For the first version:** Prepare the base script and `.env.example` with a concise docstring and sanitised variables. Commit this as the base file. *(Message: "docs: add [NODE-NAME] [SCRIPT-NAME] v1")*
- **For all subsequent versions:** Overwrite the base script and `.env.example` file with the updated content. If any draft contains a lengthy changelog in the header, remove it from the script and place it into that version's Git commit message instead. Commit each update sequentially. *(Message: "docs: update [NODE-NAME] [SCRIPT-NAME] to v[X]")*

## 4. Deployment & Cleanup
- Create or update the `deployment.md` file in the node's directory to document the exact deployment strategy. It should instruct the user to:
  1. Clone or pull the repository to a central location.
  2. Copy the `.env.example` to `.env`.
  3. **For Scripts:** Create a symlink (e.g., `sudo ln -s /opt/homelab-repo/.../script.sh /etc/cron.daily/script`) and ensure execution permissions.
  4. **For Config Templates:** Run the associated `deploy_app.sh` script to render the templates with `envsubst`.
- Delete all original draft files (e.g., `_v1.sh`, `_v2.sh`) once their history is safely captured in Git.
- Execute a single batch `git push` at the end.
