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
- Extract any hardcoded paths, IPs, IDs, or environment secrets into a safe `script_name.env.example` template.
- **For File-Based Secrets:** If the original drafts reference file-based secrets in a global directory (e.g., `/data/secrets/...`), instruct the user to migrate them into a local git-ignored `.secrets/` directory within the service. However, because Portainer deployments do not clone git-ignored files, update the configurations (like `docker-compose.yml` and `.env.example`) to reference an **absolute host path** (e.g., `/srv/[service-name]/.secrets/secret_name`) rather than a relative path.
- **For Bash Scripts:** Ensure the script dynamically sources the `.env` file using the `readlink` method so it won't break when symlinked on the host:
  ```bash
  SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
  source "$SCRIPT_DIR/script_name.env"
  ```
- **For YAML / Config Files:** Configuration files (like CrowdSec or Prometheus configs) usually do not natively support dynamic `.env` sourcing. Replace secrets with standard bash variables (e.g. `${API_KEY}`). You must write a `deploy_app.sh` script that uses `envsubst` to inject the `.env` variables into the YAML templates and output them directly to the destination path (e.g. `/etc/app/config.yaml`). Do NOT symlink them.
- **For Docker Compose / Portainer Stacks:** 
  - Do not write scripts that copy `docker-compose.yml` to the live destination path (e.g., `/srv/...`). The compose file should remain exclusively in the Git repository to be orchestrated via Portainer's Git integration. The `deploy_app.sh` script should only handle the rendering and delivery of configuration files/templates that the containers will mount.
  - For host volume mounts in the `docker-compose.yml`, use environment variable fallback templating for the host path (e.g., `${SERVICE_CONFIG_PATH:-/srv/service/config.yml}:/app/config.yml`). This enables dynamic overrides via Portainer while maintaining a solid default.

## 3. Sequential Commits (Iterate through all versions)
- Identify all draft versions of the script in the target directory (e.g., `_v1`, `_v2`, `_v3`, etc.) and process them in chronological order.
- **For the first version:** Rename the first draft (e.g., `_v1.sh`) to its final name without the version suffix (e.g., `script_name.sh`). Prepare this base script and its `.env.example` with a concise docstring and sanitised variables. Commit *only* the final base files (ensure the other `_vX` drafts are not committed). *(Message: "docs: add [NODE-NAME] [SCRIPT-NAME] v1")*
- **For all subsequent versions:** Apply the changes from the next draft (e.g., `_v2.sh`) by overwriting the final base script and `.env.example` file. Once the content is applied, delete the original draft file (e.g., `_v2.sh`) to keep the directory clean. If any draft contains a lengthy changelog in the header, remove it from the script and place it into that version's Git commit message instead. Commit each update sequentially. *(Message: "docs: update [NODE-NAME] [SCRIPT-NAME] to v[X]")*

## 4. Deployment & Cleanup
- Create or update the `deployment.md` file in the node's directory to document the exact deployment strategy. It should instruct the user to:
  1. Clone or pull the repository to a central location.
  2. Copy the `.env.example` to `.env`.
  3. Migrate any file-based secrets from legacy global directories (e.g., `/data/secrets/`) into the service's new local `.secrets/` directory.
  4. **For Scripts:** Create a symlink (e.g., `sudo ln -s /opt/homelab-repo/.../script.sh /etc/cron.daily/script`) and ensure execution permissions.
  5. **For Config Templates & Secrets:** Ensure the associated `deploy_app.sh` script renders configuration templates with `envsubst` to the destination path. It MUST also include a step to securely copy the `.secrets/` directory to the absolute host path (e.g., `/srv/[service-name]/.secrets/`) with strict permissions (`chmod -R 600`), so Portainer can access them. Run the deployment script to test.
- SSH into the target production node and actually execute the deployment strategy to ensure the live environment files reflect the repository and are no longer standalone.
- Execute a single batch `git push` at the end.
