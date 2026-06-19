# Project Send Setup

> [!NOTE]
> **Tags:** #ProjectSend #WebDAV #Files #FileSharing #DockerCompose

## 1. Description

A self-hosted file sharing application designed for businesses and individuals to share files with clients or users securely.

## 2. Installation

> [!NOTE]
> This setup assumes running Project Send as a URL subpath, rather than a subdomain.

1. **Initial Setup**: Deploy the container initially with the reverse proxy disabled and utilise standard ports `80` and `443`.
2. **Registration**: Complete the registration via the Web UI.
3. **Configuration**: In the application settings, specify the URI as `/projectsend/`.
4. **Reverse Proxy**: Enable Caddy and update the Docker Compose file to use `expose: 80` instead of port mapping.

## 3. Docker Compose Troubleshooting

If the backend reports a `java.sql.SQLException: The url cannot be null` error, ensure all database connection strings are correctly defined in the environment variables.