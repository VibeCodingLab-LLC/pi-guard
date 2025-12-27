#!/bin/bash
# =============================================================================
# Pi Guard - Pi-hole Monitor
#
# Features:
#   - Detects if Pi-hole goes down
#   - Auto-restarts on failure
#   - Alerts on unusual blocking rates
# =============================================================================

LOG_FILE="/var/log/pi-guard/pihole-monitor.log"
mkdir -p /var/log/pi-guard

TELEGRAM="/usr/local/bin/alerts/send-telegram.sh"
DISCORD="/usr/local/bin/alerts/send-discord.sh"

# Check if Pi-hole FTL is running
if ! systemctl is-active --quiet pihole-FTL; then
    echo "[$(date)] Pi-hole FTL DOWN - attempting restart" >> "$LOG_FILE"
    
    sudo systemctl restart pihole-FTL
    sleep 5
    
    if systemctl is-active --quiet pihole-FTL; then
        MESSAGE="⚠️ Pi-hole FTL was down - RESTARTED successfully"
        echo "[$(date)] Restart successful" >> "$LOG_FILE"
    else
        MESSAGE="❌ Pi-hole FTL DOWN - Restart FAILED! Manual intervention needed."
        echo "[$(date)] Restart FAILED" >> "$LOG_FILE"
    fi
    
    [ -f "$TELEGRAM" ] && bash "$TELEGRAM" "$MESSAGE"
    [ -f "$DISCORD" ] && bash "$DISCORD" "$MESSAGE"
    exit
fi

# Get stats
STATS=$(pihole -c -e 2>/dev/null)
if [ -z "$STATS" ]; then
    echo "[$(date)] Could not get Pi-hole stats" >> "$LOG_FILE"
    exit 0
fi

# Parse stats
QUERIES=$(echo "$STATS" | grep -oP 'dns_queries_today=\K[0-9]+' 2>/dev/null || echo "0")
BLOCKED=$(echo "$STATS" | grep -oP 'ads_blocked_today=\K[0-9]+' 2>/dev/null || echo "0")
PERCENT=$(echo "$STATS" | grep -oP 'ads_percentage_today=\K[0-9.]+' 2>/dev/null || echo "0")

echo "[$(date)] Stats: queries=$QUERIES, blocked=$BLOCKED ($PERCENT%)" >> "$LOG_FILE"

# Alert if blocking rate is unusually high (>60% might indicate misconfiguration)
if [ -n "$PERCENT" ]; then
    HIGH_THRESHOLD=60
    if [ "$(echo "$PERCENT > $HIGH_THRESHOLD" | bc -l 2>/dev/null)" = "1" ]; then
        MESSAGE="⚠️ Pi-hole blocking rate unusually high: ${PERCENT}%

This could indicate:
- Malware on a device
- Misconfigured blocklist
- Normal for high-ad sites

Queries: $QUERIES
Blocked: $BLOCKED

Check: http://$(hostname -I | awk '{print $1}')/admin"

        [ -f "$TELEGRAM" ] && bash "$TELEGRAM" "$MESSAGE"
        echo "[$(date)] HIGH BLOCKING RATE ALERT" >> "$LOG_FILE"
    fi
fi
