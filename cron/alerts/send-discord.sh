#!/bin/bash
# =============================================================================
# Pi Guard - Discord Alert (with Retry Logic)
# =============================================================================

CONFIG_FILE="${HOME}/.config/pi-guard/discord.conf"
FALLBACK_CONFIG="/home/pi/.config/pi-guard/discord.conf"
LOG_FILE="/var/log/pi-guard/alerts.log"
QUEUE_FILE="/var/log/pi-guard/discord-queue.txt"

MAX_RETRIES=3
RETRY_DELAY=5

# Load config
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
elif [ -f "$FALLBACK_CONFIG" ]; then
    source "$FALLBACK_CONFIG"
else
    echo "[$(date)] ERROR: Discord config not found" >> "$LOG_FILE"
    exit 1
fi

if [ -z "$WEBHOOK_URL" ]; then
    echo "[$(date)] ERROR: WEBHOOK_URL not set" >> "$LOG_FILE"
    exit 1
fi

# Get message
if [ -n "$1" ]; then
    MESSAGE="$1"
else
    MESSAGE=$(cat)
fi

[ -z "$MESSAGE" ] && exit 0

# Add timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
MESSAGE="**[$TIMESTAMP]** $MESSAGE"

# Escape for JSON
MESSAGE=$(echo "$MESSAGE" | sed 's/"/\\"/g' | sed ':a;N;$!ba;s/\n/\\n/g')

# Build payload
PAYLOAD="{\"username\":\"Pi Guard\",\"content\":\"${MESSAGE}\"}"

# Send with retry
send_message() {
    local attempt=1
    local delay=$RETRY_DELAY
    
    while [ $attempt -le $MAX_RETRIES ]; do
        RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
            --max-time 10 \
            -X POST \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD" \
            "$WEBHOOK_URL" 2>&1)
        
        if [ "$RESPONSE" = "204" ] || [ "$RESPONSE" = "200" ]; then
            echo "[$(date)] SUCCESS: Discord message sent (attempt $attempt)" >> "$LOG_FILE"
            return 0
        fi
        
        echo "[$(date)] RETRY $attempt/$MAX_RETRIES: HTTP $RESPONSE" >> "$LOG_FILE"
        
        [ $attempt -lt $MAX_RETRIES ] && sleep $delay && delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
    
    return 1
}

if send_message; then
    echo "✓ Discord alert sent"
else
    echo "[$(date)] $MESSAGE" >> "$QUEUE_FILE"
    echo "✗ Failed - queued for retry"
    exit 1
fi
