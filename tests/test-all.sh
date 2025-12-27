#!/bin/bash
# =============================================================================
# Pi Guard - Comprehensive Test Suite
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

test_result() {
    if [ $1 -eq 0 ]; then
        echo -e "  ${GREEN}✓${NC} $2"
        ((PASS++))
    else
        echo -e "  ${RED}✗${NC} $2"
        ((FAIL++))
    fi
}

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}           Pi Guard Comprehensive Test Suite           ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# =============================================================================
# DNS Tests
# =============================================================================
echo -e "${CYAN}DNS Tests:${NC}"

# Local resolution
dig @127.0.0.1 google.com +short +time=5 > /dev/null 2>&1
test_result $? "Local DNS resolution"

# Unbound DoT
dig @127.0.0.1 -p 5335 cloudflare.com +short +time=5 > /dev/null 2>&1
test_result $? "Unbound DNS-over-TLS"

# Ad blocking
BLOCK=$(dig @127.0.0.1 ads.google.com +short 2>/dev/null)
[ "$BLOCK" = "0.0.0.0" ] || [ -z "$BLOCK" ]
test_result $? "Ad domain blocking"

# DNSSEC (should fail for bad domains)
dig @127.0.0.1 -p 5335 dnssec-failed.org +time=5 2>/dev/null | grep -q "SERVFAIL"
test_result $? "DNSSEC validation"

# =============================================================================
# Firewall Tests
# =============================================================================
echo ""
echo -e "${CYAN}Firewall Tests:${NC}"

# Default policy
iptables -L INPUT -n 2>/dev/null | grep -q "policy DROP"
test_result $? "Default DROP policy"

# SSH rate limiting
iptables -L INPUT -n 2>/dev/null | grep -q "recent"
test_result $? "SSH rate limiting"

# Logging enabled
iptables -L INPUT -n 2>/dev/null | grep -q "LOG"
test_result $? "Dropped packet logging"

# =============================================================================
# Service Tests
# =============================================================================
echo ""
echo -e "${CYAN}Service Tests:${NC}"

systemctl is-active --quiet pihole-FTL
test_result $? "Pi-hole FTL"

systemctl is-active --quiet unbound
test_result $? "Unbound"

systemctl is-active --quiet fail2ban
test_result $? "fail2ban"

systemctl is-active --quiet auditd
test_result $? "auditd"

if systemctl list-unit-files | grep -q "^arpwatch"; then
    systemctl is-active --quiet arpwatch
    test_result $? "arpwatch"
fi

if systemctl list-unit-files | grep -q "^snort"; then
    systemctl is-active --quiet snort
    test_result $? "Snort IDS"
fi

# =============================================================================
# Security Tests
# =============================================================================
echo ""
echo -e "${CYAN}Security Tests:${NC}"

# SSH root disabled
grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null
test_result $? "SSH root login disabled"

# fail2ban SSH jail
fail2ban-client status sshd > /dev/null 2>&1
test_result $? "fail2ban SSH jail active"

# zram enabled
swapon --show 2>/dev/null | grep -q zram
test_result $? "zram memory compression"

# Audit rules loaded
auditctl -l 2>/dev/null | grep -q "pihole"
test_result $? "Pi Guard audit rules"

# =============================================================================
# Alert Tests
# =============================================================================
echo ""
echo -e "${CYAN}Alert Configuration:${NC}"

[ -f ~/.config/pi-guard/telegram.conf ] || [ -f /home/pi/.config/pi-guard/telegram.conf ]
test_result $? "Telegram configured"

[ -f ~/.config/pi-guard/discord.conf ] || [ -f /home/pi/.config/pi-guard/discord.conf ]
if [ $? -eq 0 ]; then
    test_result 0 "Discord configured"
else
    echo -e "  ${YELLOW}○${NC} Discord not configured (optional)"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
TOTAL=$((PASS + FAIL))
if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}All $PASS tests passed!${NC}"
else
    echo -e "  ${YELLOW}$PASS passed, $FAIL failed${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
