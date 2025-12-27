#!/bin/bash
# =============================================================================
# Pi Guard - System Verification
# Checks all components are running correctly
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                 Pi Guard System Verification                 ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

check_service() {
    local name=$1
    local service=$2
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $name"
        ((PASS++))
        return 0
    elif systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
        echo -e "  ${RED}✗${NC} $name (installed but not running)"
        ((FAIL++))
        return 1
    else
        echo -e "  ${YELLOW}○${NC} $name (not installed)"
        ((WARN++))
        return 2
    fi
}

check_command() {
    local name=$1
    local cmd=$2
    
    if eval "$cmd" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} $name"
        ((PASS++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $name"
        ((FAIL++))
        return 1
    fi
}

# =============================================================================
# System Services
# =============================================================================
echo -e "${CYAN}System Services:${NC}"
check_service "Pi-hole FTL" "pihole-FTL"
check_service "Lighttpd (Web)" "lighttpd"
check_service "Unbound (DNS-over-TLS)" "unbound"
check_service "fail2ban" "fail2ban"
check_service "auditd" "auditd"
check_service "SSH daemon" "sshd"
check_service "arpwatch" "arpwatch"
check_service "Snort IDS" "snort"

# =============================================================================
# Network Tests
# =============================================================================
echo ""
echo -e "${CYAN}Network Tests:${NC}"
check_command "Local DNS resolution" "dig @127.0.0.1 google.com +short +time=5"
check_command "Unbound DNS-over-TLS" "dig @127.0.0.1 -p 5335 cloudflare.com +short +time=5"

# Test ad blocking
BLOCK_TEST=$(dig @127.0.0.1 ads.google.com +short 2>/dev/null)
if [ "$BLOCK_TEST" = "0.0.0.0" ] || [ -z "$BLOCK_TEST" ]; then
    echo -e "  ${GREEN}✓${NC} Ad blocking active"
    ((PASS++))
else
    echo -e "  ${YELLOW}○${NC} Ad blocking (may take time to activate)"
    ((WARN++))
fi

# =============================================================================
# Security Checks
# =============================================================================
echo ""
echo -e "${CYAN}Security Checks:${NC}"

# Firewall
if iptables -L -n 2>/dev/null | grep -q "DROP"; then
    echo -e "  ${GREEN}✓${NC} Firewall active (deny-by-default)"
    ((PASS++))
else
    echo -e "  ${RED}✗${NC} Firewall rules missing"
    ((FAIL++))
fi

# fail2ban SSH jail
if fail2ban-client status sshd &>/dev/null; then
    BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
    echo -e "  ${GREEN}✓${NC} fail2ban SSH jail (banned: $BANNED)"
    ((PASS++))
else
    echo -e "  ${RED}✗${NC} fail2ban SSH jail not active"
    ((FAIL++))
fi

# SSH hardening
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} SSH root login disabled"
    ((PASS++))
else
    echo -e "  ${YELLOW}○${NC} SSH root login enabled (consider disabling)"
    ((WARN++))
fi

# Password auth check
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    echo -e "  ${GREEN}✓${NC} SSH password auth disabled (key-only)"
    ((PASS++))
else
    echo -e "  ${YELLOW}○${NC} SSH password auth enabled (run harden-ssh.sh after key setup)"
    ((WARN++))
fi

# zram
if swapon --show 2>/dev/null | grep -q zram; then
    echo -e "  ${GREEN}✓${NC} zram memory compression active"
    ((PASS++))
else
    echo -e "  ${YELLOW}○${NC} zram not active"
    ((WARN++))
fi

# =============================================================================
# Configuration Files
# =============================================================================
echo ""
echo -e "${CYAN}Configuration Files:${NC}"
check_command "Pi-hole config" "test -f /etc/pihole/setupVars.conf"
check_command "Unbound config" "test -f /etc/unbound/unbound.conf.d/pi-hole.conf"
check_command "fail2ban config" "test -f /etc/fail2ban/jail.local"
check_command "Audit rules" "test -f /etc/audit/rules.d/pi-guard.rules"

# =============================================================================
# System Resources
# =============================================================================
echo ""
echo -e "${CYAN}System Resources:${NC}"
MEMORY=$(free -m | awk 'NR==2{printf "  %dMB / %dMB (%.0f%%)", $3, $2, $3*100/$2}')
DISK=$(df -h / | awk 'NR==2{printf "  %s / %s (%s)", $3, $2, $5}')
SWAP=$(free -m | awk 'NR==3{printf "  %dMB / %dMB", $3, $2}')
echo -e "  Memory:$MEMORY"
echo -e "  Disk:  $DISK"
echo -e "  Swap:  $SWAP"

# =============================================================================
# Web Interfaces
# =============================================================================
PI_IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${CYAN}Web Interfaces:${NC}"
echo -e "  Pi-hole:  ${GREEN}http://$PI_IP/admin${NC}"

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL + WARN))
if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}All checks passed!${NC} ($PASS passed, $WARN warnings)"
else
    echo -e "  ${YELLOW}$PASS passed, $FAIL failed, $WARN warnings${NC}"
    echo ""
    echo "  To investigate failures:"
    echo "    sudo systemctl status <service-name>"
    echo "    sudo journalctl -u <service-name> -n 50"
fi
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""
