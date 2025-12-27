#!/bin/bash
# =============================================================================
# Pi Guard - fail2ban Monitor
#
# Features:
#   - Tracks new bans since last check
#   - Logs banned IPs for forensics
#   - Provides context (total bans, jail status)
# =============================================================================

STATE_FILE="/var/log/pi-guard/fail2ban-last-count"
LOG_FILE="/var/log/pi-guard/fail2ban-monitor.log"
BANNED_LOG="/var/log/pi-guard/banned-ips.log"

mkdir -p /var/log/pi-guard

TELEGRAM="/usr/local/bin/alerts/send-telegram.sh"
DISCORD="/usr/local/bin/alerts/send-discord.sh"

# Check fail2ban is running
if ! systemctl is-active --quiet fail2ban; then
    echo "[$(date)] fail2ban not running" >> "$LOG_FILE"
    exit 0
fi

# Get current stats
STATUS=$(fail2ban-client status sshd 2>/dev/null)
CURRENTLY_BANNED=$(echo "$STATUS" | grep "Currently banned" | awk '{print $NF}')
TOTAL_BANNED=$(echo "$STATUS" | grep "Total banned" | awk '{print $NF}')
BANNED_IPS=$(echo "$STATUS" | grep "Banned IP" | cut -d: -f2 | tr -d ' ')

# Default values
CURRENTLY_BANNED=${CURRENTLY_BANNED:-0}
TOTAL_BANNED=${TOTAL_BANNED:-0}

# Get last count
if [ -f "$STATE_FILE" ]; then
    LAST_TOTAL=$(cat "$STATE_FILE")
else
    LAST_TOTAL=0
    echo "$TOTAL_BANNED" > "$STATE_FILE"
    echo "[$(date)] Initial state: $TOTAL_BANNED total bans" >> "$LOG_FILE"
    exit 0
fi

# Check for new bans
if [ "$TOTAL_BANNED" -gt "$LAST_TOTAL" ]; then
    NEW_BANS=$((TOTAL_BANNED - LAST_TOTAL))
    
    # Log for forensics
    echo "[$(date)] NEW BANS: $NEW_BANS" >> "$LOG_FILE"
    echo "[$(date)] Currently banned: $CURRENTLY_BANNED" >> "$LOG_FILE"
    echo "[$(date)] Banned IPs: $BANNED_IPS" >> "$LOG_FILE"
    
    # Log banned IPs with timestamp
    for IP in $BANNED_IPS; do
        echo "[$(date)] $IP" >> "$BANNED_LOG"
    done
    
    # Send alert
    MESSAGE="🚫 SSH Attack Blocked!

New bans: $NEW_BANS
Currently banned: $CURRENTLY_BANNED IPs
Total banned: $TOTAL_BANNED

Banned IPs:
$(echo "$BANNED_IPS" | tr ' ' '\n' | head -5)

View all: sudo fail2ban-client status sshd"

    [ -f "$TELEGRAM" ] && bash "$TELEGRAM" "$MESSAGE"
    [ -f "$DISCORD" ] && bash "$DISCORD" "$MESSAGE"
fi

# Update state
echo "$TOTAL_BANNED" > "$STATE_FILE"

# Log current status
echo "[$(date)] Status: banned=$CURRENTLY_BANNED, total=$TOTAL_BANNED" >> "$LOG_FILE"
