#!/bin/bash
# =============================================================================
# Pi Guard - Daily Security Report
#
# Features:
#   - System health summary
#   - Top 5 blocked domains (identify chatty malware)
#   - Attack statistics
#   - Snort IDS summary
#   - Memory/disk usage
# =============================================================================

LOG_FILE="/var/log/pi-guard/daily-report.log"
SNORT_DAILY="/var/log/pi-guard/snort-daily.txt"

mkdir -p /var/log/pi-guard

TELEGRAM="/usr/local/bin/alerts/send-telegram.sh"
DISCORD="/usr/local/bin/alerts/send-discord.sh"
EMAIL="/usr/local/bin/alerts/send-email.sh"

# Collect system info
PI_IP=$(hostname -I | awk '{print $1}')
UPTIME=$(uptime -p)
MEMORY=$(free -m | awk 'NR==2{printf "%.1f%% (%dMB/%dMB)", $3*100/$2, $3, $2}')
DISK=$(df -h / | awk 'NR==2{print $5 " (" $3 "/" $2 ")"}')
LOAD=$(cat /proc/loadavg | awk '{print $1, $2, $3}')

# Pi-hole stats
if command -v pihole &> /dev/null; then
    STATS=$(pihole -c -e 2>/dev/null)
    PIHOLE_QUERIES=$(echo "$STATS" | grep -oP 'dns_queries_today=\K[0-9]+' || echo "N/A")
    PIHOLE_BLOCKED=$(echo "$STATS" | grep -oP 'ads_blocked_today=\K[0-9]+' || echo "N/A")
    PIHOLE_PERCENT=$(echo "$STATS" | grep -oP 'ads_percentage_today=\K[0-9.]+' || echo "N/A")
    
    # Get top 5 blocked domains (helps identify chatty malware)
    TOP_BLOCKED=$(sqlite3 /etc/pihole/pihole-FTL.db \
        "SELECT domain, COUNT(*) as count FROM queries WHERE status IN (1,4,5,6,7,8,9,10,11) AND timestamp > strftime('%s', 'now', '-1 day') GROUP BY domain ORDER BY count DESC LIMIT 5;" 2>/dev/null | \
        awk -F'|' '{printf "  %s: %s hits\n", $1, $2}')
    
    if [ -z "$TOP_BLOCKED" ]; then
        TOP_BLOCKED="  (Unable to query database)"
    fi
else
    PIHOLE_QUERIES="N/A"
    PIHOLE_BLOCKED="N/A"
    PIHOLE_PERCENT="N/A"
    TOP_BLOCKED="  (Pi-hole not installed)"
fi

# fail2ban stats
if command -v fail2ban-client &> /dev/null; then
    F2B_STATUS=$(fail2ban-client status sshd 2>/dev/null)
    F2B_BANNED=$(echo "$F2B_STATUS" | grep "Currently banned" | awk '{print $NF}' || echo "0")
    F2B_TOTAL=$(echo "$F2B_STATUS" | grep "Total banned" | awk '{print $NF}' || echo "0")
else
    F2B_BANNED="N/A"
    F2B_TOTAL="N/A"
fi

# Snort stats (if running)
if systemctl is-active --quiet snort 2>/dev/null; then
    SNORT_STATUS="Running"
    if [ -f /var/log/snort/alert ]; then
        SNORT_TOTAL=$(grep -c "Priority:" /var/log/snort/alert 2>/dev/null || echo "0")
        SNORT_HIGH=$(grep -c "Priority: 1" /var/log/snort/alert 2>/dev/null || echo "0")
        SNORT_MED=$(grep -c "Priority: 2" /var/log/snort/alert 2>/dev/null || echo "0")
    else
        SNORT_TOTAL="0"
        SNORT_HIGH="0"
        SNORT_MED="0"
    fi
else
    SNORT_STATUS="Not running"
    SNORT_TOTAL="N/A"
    SNORT_HIGH="N/A"
    SNORT_MED="N/A"
fi

# arpwatch stats
if systemctl is-active --quiet arpwatch 2>/dev/null; then
    ARP_STATUS="Running"
    ARP_NEW=$(grep -c "new station" /var/log/syslog 2>/dev/null || echo "0")
else
    ARP_STATUS="Not running"
    ARP_NEW="N/A"
fi

# Service status
SERVICES=""
for svc in pihole-FTL unbound fail2ban auditd arpwatch snort; do
    if systemctl is-active --quiet $svc 2>/dev/null; then
        SERVICES="${SERVICES}✅ $svc\n"
    elif systemctl list-unit-files | grep -q "^$svc"; then
        SERVICES="${SERVICES}❌ $svc\n"
    fi
done

# Build report
REPORT="📊 Pi Guard Daily Security Report
════════════════════════════════════

🖥️ SYSTEM HEALTH
• Uptime: $UPTIME
• Memory: $MEMORY
• Disk: $DISK
• Load: $LOAD
• IP: $PI_IP

🛡️ DNS FILTERING (Pi-hole)
• Queries today: $PIHOLE_QUERIES
• Blocked: $PIHOLE_BLOCKED ($PIHOLE_PERCENT%)

🔝 TOP BLOCKED DOMAINS
$TOP_BLOCKED

🚫 SSH PROTECTION (fail2ban)
• Currently banned: $F2B_BANNED IPs
• Total banned: $F2B_TOTAL

🔍 INTRUSION DETECTION (Snort)
• Status: $SNORT_STATUS
• High priority: $SNORT_HIGH
• Medium priority: $SNORT_MED
• Total alerts: $SNORT_TOTAL

📡 NETWORK MONITORING (arpwatch)
• Status: $ARP_STATUS
• New devices today: $ARP_NEW

⚙️ SERVICES
$(echo -e "$SERVICES")
════════════════════════════════════
Dashboard: http://$PI_IP/admin"

# Send report
[ -f "$TELEGRAM" ] && bash "$TELEGRAM" "$REPORT"
[ -f "$DISCORD" ] && bash "$DISCORD" "$REPORT"
[ -f "$EMAIL" ] && bash "$EMAIL" "Pi Guard Daily Report - $(date '+%Y-%m-%d')" "$REPORT"

# Log
echo "[$(date)] Daily report sent" >> "$LOG_FILE"

# Rotate Snort daily alerts
if [ -f "$SNORT_DAILY" ]; then
    mv "$SNORT_DAILY" "${SNORT_DAILY}.$(date '+%Y%m%d')"
    find /var/log/pi-guard -name "snort-daily.txt.*" -mtime +7 -delete
fi
