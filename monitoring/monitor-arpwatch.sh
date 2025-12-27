#!/bin/bash
# =============================================================================
# Pi Guard - ARP Watch Monitor
#
# Detects:
#   - New devices on network
#   - MAC address changes (potential MITM)
#   - ARP spoofing attempts
# =============================================================================

ARPWATCH_LOG="/var/log/syslog"
STATE_FILE="/var/log/pi-guard/arpwatch-last-check"
LOG_FILE="/var/log/pi-guard/arpwatch-monitor.log"

mkdir -p /var/log/pi-guard

TELEGRAM="/usr/local/bin/alerts/send-telegram.sh"
DISCORD="/usr/local/bin/alerts/send-discord.sh"

# Check if arpwatch is running
if ! systemctl is-active --quiet arpwatch 2>/dev/null; then
    exit 0
fi

# Get last check time
if [ -f "$STATE_FILE" ]; then
    LAST_CHECK=$(cat "$STATE_FILE")
else
    LAST_CHECK=$(date -d '5 minutes ago' '+%b %d %H:%M')
fi

# Save current time for next run
date '+%b %d %H:%M' > "$STATE_FILE"

# Look for arpwatch events since last check
EVENTS=$(grep "arpwatch:" "$ARPWATCH_LOG" 2>/dev/null | tail -50)

if [ -z "$EVENTS" ]; then
    exit 0
fi

# Check for concerning events
NEW_STATIONS=$(echo "$EVENTS" | grep -c "new station" || echo "0")
FLIP_FLOPS=$(echo "$EVENTS" | grep -c "flip flop" || echo "0")
CHANGED=$(echo "$EVENTS" | grep -c "changed ethernet address" || echo "0")

# Log
echo "[$(date)] ARP events: new=$NEW_STATIONS, flip-flop=$FLIP_FLOPS, changed=$CHANGED" >> "$LOG_FILE"

# Alert on suspicious activity
if [ "$FLIP_FLOPS" -gt 0 ] || [ "$CHANGED" -gt 0 ]; then
    # This is suspicious - could be ARP spoofing
    SUSPICIOUS_EVENTS=$(echo "$EVENTS" | grep -E "(flip flop|changed ethernet)" | tail -5)
    
    MESSAGE="🚨 POSSIBLE ARP SPOOFING DETECTED!

Flip-flops: $FLIP_FLOPS
MAC changes: $CHANGED

This could indicate:
- ARP spoofing attack (MITM)
- Network misconfiguration
- Device with changing MAC

Recent events:
$SUSPICIOUS_EVENTS

Action: Check your network for unauthorized devices."

    [ -f "$TELEGRAM" ] && bash "$TELEGRAM" "$MESSAGE"
    [ -f "$DISCORD" ] && bash "$DISCORD" "$MESSAGE"
    
    echo "[$(date)] ALERT SENT - ARP spoofing suspected" >> "$LOG_FILE"
    
elif [ "$NEW_STATIONS" -gt 0 ]; then
    # New device - informational
    NEW_DEVICES=$(echo "$EVENTS" | grep "new station" | tail -3)
    
    MESSAGE="📱 New device(s) detected on network

New devices: $NEW_STATIONS

$NEW_DEVICES

This is usually normal (phone, laptop, etc.)
Check if unexpected: http://$(hostname -I | awk '{print $1}')/admin"

    # Only alert for new devices via Telegram (less urgent)
    [ -f "$TELEGRAM" ] && bash "$TELEGRAM" "$MESSAGE"
    
    echo "[$(date)] New devices detected: $NEW_STATIONS" >> "$LOG_FILE"
fi
