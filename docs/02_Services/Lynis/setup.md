# Lynis Setup

> [!NOTE]
> **Tags:** #Security #Auditing #Native

Lynis is an open-source security auditing tool designed to assist in system hardening.

## 1. Installation

Install Lynis directly on the system:

   ```bash
   sudo apt update && sudo apt install -y lynis
   ```

## 2. Portable Execution

> [!TIP] Portable Run
> If you prefer not to install Lynis on a target machine, you can run it portably:

   ```bash
   wget https://cisofy.com/files/lynis-3.1.2.tar.gz
   tar xzf lynis-3.1.2.tar.gz
   cd lynis
   ./lynis audit system
   ```

## 3. Audit Commands

Execute an audit on a remote system:

1. Run a non-interactive audit:

   ```bash
   ssh [HOST-IP] "lynis audit system --quick --no-log"
   ```

2. Retrieve specific findings:

   ```bash
   ssh [HOST-IP] "cat /var/log/lynis-report.dat"
   ```

> [!TIP]
> Utilise agentic AI to assist in narrowing down and focusing on addressing the most significant findings.
