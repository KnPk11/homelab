# Netdata Security

## 1. Dashboard Access

- The public dashboard state only persists on the client device. However, exposing a Netdata instance publicly presents a significant security risk for system reconnaissance.
- It is highly recommended to restrict dashboard access to the local network (LAN), utilize basic authentication via a reverse proxy, or register a secure account.

## 2. Monitoring Integration

If access is restricted to the LAN, tools like Heimdall can still pull live system usage metrics by utilizing the internal service URL: `http://netdata:19999`.
