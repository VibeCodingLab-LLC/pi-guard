#!/bin/bash
# =============================================================================
# Pi Guard - Pi Zero W Installation Script
# Lightweight security stack for 512MB RAM
# 
# What this installs:
#   - Pi-hole (DNS-level ad/malware blocking)
#   - Unbound (Encrypted DNS-over-TLS)
#   - fail2ban (SSH brute force protection)
#   - iptables (Firewall)
#   - auditd (System audit logging)
#   - Monitoring & alerting scripts
#
# Requirements: Raspberry Pi Zero W with Raspberry Pi OS Lite
# Time: 30-45 minutes
# =============================================================================

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging
LOG_FILE="/var/log/pi-guard-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${BLUE}"
echo "=============================================="
echo "   Pi Guard Installation - Pi Zero W"
echo "   Lightweight Security Stack (215MB RAM)"
echo "=============================================="
echo -e "${NC}"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    echo "Usage: sudo bash $0"
    exit 1
fi

# Check if this is a Pi Zero
if ! grep -q "Zero" /proc/device-tree/model 2>/dev/null; then
    echo -e "${YELLOW}Warning: This doesn't appear to be a Pi Zero.${NC}"
    echo "This script is optimized for Pi Zero W (512MB RAM)."
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo -e "${GREEN}[1/10]${NC} Updating system packages..."
apt update
apt upgrade -y

echo -e "${GREEN}[2/10]${NC} Installing dependencies..."
apt install -y \
    curl \
    wget \
    git \
    dnsutils \
    net-tools \
    ufw \
    fail2ban \
    auditd \
    audispd-plugins \
    libcap2-bin \
    sqlite3 \
    jq \
    mailutils \
    msmtp \
    msmtp-mta

# =============================================================================
# Pi-hole Installation
# =============================================================================
echo -e "${GREEN}[3/10]${NC} Installing Pi-hole..."

# Create Pi-hole config for unattended install
mkdir -p /etc/pihole
cat > /etc/pihole/setupVars.conf << 'EOF'
WEBPASSWORD=
PIHOLE_INTERFACE=wlan0
IPV4_ADDRESS=0.0.0.0
IPV6_ADDRESS=
PIHOLE_DNS_1=127.0.0.1#5335
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=10000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
DNSMASQ_LISTENING=local
BLOCKING_ENABLED=true
EOF

# Download and run Pi-hole installer
curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

# Set a random password and save it
PIHOLE_PASSWORD=$(openssl rand -base64 12)
pihole -a -p "$PIHOLE_PASSWORD"
echo "Pi-hole admin password: $PIHOLE_PASSWORD" > /root/pihole-password.txt
chmod 600 /root/pihole-password.txt

echo -e "${YELLOW}Pi-hole password saved to /root/pihole-password.txt${NC}"

# =============================================================================
# Unbound (Encrypted DNS) Installation
# =============================================================================
echo -e "${GREEN}[4/10]${NC} Installing Unbound (DNS-over-TLS)..."

apt install -y unbound

# Download root hints
wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root

# Configure Unbound for Pi-hole
cat > /etc/unbound/unbound.conf.d/pi-hole.conf << 'EOF'
server:
    # Basic settings
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    
    # Security settings
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    use-caps-for-id: no
    
    # Privacy - use DNS-over-TLS to upstream
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    
    # Performance (optimized for Pi Zero)
    num-threads: 1
    msg-cache-slabs: 2
    rrset-cache-slabs: 2
    infra-cache-slabs: 2
    key-cache-slabs: 2
    rrset-cache-size: 16m
    msg-cache-size: 8m
    
    # Root hints
    root-hints: "/var/lib/unbound/root.hints"
    
    # Access control
    access-control: 127.0.0.0/8 allow
    access-control: 192.168.0.0/16 allow
    access-control: 10.0.0.0/8 allow
    
    # Private addresses
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8

# Use DNS-over-TLS for upstream queries (Cloudflare)
forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
EOF

# Set permissions
chown -R unbound:unbound /var/lib/unbound

# Enable and start
systemctl enable unbound
systemctl restart unbound

# Test Unbound
sleep 2
if dig @127.0.0.1 -p 5335 google.com +short > /dev/null; then
    echo -e "${GREEN}✓ Unbound is working${NC}"
else
    echo -e "${RED}✗ Unbound test failed${NC}"
fi

# Configure Pi-hole to use Unbound
sed -i 's/PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#5335/' /etc/pihole/setupVars.conf
pihole restartdns

# =============================================================================
# Firewall Configuration
# =============================================================================
echo -e "${GREEN}[5/10]${NC} Configuring firewall..."

# Copy firewall rules
cp "$SCRIPT_DIR/configs/iptables.sh" /usr/local/bin/pi-guard-firewall.sh
chmod +x /usr/local/bin/pi-guard-firewall.sh

# Apply firewall rules
bash /usr/local/bin/pi-guard-firewall.sh

# Make persistent
apt install -y iptables-persistent
netfilter-persistent save

echo -e "${GREEN}✓ Firewall configured${NC}"

# =============================================================================
# fail2ban Configuration
# =============================================================================
echo -e "${GREEN}[6/10]${NC} Configuring fail2ban..."

# Copy fail2ban config
cp "$SCRIPT_DIR/configs/jail.local" /etc/fail2ban/jail.local

# Enable and start
systemctl enable fail2ban
systemctl restart fail2ban

echo -e "${GREEN}✓ fail2ban configured${NC}"

# =============================================================================
# SSH Hardening
# =============================================================================
echo -e "${GREEN}[7/10]${NC} Hardening SSH..."

# Backup original config
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup

# Apply hardened config
cp "$SCRIPT_DIR/configs/sshd_config" /etc/ssh/sshd_config

# Restart SSH
systemctl restart sshd

echo -e "${GREEN}✓ SSH hardened${NC}"

# =============================================================================
# Auditd Configuration
# =============================================================================
echo -e "${GREEN}[8/10]${NC} Configuring audit logging..."

# Copy audit rules
cp "$SCRIPT_DIR/configs/auditd.rules" /etc/audit/rules.d/pi-guard.rules

# Enable and start
systemctl enable auditd
systemctl restart auditd

echo -e "${GREEN}✓ Audit logging configured${NC}"

# =============================================================================
# Monitoring Scripts Setup
# =============================================================================
echo -e "${GREEN}[9/10]${NC} Setting up monitoring..."

# Create config directory
mkdir -p /home/pi/.config/pi-guard
chown pi:pi /home/pi/.config/pi-guard

# Copy monitoring scripts
cp "$SCRIPT_DIR/monitoring/"*.sh /usr/local/bin/
chmod +x /usr/local/bin/monitor-*.sh

# Copy alert scripts
mkdir -p /usr/local/bin/alerts
cp "$SCRIPT_DIR/cron/alerts/"*.sh /usr/local/bin/alerts/
chmod +x /usr/local/bin/alerts/*.sh

# Create alert config templates
cat > /home/pi/.config/pi-guard/telegram.conf.example << 'EOF'
# Telegram Bot Configuration
# 1. Message @BotFather on Telegram
# 2. Send /newbot and follow instructions
# 3. Copy your token below
# 4. Start a chat with your bot
# 5. Visit https://api.telegram.org/bot<TOKEN>/getUpdates
# 6. Copy your chat_id below
# 7. Rename this file to telegram.conf

BOT_TOKEN="your-bot-token-here"
CHAT_ID="your-chat-id-here"
EOF

cat > /home/pi/.config/pi-guard/discord.conf.example << 'EOF'
# Discord Webhook Configuration
# 1. Open Discord
# 2. Right-click channel → Edit Channel
# 3. Integrations → Webhooks → New Webhook
# 4. Copy the URL below
# 5. Rename this file to discord.conf

WEBHOOK_URL="https://discord.com/api/webhooks/..."
EOF

cat > /home/pi/.config/pi-guard/email.conf.example << 'EOF'
# Email Alert Configuration
# For Gmail: Use an App Password (not your regular password)
# Google Account → Security → App Passwords
# Rename this file to email.conf

SMTP_SERVER="smtp.gmail.com"
SMTP_PORT="587"
EMAIL_FROM="your-email@gmail.com"
EMAIL_TO="your-email@gmail.com"
EMAIL_PASSWORD="your-app-password"
EOF

chown -R pi:pi /home/pi/.config/pi-guard

# =============================================================================
# Cron Jobs Setup
# =============================================================================
echo -e "${GREEN}[10/10]${NC} Setting up scheduled tasks..."

# Install crontab
cat > /tmp/pi-guard-cron << 'EOF'
# Pi Guard Scheduled Tasks
# ========================

# Check for blocked intrusion attempts every 5 minutes
*/5 * * * * /usr/local/bin/monitor-fail2ban.sh

# Check Pi-hole status every hour
0 * * * * /usr/local/bin/monitor-pihole.sh

# Daily security report at 8 AM
0 8 * * * /usr/local/bin/alerts/daily-report.sh

# Update Pi-hole gravity (blocklists) weekly on Sunday at 3 AM
0 3 * * 0 pihole -g

# Update root hints monthly
0 4 1 * * wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root && systemctl restart unbound
EOF

crontab -u root /tmp/pi-guard-cron
rm /tmp/pi-guard-cron

echo -e "${GREEN}✓ Cron jobs configured${NC}"

# =============================================================================
# Final Setup
# =============================================================================
echo ""
echo -e "${BLUE}=============================================="
echo "   Installation Complete!"
echo "==============================================${NC}"
echo ""
echo -e "Pi-hole Dashboard:    ${GREEN}http://$(hostname -I | awk '{print $1}')/admin${NC}"
echo -e "Pi-hole Password:     ${GREEN}$(cat /root/pihole-password.txt | cut -d: -f2 | tr -d ' ')${NC}"
echo ""
echo "Next steps:"
echo "  1. Configure alerts: nano ~/.config/pi-guard/telegram.conf"
echo "  2. Test alerts: bash /usr/local/bin/alerts/send-telegram.sh 'Test'"
echo "  3. Point your router/devices to use this Pi for DNS"
echo "  4. Run verification: bash $SCRIPT_DIR/scripts/verify.sh"
echo ""
echo -e "Memory usage: ${YELLOW}$(free -m | awk 'NR==2{printf "%.0f%%", $3*100/$2}')${NC}"
echo ""
echo "Log file: $LOG_FILE"
echo ""
