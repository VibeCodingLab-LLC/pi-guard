#!/bin/bash
# =============================================================================
# Pi Guard - Retry Failed Alerts
# Processes queued messages that failed to send
# =============================================================================

LOG_FILE="/var/log/pi-guard/alerts.log"
TELEGRAM_QUEUE="/var/log/pi-guard/telegram-queue.txt"
DISCORD_QUEUE="/var/log/pi-guard/discord-queue.txt"

TELEGRAM="/usr/local/bin/alerts/send-telegram.sh"
DISCORD="/usr/local/bin/alerts/send-discord.sh"

# Process Telegram queue
if [ -f "$TELEGRAM_QUEUE" ] && [ -s "$TELEGRAM_QUEUE" ]; then
    echo "[$(date)] Processing Telegram queue..." >> "$LOG_FILE"
    
    # Read and clear queue atomically
    MESSAGES=$(cat "$TELEGRAM_QUEUE")
    > "$TELEGRAM_QUEUE"
    
    # Retry each message
    echo "$MESSAGES" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            # Extract message (after timestamp)
            MSG=$(echo "$line" | sed 's/^\[[^]]*\] //')
            if [ -f "$TELEGRAM" ]; then
                bash "$TELEGRAM" "[RETRY] $MSG" 2>/dev/null
                sleep 2  # Rate limit
            fi
        fi
    done
    
    echo "[$(date)] Telegram queue processed" >> "$LOG_FILE"
fi

# Process Discord queue
if [ -f "$DISCORD_QUEUE" ] && [ -s "$DISCORD_QUEUE" ]; then
    echo "[$(date)] Processing Discord queue..." >> "$LOG_FILE"
    
    MESSAGES=$(cat "$DISCORD_QUEUE")
    > "$DISCORD_QUEUE"
    
    echo "$MESSAGES" | while IFS= read -r line; do
        if [ -n "$line" ]; then
            MSG=$(echo "$line" | sed 's/^\[[^]]*\] //')
            if [ -f "$DISCORD" ]; then
                bash "$DISCORD" "[RETRY] $MSG" 2>/dev/null
                sleep 2
            fi
        fi
    done
    
    echo "[$(date)] Discord queue processed" >> "$LOG_FILE"
fi
