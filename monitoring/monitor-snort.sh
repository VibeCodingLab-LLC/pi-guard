#!/bin/bash
# =============================================================================
# Pi Guard - Snort IDS Monitor (Priority-Based Alerting)
#
# Features:
#   - Only sends immediate alerts for Priority 1 (High) events
#   - Priority 2/3 alerts go to daily report
#   - Handles log rotation gracefully
#   - Logs all activity for forensics
# =============================================================================

SNORT_LOG="/var/log/snort/alert"
STATE_FILE="/var/log/pi-guard/snort-last-line"
LOG_FILE="/var/log/pi-guard/snort-monitor.log"
DAILY_ALERTS="/var/log/pi-guard/snort-daily.txt"

mkdir -p /var/log/pi-guard

# Alert scripts
TELEGRAM="/usr/local/bin/alerts/send-telegram.sh"
DISCORD="/usr/local/bin/alerts/send-discord.sh"

# Check if Snort is running
if ! systemctl is-active --quiet snort 2>/dev/null; then
    exit 0
fi

# Check if alert file exists
if [ ! -f "$SNORT_LOG" ]; then
    exit 0
fi

# Get last processed line
if [ -f "$STATE_FILE" ]; then
    LAST_LINE=$(cat "$STATE_FILE")
else
    LAST_LINE=0
fi

# Get current line count
CURRENT_LINE=$(wc -l < "$SNORT_LOG" 2>/dev/null || echo "0")

# Handle log rotation (current < last means rotated)
if [ "$CURRENT_LINE" -lt "$LAST_LINE" ]; then
    echo "[$(date)] Log rotated. Resetting state." >> "$LOG_FILE"
    LAST_LINE=0
fi

# Check for new alerts
if [ "$CURRENT_LINE" -gt "$LAST_LINE" ]; then
    # Get new alerts
    NEW_ALERTS=$(tail -n +$((LAST_LINE + 1)) "$SNORT_LOG")
    
    # Count by priority
    TOTAL=$(echo "$NEW_ALERTS" | grep -c "Priority:" || echo "0")
    HIGH=$(echo "$NEW_ALERTS" | grep -c "Priority: 1" || echo "0")
    MEDIUM=$(echo "$NEW_ALERTS" | grep -c "Priority: 2" || echo "0")
    LOW=$(echo "$NEW_ALERTS" | grep -c "Priority: 3" || echo "0")
    
    if [ "$TOTAL" -gt 0 ]; then
        # Log for forensics
        echo "[$(date)] New alerts: Total=$TOTAL, High=$HIGH, Med=$MEDIUM, Low=$LOW" >> "$LOG_FILE"
        echo "$NEW_ALERTS" >> "$LOG_FILE"
        
        # Save for daily report
        echo "[$(date)]" >> "$DAILY_ALERTS"
        echo "$NEW_ALERTS" >> "$DAILY_ALERTS"
        echo "---" >> "$DAILY_ALERTS"
        
        # Only send immediate alert for HIGH PRIORITY events
        if [ "$HIGH" -gt 0 ]; then
            HIGH_ALERTS=$(echo "$NEW_ALERTS" | grep -A2 "Priority: 1" | head -10)
            
            MESSAGE="🚨 CRITICAL: High Priority Intrusion Detected!

High Priority: $HIGH
Total Alerts: $TOTAL

Sample:
$HIGH_ALERTS

Review: /var/log/snort/alert"

            # Send to all configured channels
            [ -f "$TELEGRAM" ] && bash "$TELEGRAM" "$MESSAGE"
            [ -f "$DISCORD" ] && bash "$DISCORD" "$MESSAGE"
            
            echo "[$(date)] CRITICAL ALERT SENT" >> "$LOG_FILE"
        fi
    fi
fi

# Update state
echo "$CURRENT_LINE" > "$STATE_FILE"
