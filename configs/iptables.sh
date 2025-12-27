#!/bin/bash
# =============================================================================
# Pi Guard - Firewall Rules (iptables)
# Deny-by-default with rate limiting
# =============================================================================

set -e

echo "Configuring Pi Guard firewall..."

# Flush existing rules
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X

# Default policies: DROP everything
iptables -P INPUT DROP
iptables -P FORWARD DROP
iptables -P OUTPUT ACCEPT

# =============================================================================
# Loopback
# =============================================================================
iptables -A INPUT -i lo -j ACCEPT
iptables -A OUTPUT -o lo -j ACCEPT

# =============================================================================
# Established Connections
# =============================================================================
iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# =============================================================================
# Drop Invalid Packets
# =============================================================================
iptables -A INPUT -m state --state INVALID -j DROP

# =============================================================================
# SSH (Port 22) - Rate limited
# =============================================================================
# Limit: 4 new connections per minute per IP
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --set --name SSH
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -m recent --update --seconds 60 --hitcount 4 --name SSH -j DROP
iptables -A INPUT -p tcp --dport 22 -m state --state NEW -j ACCEPT

# =============================================================================
# DNS (Port 53) - Local network only
# =============================================================================
iptables -A INPUT -p tcp --dport 53 -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 53 -s 172.16.0.0/12 -j ACCEPT
iptables -A INPUT -p udp --dport 53 -s 172.16.0.0/12 -j ACCEPT

# =============================================================================
# HTTP (Port 80) - Pi-hole Admin
# =============================================================================
iptables -A INPUT -p tcp --dport 80 -s 192.168.0.0/16 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -s 10.0.0.0/8 -j ACCEPT
iptables -A INPUT -p tcp --dport 80 -s 172.16.0.0/12 -j ACCEPT

# =============================================================================
# DHCP (if Pi is DHCP server - uncomment if needed)
# =============================================================================
# iptables -A INPUT -p udp --dport 67:68 --sport 67:68 -j ACCEPT

# =============================================================================
# ICMP (Ping) - Rate limited
# =============================================================================
iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s --limit-burst 4 -j ACCEPT

# =============================================================================
# Logging (dropped packets)
# =============================================================================
iptables -A INPUT -m limit --limit 5/min -j LOG --log-prefix "IPTables-Dropped: " --log-level 4

# =============================================================================
# Final DROP
# =============================================================================
iptables -A INPUT -j DROP

# =============================================================================
# IPv6 - Block all (unless you specifically need it)
# =============================================================================
if command -v ip6tables &> /dev/null; then
    ip6tables -P INPUT DROP
    ip6tables -P FORWARD DROP
    ip6tables -P OUTPUT DROP
    ip6tables -A INPUT -i lo -j ACCEPT
    ip6tables -A OUTPUT -o lo -j ACCEPT
fi

echo "Firewall configured successfully!"
echo ""
echo "Rules applied:"
iptables -L -n --line-numbers | head -30
