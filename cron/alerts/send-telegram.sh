#!/bin/bash
# =============================================================================
# Pi Guard - Telegram Alert (with Retry Logic)
# 
# Features:
#   - Automatic retry on failure (3 attempts)
#   - Exponential backoff
#   - Queues failed messages
#   - Logs all attempts for forensics
# =============================================================================

CONFIG_FILE="${HOME}/.config/pi-guard/telegram.conf"
FALLBACK_CONFIG="/home/pi/.config/pi-guard/telegram.conf"
LOG_FILE="/var/log/pi-guard/alerts.log"
QUEUE_FILE="/var/log/pi-guard/telegram-queue.txt"

# Retry settings
MAX_RETRIES=3
RETRY_DELAY=5

# Load config
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
elif [ -f "$FALLBACK_CONFIG" ]; then
    source "$FALLBACK_CONFIG"
else
    echo "[$(date)] ERROR: Telegram config not found" >> "$LOG_FILE"
    exit 1
fi

if [ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ]; then
    echo "[$(date)] ERROR: BOT_TOKEN or CHAT_ID not set" >> "$LOG_FILE"
    exit 1
fi

# Get message
if [ -n "$1" ]; then
    MESSAGE="$1"
else
    MESSAGE=$(cat)
fi

if [ -z "$MESSAGE" ]; then
    exit 0
fi

# Add timestamp to message
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
MESSAGE="[$TIMESTAMP] $MESSAGE"

# Send with retry
send_message() {
    local attempt=1
    local delay=$RETRY_DELAY
    
    while [ $attempt -le $MAX_RETRIES ]; do
        RESPONSE=$(curl -s -X POST \
            --max-time 10 \
            "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
            -d "chat_id=${CHAT_ID}" \
            -d "text=${MESSAGE}" \
            -d "parse_mode=HTML" \
            2>&1)
        
        if echo "$RESPONSE" | grep -q '"ok":true'; then
            echo "[$(date)] SUCCESS: Message sent (attempt $attempt)" >> "$LOG_FILE"
            return 0
        fi
        
        echo "[$(date)] RETRY $attempt/$MAX_RETRIES: $RESPONSE" >> "$LOG_FILE"
        
        if [ $attempt -lt $MAX_RETRIES ]; then
            sleep $delay
            delay=$((delay * 2))  # Exponential backoff
        fi
        
        attempt=$((attempt + 1))
    done
    
    return 1
}

# Attempt to send
if send_message; then
    echo "✓ Telegram alert sent"
else
    # Queue for later retry
    echo "[$(date)] $MESSAGE" >> "$QUEUE_FILE"
    echo "[$(date)] FAILED: Queued for retry" >> "$LOG_FILE"
    echo "✗ Failed - queued for retry"
    exit 1
fi
