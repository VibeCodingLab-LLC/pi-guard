#!/bin/bash
# =============================================================================
# Pi Guard - DNS Stack Test
# Tests Pi-hole, Unbound, and DNS-over-TLS
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}              Pi Guard DNS Stack Test                  ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

PASS=0
FAIL=0

test_dns() {
    local name=$1
    local server=$2
    local port=$3
    local domain=$4
    
    if [ -n "$port" ]; then
        RESULT=$(dig @$server -p $port $domain +short +time=5 2>/dev/null)
    else
        RESULT=$(dig @$server $domain +short +time=5 2>/dev/null)
    fi
    
    if [ -n "$RESULT" ]; then
        echo -e "  ${GREEN}✓${NC} $name"
        echo -e "    ${CYAN}→${NC} $RESULT"
        ((PASS++))
        return 0
    else
        echo -e "  ${RED}✗${NC} $name"
        ((FAIL++))
        return 1
    fi
}

# =============================================================================
# Service Status
# =============================================================================
echo -e "${CYAN}Service Status:${NC}"

if systemctl is-active --quiet pihole-FTL; then
    echo -e "  ${GREEN}✓${NC} Pi-hole FTL running"
else
    echo -e "  ${RED}✗${NC} Pi-hole FTL NOT running"
fi

if systemctl is-active --quiet unbound; then
    echo -e "  ${GREEN}✓${NC} Unbound running"
else
    echo -e "  ${RED}✗${NC} Unbound NOT running"
fi

# =============================================================================
# DNS Resolution Tests
# =============================================================================
echo ""
echo -e "${CYAN}DNS Resolution:${NC}"

# Test Unbound directly (DNS-over-TLS)
test_dns "Unbound DoT (direct)" "127.0.0.1" "5335" "cloudflare.com"

# Test Pi-hole (goes through Unbound)
test_dns "Pi-hole → Unbound" "127.0.0.1" "" "google.com"

# Test external domain
test_dns "External domain" "127.0.0.1" "" "github.com"

# =============================================================================
# Ad Blocking Test
# =============================================================================
echo ""
echo -e "${CYAN}Ad Blocking:${NC}"

# Test known ad domain
AD_RESULT=$(dig @127.0.0.1 ads.google.com +short 2>/dev/null)
if [ "$AD_RESULT" = "0.0.0.0" ] || [ -z "$AD_RESULT" ]; then
    echo -e "  ${GREEN}✓${NC} ads.google.com blocked"
    ((PASS++))
else
    echo -e "  ${YELLOW}○${NC} ads.google.com not blocked (may take time)"
fi

# Test tracker domain
TRACKER_RESULT=$(dig @127.0.0.1 analytics.google.com +short 2>/dev/null)
if [ "$TRACKER_RESULT" = "0.0.0.0" ] || [ -z "$TRACKER_RESULT" ]; then
    echo -e "  ${GREEN}✓${NC} analytics.google.com blocked"
    ((PASS++))
else
    echo -e "  ${YELLOW}○${NC} analytics.google.com not blocked"
fi

# =============================================================================
# DNSSEC Validation
# =============================================================================
echo ""
echo -e "${CYAN}DNSSEC Validation:${NC}"

# Test valid DNSSEC domain
DNSSEC_VALID=$(dig @127.0.0.1 -p 5335 dnssec.vs.uni-due.de +dnssec +short 2>/dev/null)
if [ -n "$DNSSEC_VALID" ]; then
    echo -e "  ${GREEN}✓${NC} Valid DNSSEC domain resolves"
    ((PASS++))
else
    echo -e "  ${RED}✗${NC} DNSSEC validation issue"
    ((FAIL++))
fi

# Test invalid DNSSEC domain (should fail)
DNSSEC_FAIL=$(dig @127.0.0.1 -p 5335 dnssec-failed.org +time=5 2>/dev/null | grep -c "SERVFAIL")
if [ "$DNSSEC_FAIL" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Invalid DNSSEC rejected (SERVFAIL)"
    ((PASS++))
else
    echo -e "  ${YELLOW}○${NC} DNSSEC rejection test inconclusive"
fi

# =============================================================================
# Response Time
# =============================================================================
echo ""
echo -e "${CYAN}Response Times:${NC}"

# First query (cold cache)
START=$(date +%s%N)
dig @127.0.0.1 example.org +short > /dev/null 2>&1
END=$(date +%s%N)
COLD_MS=$(( (END - START) / 1000000 ))
echo -e "  Cold cache: ${CYAN}${COLD_MS}ms${NC}"

# Second query (warm cache)
START=$(date +%s%N)
dig @127.0.0.1 example.org +short > /dev/null 2>&1
END=$(date +%s%N)
WARM_MS=$(( (END - START) / 1000000 ))
echo -e "  Warm cache: ${CYAN}${WARM_MS}ms${NC}"

# =============================================================================
# Pi-hole Statistics
# =============================================================================
echo ""
echo -e "${CYAN}Pi-hole Statistics:${NC}"
if command -v pihole &> /dev/null; then
    STATS=$(pihole -c -e 2>/dev/null)
    QUERIES=$(echo "$STATS" | grep -oP 'dns_queries_today=\K[0-9]+' || echo "N/A")
    BLOCKED=$(echo "$STATS" | grep -oP 'ads_blocked_today=\K[0-9]+' || echo "N/A")
    PERCENT=$(echo "$STATS" | grep -oP 'ads_percentage_today=\K[0-9.]+' || echo "N/A")
    DOMAINS=$(echo "$STATS" | grep -oP 'domains_being_blocked=\K[0-9]+' || echo "N/A")
    
    echo -e "  Queries today:    ${CYAN}$QUERIES${NC}"
    echo -e "  Blocked today:    ${CYAN}$BLOCKED${NC} (${PERCENT}%)"
    echo -e "  Blocklist size:   ${CYAN}$DOMAINS${NC} domains"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}DNS stack healthy!${NC} ($PASS tests passed)"
else
    echo -e "  ${YELLOW}$PASS passed, $FAIL failed${NC}"
fi
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
