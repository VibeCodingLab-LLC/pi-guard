#!/bin/bash
# =============================================================================
# Pi Guard - Alert System Test
# Tests all configured alert channels
# =============================================================================

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}            Pi Guard Alert System Test                 ${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# =============================================================================
# Check Configurations
# =============================================================================
echo -e "${CYAN}Configuration Status:${NC}"

CONFIG_DIR="${HOME}/.config/pi-guard"
if [ ! -d "$CONFIG_DIR" ]; then
    CONFIG_DIR="/home/pi/.config/pi-guard"
fi

# Telegram
if [ -f "$CONFIG_DIR/telegram.conf" ]; then
    source "$CONFIG_DIR/telegram.conf"
    if [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
        echo -e "  ${GREEN}✓${NC} Telegram configured"
        TELEGRAM_OK=true
    else
        echo -e "  ${YELLOW}○${NC} Telegram config incomplete"
        TELEGRAM_OK=false
    fi
else
    echo -e "  ${YELLOW}○${NC} Telegram not configured"
    TELEGRAM_OK=false
fi

# Discord
if [ -f "$CONFIG_DIR/discord.conf" ]; then
    source "$CONFIG_DIR/discord.conf"
    if [ -n "$WEBHOOK_URL" ]; then
        echo -e "  ${GREEN}✓${NC} Discord configured"
        DISCORD_OK=true
    else
        echo -e "  ${YELLOW}○${NC} Discord config incomplete"
        DISCORD_OK=false
    fi
else
    echo -e "  ${YELLOW}○${NC} Discord not configured"
    DISCORD_OK=false
fi

# Email
if [ -f "$CONFIG_DIR/email.conf" ]; then
    source "$CONFIG_DIR/email.conf"
    if [ -n "$EMAIL_FROM" ] && [ -n "$EMAIL_TO" ] && [ -n "$EMAIL_PASSWORD" ]; then
        echo -e "  ${GREEN}✓${NC} Email configured"
        EMAIL_OK=true
    else
        echo -e "  ${YELLOW}○${NC} Email config incomplete"
        EMAIL_OK=false
    fi
else
    echo -e "  ${YELLOW}○${NC} Email not configured"
    EMAIL_OK=false
fi

# =============================================================================
# Test Alerts
# =============================================================================
echo ""
echo -e "${CYAN}Send Test Alerts?${NC}"
echo "This will send a test message to all configured channels."
echo ""
read -p "Proceed? [y/N] " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

TEST_MSG="🧪 Pi Guard Test Alert

This is a test message from Pi Guard.
Time: $(date)
Host: $(hostname)
IP: $(hostname -I | awk '{print $1}')

If you received this, alerts are working!"

echo ""
echo -e "${CYAN}Sending Test Alerts:${NC}"

# Test Telegram
if [ "$TELEGRAM_OK" = true ]; then
    echo -n "  Telegram... "
    if bash "$SCRIPT_DIR/cron/alerts/send-telegram.sh" "$TEST_MSG" 2>/dev/null; then
        echo -e "${GREEN}sent${NC}"
    else
        echo -e "${RED}failed${NC}"
    fi
else
    echo -e "  Telegram... ${YELLOW}skipped${NC}"
fi

# Test Discord
if [ "$DISCORD_OK" = true ]; then
    echo -n "  Discord... "
    if bash "$SCRIPT_DIR/cron/alerts/send-discord.sh" "$TEST_MSG" 2>/dev/null; then
        echo -e "${GREEN}sent${NC}"
    else
        echo -e "${RED}failed${NC}"
    fi
else
    echo -e "  Discord... ${YELLOW}skipped${NC}"
fi

# Test Email
if [ "$EMAIL_OK" = true ]; then
    echo -n "  Email... "
    if bash "$SCRIPT_DIR/cron/alerts/send-email.sh" "Pi Guard Test Alert" "$TEST_MSG" 2>/dev/null; then
        echo -e "${GREEN}sent${NC}"
    else
        echo -e "${RED}failed${NC}"
    fi
else
    echo -e "  Email... ${YELLOW}skipped${NC}"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo "  Check your phone/email for test messages!"
echo ""
echo "  If alerts didn't arrive:"
echo "    1. Check config files in $CONFIG_DIR"
echo "    2. Run alert script with -x for debug:"
echo "       bash -x $SCRIPT_DIR/cron/alerts/send-telegram.sh 'test'"
echo "    3. Check logs: /var/log/pi-guard/alerts.log"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""
