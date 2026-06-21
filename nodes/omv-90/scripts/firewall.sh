#!/bin/bash
# ==============================================================================
# OMV Firewall Rules Generator
# Generates iptables rules in JSON for OMV and applies them via omv-rpc/omv-salt.
# ==============================================================================

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/firewall.env"

export PATH=$PATH:/usr/sbin:/sbin:/usr/bin:/bin

# Function to generate a rule object
gen_rule() {
  local rulenum=$1
  local chain=$2
  local action=$3
  local protocol=$4
  local dport=$5
  local source=$6
  local comment=$7
  local extra=$8
  local family=$9
  local uuid=$(cat /proc/sys/kernel/random/uuid)

  cat <<EOR
{
  "uuid": "$uuid",
  "rulenum": $rulenum,
  "chain": "$chain",
  "action": "$action",
  "family": "$family",
  "source": "$source",
  "sport": "",
  "destination": "",
  "dport": "$dport",
  "protocol": "$protocol",
  "extraoptions": "$extra",
  "comment": "$comment"
}
EOR
}

echo "[+] Preparing IPv4 rules..."
rules_v4="["
rules_v4="$rules_v4$(gen_rule 0 "INPUT" "ACCEPT" "all" "" "" "Allow Established" "-m conntrack --ctstate ESTABLISHED,RELATED" "inet"),"
rules_v4="$rules_v4$(gen_rule 1 "INPUT" "ACCEPT" "all" "" "" "Allow Loopback" "-i lo" "inet"),"
rules_v4="$rules_v4$(gen_rule 2 "INPUT" "ACCEPT" "tcp" "22" "$LAN_SUBNET" "SSH LAN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 3 "INPUT" "ACCEPT" "tcp" "22" "$VPN_SUBNET" "SSH VPN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 4 "INPUT" "ACCEPT" "tcp" "22" "$AITOOLS_IP" "SSH AI Tools" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 5 "INPUT" "ACCEPT" "tcp" "22" "$CADDY_IP" "SSH Caddy LXC" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 6 "INPUT" "ACCEPT" "tcp" "80" "$LAN_SUBNET" "Web UI HTTP LAN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 7 "INPUT" "ACCEPT" "tcp" "80" "$VPN_SUBNET" "Web UI HTTP VPN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 8 "INPUT" "ACCEPT" "tcp" "443" "$LAN_SUBNET" "Web UI HTTPS LAN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 9 "INPUT" "ACCEPT" "tcp" "443" "$VPN_SUBNET" "Web UI HTTPS VPN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 10 "INPUT" "ACCEPT" "tcp" "445" "$LAN_SUBNET" "SMB LAN 445" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 11 "INPUT" "ACCEPT" "tcp" "445" "$VPN_SUBNET" "SMB VPN 445" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 12 "INPUT" "ACCEPT" "tcp" "445" "$HOMELAB_NODE_IP" "SMB 445 Homelab Node" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 13 "INPUT" "ACCEPT" "tcp" "139" "$LAN_SUBNET" "SMB LAN 139" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 14 "INPUT" "ACCEPT" "tcp" "139" "$VPN_SUBNET" "SMB VPN 139" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 15 "INPUT" "ACCEPT" "tcp" "139" "$HOMELAB_NODE_IP" "SMB 139 Homelab Node" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 16 "INPUT" "ACCEPT" "tcp" "2049" "$HOMELAB_SUBNET" "NFS Data" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 17 "INPUT" "ACCEPT" "tcp" "111" "$HOMELAB_SUBNET" "NFS RPC Bind TCP" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 18 "INPUT" "ACCEPT" "udp" "111" "$HOMELAB_SUBNET" "NFS RPC Bind UDP" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 19 "INPUT" "ACCEPT" "icmp" "" "$LAN_SUBNET" "Ping LAN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 20 "INPUT" "ACCEPT" "icmp" "" "$VPN_SUBNET" "Ping VPN" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 21 "INPUT" "ACCEPT" "icmp" "" "$HOMELAB_SUBNET" "Ping Homelab" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 22 "OUTPUT" "ACCEPT" "all" "" "" "Allow All Outbound" "" "inet"),"
rules_v4="$rules_v4$(gen_rule 23 "INPUT" "DROP" "all" "" "0.0.0.0/0" "DENY ALL IPv4" "" "inet")"
rules_v4="$rules_v4]"

echo "[+] Preparing IPv6 rules..."
rules_v6="["
rules_v6="$rules_v6$(gen_rule 0 "INPUT" "DROP" "all" "" "::/0" "DENY ALL IPv6" "" "inet6")"
rules_v6="$rules_v6]"

echo "[+] Applying rules to OMV Database..."
/usr/sbin/omv-rpc "Iptables" "setRules" "$rules_v4" > /dev/null
/usr/sbin/omv-rpc "Iptables" "setRules6" "$rules_v6" > /dev/null

echo "[+] Triggering OMV to generate and apply rules..."
/usr/sbin/omv-salt deploy run iptables

echo "DONE! Check the OMV Web UI."
