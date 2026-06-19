# OwnCloud Setup

> [!NOTE]
> **Tags:** #OwnCloud #Cloud #Productivity #Files #Collaboration #DockerCompose

## 1. Description

A self-hosted personal cloud storage and collaboration platform for synchronising and sharing files.

## 2. Installation

1. **Configure Subpath**: Update the configuration to point at the required URL subpath:
   
   ```bash
   docker exec -it owncloud bash
   apt update && apt install nano
   nano /var/www/owncloud/config/config.php
   ```

1. **Update Settings**: Add the following lines to the configuration file (note that this uses a custom path rather than a subdomain):
   
   ```php
   'overwrite.cli.url' => 'http://homelab.local/owncloud',
   'overwritewebroot' => '/owncloud',
   'htaccess.RewriteBase' => '/owncloud',
   ```

2. **Reverse Proxy**: Ensure the Caddyfile is updated to reflect these changes.
3. **Access**: Access OwnCloud at `https://homelab.local/owncloud/`.

## 3. Additional Configuration

### Local File Access

To enable local file access, add the following to the configuration file and toggle the **External storage support** app:

```php
'enable_local_external_storage' => true,
'files_external_allow_create_new_local' => true,
```

Once enabled, a 'local' option will appear under the storage section.
