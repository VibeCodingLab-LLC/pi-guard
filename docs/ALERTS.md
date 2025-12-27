# Alert Setup Guide

Get notifications on your phone when Pi Guard detects threats.

---

## Telegram (Recommended)

Free, instant, and easy to set up.

### Step 1: Create a Bot

1. Open Telegram on your phone
2. Search for `@BotFather`
3. Send: `/newbot`
4. Follow prompts:
   - Name: `Pi Guard Alerts`
   - Username: `MyPiGuardBot` (must end in "bot", must be unique)
5. **Save the token** (looks like `123456:ABC-DEF1234...`)

### Step 2: Get Your Chat ID

1. Start a chat with your new bot (search for it, click Start)
2. Send any message (like "hello")
3. Open in browser:
   ```
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```
4. Find `"chat":{"id":123456789` - that's your **chat_id**

### Step 3: Configure

```bash
nano ~/.config/pi-guard/telegram.conf
```

Add:
```bash
BOT_TOKEN="123456:ABC-DEF1234ghIkl-xyz"
CHAT_ID="123456789"
```

### Step 4: Test

```bash
bash ~/pi-guard/cron/alerts/send-telegram.sh "Test from Pi Guard!"
```

You should receive a message!

---

## Discord

Send alerts to a Discord channel.

### Step 1: Create Webhook

1. Open Discord
2. Right-click channel → Edit Channel
3. Integrations → Webhooks → New Webhook
4. Copy the URL

### Step 2: Configure

```bash
nano ~/.config/pi-guard/discord.conf
```

Add:
```bash
WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

### Step 3: Test

```bash
bash ~/pi-guard/cron/alerts/send-discord.sh "Test from Pi Guard!"
```

---

## Email

### Step 1: Get App Password (Gmail)

1. Go to [Google Account](https://myaccount.google.com)
2. Security → 2-Step Verification (enable)
3. Security → App Passwords
4. Generate password for "Mail"
5. Copy the 16-character password

### Step 2: Configure

```bash
nano ~/.config/pi-guard/email.conf
```

Add:
```bash
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT="587"
EMAIL_FROM="your@gmail.com"
EMAIL_TO="your@gmail.com"
EMAIL_PASSWORD="your-16-char-app-password"
```

### Step 3: Test

```bash
bash ~/pi-guard/cron/alerts/send-email.sh "Test Subject" "Test message!"
```

---

## Alert Types

| Alert | Priority | Channels |
|-------|----------|----------|
| SSH Attack Blocked | High | Telegram + Discord |
| Snort Priority 1 | Critical | Telegram + Discord |
| Snort Priority 2-3 | Low | Daily Report only |
| ARP Spoofing | Critical | Telegram + Discord |
| New Device | Info | Telegram only |
| Pi-hole Down | High | All channels |
| Daily Report | Info | All channels |

---

## Retry Logic

All alert scripts include automatic retry:
- 3 attempts per message
- Exponential backoff (5s, 10s, 20s)
- Failed messages queued for later
- All attempts logged for forensics

---

## Troubleshooting

### "Config not found"
```bash
# Check file exists
cat ~/.config/pi-guard/telegram.conf

# Check permissions
ls -la ~/.config/pi-guard/
```

### Telegram: No message received
1. Make sure you started a chat with your bot
2. Verify token and chat_id are correct
3. Test API directly:
   ```bash
   curl "https://api.telegram.org/bot<TOKEN>/getMe"
   ```

### Discord: Webhook fails
1. Check URL is complete (starts with https://)
2. Verify webhook still exists in Discord
3. Check channel permissions

### Email: Authentication error
- Use App Password, not regular password
- Enable 2FA on your Google account first
- Check for typos in email address
