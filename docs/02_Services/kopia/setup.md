# Kopia Setup

> [!NOTE]
> #Kopia #Backup #Encryption #DataProtection


## 1. Description

Kopia is a fast, encrypted backup tool with client-side encryption, compression, and deduplication to local or remote repositories.

## 2. Installation

1. Install the GPG signing key to verify the authenticity of the releases:

   ```bash
   curl -s https://kopia.io/signing-key | sudo gpg --dearmor -o /etc/apt/keyrings/kopia-keyring.gpg
   ```

2. Register the APT source:

   ```bash
   echo "deb [signed-by=/etc/apt/keyrings/kopia-keyring.gpg] http://packages.kopia.io/apt/ stable main" | sudo tee /etc/apt/sources.list.d/kopia.list
   sudo apt update
   ```

3. Finally, install Kopia or KopiaUI:

   ```bash
   sudo apt install kopia
   sudo apt install kopia-ui
   ```

## 3. Docker Installation (Alternative)

1. Install the password hashing tool:

   ```bash
   sudo apt install apache2-utils
   ```

2. Set the Web UI password for user `[USER]`:

   ```bash
   sudo htpasswd -c -B /srv/kopia/config/htpasswd [USER]
   ```

3. Copy the Docker Compose stack into Portainer and start it.
