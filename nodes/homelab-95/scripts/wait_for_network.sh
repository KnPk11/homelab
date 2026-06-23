#!/bin/bash
# ==============================================================================
# Network Availability Waiter - Version 1.1
# ==============================================================================
# Delays script execution until the 'ens18' interface is assigned the 
# static IP 192.168.50.95. Useful for services that depend on networking 
# being fully initialized.
# ==============================================================================

while ! ip addr show ens18 | grep -q "192.168.50.95"; do
    sleep 1
done