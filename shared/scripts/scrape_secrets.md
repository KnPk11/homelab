# Secrets Scraper (`scrape_secrets.sh`)

## The Problem
Because `.env` files contain highly sensitive credentials (API keys, passwords, database URLs), they are explicitly ignored in our Git repository via `.gitignore`. 
This creates an architectural challenge: if our servers die, the `.env` files are lost because they are not backed up to GitHub alongside the infrastructure code.

## The Solution (Option C)
The `scrape_secrets.sh` script is a "Centralized Scraper". It runs on a schedule from a secure management node (or NAS) and uses `rsync` to reach out to every homelab node.
It vacuums up *only* the `*.env` files across the entire node and downloads them into a local `/root/secrets_vault/` directory, completely skipping the massive YAML/Code files.

## Deployment Strategy
1. **Locate the Vault:** The vault should exist *outside* of the GitHub repository so secrets aren't accidentally committed.
   ```bash
   mkdir -p /root/secrets_vault/backups
   ```
2. **Symlink the Script:** Keep the script tracked in Git, but run it from the vault:
   ```bash
   ln -s /root/staging/shared/scripts/scrape_secrets.sh /root/secrets_vault/scrape_secrets.sh
   ```
3. **Automate via Cron:** Add the following to the `crontab -e` of your management node to execute the backup automatically every Sunday at 3:00 AM:
   ```text
   0 3 * * 0 /root/secrets_vault/scrape_secrets.sh >> /var/log/scrape_secrets.log 2>&1
   ```

## Adding New Nodes
As you migrate new machines into the GitOps architecture, simply open `scrape_secrets.sh` in the repository, add their Hostname and IP to the `NODES` mapping, and add their Hostname to the `GITOPS_HOSTS` array at the top of the file!
