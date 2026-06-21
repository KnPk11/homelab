# Caddy-101 Master Bootstrap Guide

This node operates on a strict **Infrastructure as Intent** methodology. Do not edit files directly on the server. Instead, push updates to the Git repository, pull them on the server, and restart the respective services.

If this machine ever suffers a catastrophic failure, follow the deployment guides below in this exact order to nuke-and-pave it back to a working state.

## 1. System Scripts & Cron Jobs
*   [Process Logs Script](scripts/deployment.md)

## 2. Reverse Proxy & Security
*   [Caddy Reverse Proxy](services/Caddy/deployment.md)
*   [CrowdSec IPS](services/CrowdSec/deployment.md)
*   [Fail2Ban Monitor](services/Fail2Ban\ Monitor/deployment.md)

## 3. Observability
*   [Gatus Status Page](services/Gatus/deployment.md)
