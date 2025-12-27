#!/bin/bash
# =============================================================================
# Pi Guard - Email Alert (with Retry Logic)
# =============================================================================

CONFIG_FILE="${HOME}/.config/pi-guard/email.conf"
FALLBACK_CONFIG="/home/pi/.config/pi-guard/email.conf"
LOG_FILE="/var/log/pi-guard/alerts.log"

MAX_RETRIES=3
RETRY_DELAY=10

# Load config
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
elif [ -f "$FALLBACK_CONFIG" ]; then
    source "$FALLBACK_CONFIG"
else
    echo "[$(date)] ERROR: Email config not found" >> "$LOG_FILE"
    exit 1
fi

if [ -z "$EMAIL_FROM" ] || [ -z "$EMAIL_TO" ] || [ -z "$EMAIL_PASSWORD" ]; then
    echo "[$(date)] ERROR: Email config incomplete" >> "$LOG_FILE"
    exit 1
fi

SMTP_SERVER="${SMTP_SERVER:-smtp.gmail.com}"
SMTP_PORT="${SMTP_PORT:-587}"

# Get subject and message
SUBJECT="${1:-Pi Guard Alert}"
shift
if [ -n "$1" ]; then
    MESSAGE="$1"
else
    MESSAGE=$(cat)
fi

[ -z "$MESSAGE" ] && exit 0

# Add timestamp
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
MESSAGE="Time: $TIMESTAMP

$MESSAGE

--
Pi Guard Security Appliance
$(hostname -I | awk '{print $1}')"

# Create msmtp config
MSMTP_CONFIG=$(mktemp)
cat > "$MSMTP_CONFIG" << EOF
defaults
auth on
tls on
tls_trust_file /etc/ssl/certs/ca-certificates.crt
logfile /var/log/pi-guard/msmtp.log

account default
host $SMTP_SERVER
port $SMTP_PORT
from $EMAIL_FROM
user $EMAIL_FROM
password $EMAIL_PASSWORD
EOF
chmod 600 "$MSMTP_CONFIG"

# Send with retry
send_message() {
    local attempt=1
    local delay=$RETRY_DELAY
    
    while [ $attempt -le $MAX_RETRIES ]; do
        if echo -e "Subject: $SUBJECT\nFrom: $EMAIL_FROM\nTo: $EMAIL_TO\n\n$MESSAGE" | \
            msmtp --file="$MSMTP_CONFIG" "$EMAIL_TO" 2>/dev/null; then
            echo "[$(date)] SUCCESS: Email sent (attempt $attempt)" >> "$LOG_FILE"
            rm -f "$MSMTP_CONFIG"
            return 0
        fi
        
        echo "[$(date)] RETRY $attempt/$MAX_RETRIES: Email failed" >> "$LOG_FILE"
        
        [ $attempt -lt $MAX_RETRIES ] && sleep $delay && delay=$((delay * 2))
        attempt=$((attempt + 1))
    done
    
    rm -f "$MSMTP_CONFIG"
    return 1
}

if send_message; then
    echo "✓ Email sent to $EMAIL_TO"
else
    echo "[$(date)] FAILED: Email to $EMAIL_TO" >> "$LOG_FILE"
    echo "✗ Failed to send email"
    exit 1
fi
