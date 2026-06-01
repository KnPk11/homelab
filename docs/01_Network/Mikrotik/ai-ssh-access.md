> [!NOTE]
> **Tags:** #MikroTik #SSH #Security #Agent

# MikroTik Remote Access Setup Guide

This document outlines the steps taken to enable secure SSH access for the Gemini CLI agent to the MikroTik router.

## 1. User Creation

A dedicated user was created to isolate agent activities and allow for easy permission management.

```bash
/user add name=[AGENT-USER] group=full comment="Gemini CLI Agent"
```

## 2. SSH Key Authentication

To allow passwordless access, the agent's public key was imported.

```bash
# Create the key file on the router
/file add name=[AGENT-USER].pub contents="[AGENT-PUBLIC-KEY]"

# Import the key for the agent user
/user ssh-keys import public-key-file=[AGENT-USER].pub user=[AGENT-USER]

# Clean up
/file remove [AGENT-USER].pub
```

## 3. Firewall Authorisation

Since the agent resides in the AI Tools container (`[AGENT-CONTAINER-IP]`), an explicit allow rule was added before the general SSH drop rule.

```bash
/ip firewall filter add chain=input action=accept protocol=tcp \
    src-address=[AGENT-CONTAINER-IP] dst-port=22 \
    comment="Allow Gemini CLI SSH" place-before=[DROP-RULE-INDEX]
```

## 4. Connection Verification

The connection can be verified from the agent's environment:

```bash
ssh -i /root/.ssh/id_ed25519 [AGENT-USER]@[ROUTER-IP] "/ip firewall nat print"
```

## 5. Security Notes

*   **User:** `[AGENT-USER]`
*   **Access Method:** SSH Key (ED25519)
*   **Source IP:** `[AGENT-CONTAINER-IP]`
*   **Port:** 22
*   **Permissions:** Currently set to `full` to allow diagnostic and configuration commands.
