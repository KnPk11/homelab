# Heimdall Security

## 1. Access Control

- Accounts are limited; serving a public URL may allow unauthorised users to modify widgets unless the container is mounted as **read-only** in Docker.
- **Hiding Sensitive Links**:
  - Set up an admin account with a password.
  - Set up a separate public account and enable **Allow public access to front**.
  - Note that while passwords secure editing, live metrics may no longer be visible.
- **Alternative Strategy**: Maintain one Heimdall instance as a public, read-only landing page and link it to a second, password-protected instance (or host it at a separate subpath).

## 2. Credential Security

Be aware that Heimdall stores service passwords in plaintext for its widgets.

## 3. Authentication Issues

> [!ERROR] Auth Rate Limiting
> Heimdall does not always display appropriate authentication errors. It may return a status code `200` even upon failed login attempts.
