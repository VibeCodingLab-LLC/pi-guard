#!/bin/bash
# =============================================================================
# Pi Guard - Pi-hole Test
# Tests that Pi-hole is correctly blocking ads
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo "Testing Pi-hole..."
echo ""

# Test 1: Service running
echo -n "1. Pi-hole service: "
if systemctl is-active --quiet pihole-FTL; then
    echo -e "${GREEN}RUNNING${NC}"
else
    echo -e "${RED}NOT RUNNING${NC}"
    exit 1
fi

# Test 2: DNS resolution works
echo -n "2. DNS resolution: "
if dig @127.0.0.1 google.com +short > /dev/null 2>&1; then
    echo -e "${GREEN}WORKING${NC}"
else
    echo -e "${RED}FAILED${NC}"
fi

# Test 3: Ad domain blocked
echo -n "3. Ad blocking: "
RESULT=$(dig @127.0.0.1 ads.google.com +short 2>/dev/null)
if [ "$RESULT" = "0.0.0.0" ] || [ "$RESULT" = "127.0.0.1" ] || [ -z "$RESULT" ]; then
    echo -e "${GREEN}BLOCKING${NC}"
else
    echo -e "${RED}NOT BLOCKING ($RESULT)${NC}"
fi

# Test 4: Web interface
echo -n "4. Web interface: "
if curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1/admin | grep -q "200\|301\|302"; then
    echo -e "${GREEN}ACCESSIBLE${NC}"
else
    echo -e "${RED}NOT ACCESSIBLE${NC}"
fi

# Test 5: Stats
echo ""
echo "Statistics:"
pihole -c -e 2>/dev/null | head -5

echo ""
echo "Pi-hole test complete!"
