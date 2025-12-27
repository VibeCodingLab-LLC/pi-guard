#!/bin/bash
# =============================================================================
# Pi Guard - Pi 3A+ Installation Script
# Full security stack with IDS
# 
# What this installs:
#   - Everything in Pi Zero W script, PLUS:
#   - Snort 3 IDS (Intrusion Detection System)
#   - Pi.Alert (Network device discovery)
#   - Enhanced monitoring
#
# Requirements: Raspberry Pi 3A+ with Raspberry Pi OS Lite (64-bit)
# Time: 45-60 minutes
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="/var/log/pi-guard-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${BLUE}"
echo "=============================================="
echo "   Pi Guard Installation - Pi 3A+"
echo "   Full Security Stack with IDS"
echo "=============================================="
echo -e "${NC}"

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Error: Please run as root (use sudo)${NC}"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# =============================================================================
# Base Installation (same as Pi Zero W)
# =============================================================================
echo -e "${GREEN}[1/12]${NC} Running base installation..."

apt update && apt upgrade -y

apt install -y \
    curl wget git dnsutils net-tools ufw fail2ban \
    auditd audispd-plugins libcap2-bin sqlite3 jq \
    mailutils msmtp msmtp-mta build-essential \
    libpcap-dev libpcre3-dev libnet1-dev zlib1g-dev \
    libluajit-5.1-dev libhwloc-dev pkg-config cmake \
    liblzma-dev openssl libssl-dev flex bison

# =============================================================================
# Pi-hole
# =============================================================================
echo -e "${GREEN}[2/12]${NC} Installing Pi-hole..."

mkdir -p /etc/pihole
cat > /etc/pihole/setupVars.conf << 'EOF'
WEBPASSWORD=
PIHOLE_INTERFACE=eth0
IPV4_ADDRESS=0.0.0.0
PIHOLE_DNS_1=127.0.0.1#5335
QUERY_LOGGING=true
INSTALL_WEB_SERVER=true
INSTALL_WEB_INTERFACE=true
LIGHTTPD_ENABLED=true
CACHE_SIZE=20000
DNS_FQDN_REQUIRED=true
DNS_BOGUS_PRIV=true
BLOCKING_ENABLED=true
EOF

curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended

PIHOLE_PASSWORD=$(openssl rand -base64 12)
pihole -a -p "$PIHOLE_PASSWORD"
echo "Pi-hole password: $PIHOLE_PASSWORD" > /root/pihole-password.txt
chmod 600 /root/pihole-password.txt

# =============================================================================
# Unbound
# =============================================================================
echo -e "${GREEN}[3/12]${NC} Installing Unbound..."

apt install -y unbound
wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root

cat > /etc/unbound/unbound.conf.d/pi-hole.conf << 'EOF'
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-udp: yes
    do-tcp: yes
    do-ip6: no
    
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    
    # Pi 3A+ has more resources
    num-threads: 2
    msg-cache-slabs: 4
    rrset-cache-slabs: 4
    infra-cache-slabs: 4
    key-cache-slabs: 4
    rrset-cache-size: 32m
    msg-cache-size: 16m
    
    root-hints: "/var/lib/unbound/root.hints"
    
    access-control: 127.0.0.0/8 allow
    access-control: 192.168.0.0/16 allow
    access-control: 10.0.0.0/8 allow

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
EOF

chown -R unbound:unbound /var/lib/unbound
systemctl enable unbound
systemctl restart unbound

sed -i 's/PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#5335/' /etc/pihole/setupVars.conf
pihole restartdns

# =============================================================================
# Firewall
# =============================================================================
echo -e "${GREEN}[4/12]${NC} Configuring firewall..."

cp "$SCRIPT_DIR/configs/iptables.sh" /usr/local/bin/pi-guard-firewall.sh
chmod +x /usr/local/bin/pi-guard-firewall.sh
bash /usr/local/bin/pi-guard-firewall.sh

apt install -y iptables-persistent
netfilter-persistent save

# =============================================================================
# fail2ban
# =============================================================================
echo -e "${GREEN}[5/12]${NC} Configuring fail2ban..."

cp "$SCRIPT_DIR/configs/jail.local" /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban

# =============================================================================
# SSH Hardening
# =============================================================================
echo -e "${GREEN}[6/12]${NC} Hardening SSH..."

cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
cp "$SCRIPT_DIR/configs/sshd_config" /etc/ssh/sshd_config
systemctl restart sshd

# =============================================================================
# Auditd
# =============================================================================
echo -e "${GREEN}[7/12]${NC} Configuring audit logging..."

cp "$SCRIPT_DIR/configs/auditd.rules" /etc/audit/rules.d/pi-guard.rules
systemctl enable auditd
systemctl restart auditd

# =============================================================================
# Snort 3 IDS (Lightweight Configuration)
# =============================================================================
echo -e "${GREEN}[8/12]${NC} Installing Snort 3 IDS..."

# Install Snort from package (easier than compiling)
apt install -y snort3

# Create Snort directories
mkdir -p /var/log/snort
mkdir -p /etc/snort/rules
mkdir -p /etc/snort/lists

# Download Community Rules
echo "Downloading Snort community rules..."
cd /tmp
wget https://www.snort.org/downloads/community/snort3-community-rules.tar.gz -O snort3-rules.tar.gz || true

if [ -f snort3-rules.tar.gz ]; then
    tar -xzf snort3-rules.tar.gz
    cp -r snort3-community-rules/* /etc/snort/rules/ 2>/dev/null || true
fi

# Create lightweight Snort config for Pi
cat > /etc/snort/snort.lua << 'EOF'
-- Pi Guard Snort 3 Configuration
-- Optimized for Raspberry Pi 3A+

-- Home network definition
HOME_NET = '192.168.0.0/16'
EXTERNAL_NET = '!$HOME_NET'

-- Paths
RULE_PATH = '/etc/snort/rules'
BUILTIN_RULE_PATH = '/etc/snort/builtin_rules'

-- Stream configuration (reduced for Pi)
stream = { }
stream_tcp = { }

-- Detection settings
detection = {
    search_method = 'ac_full',
}

-- Logging
alert_fast = {
    file = true,
    packet = false,
}

-- Output to file
output = {
    event_trace = {
        enable = true,
    },
}

-- Include rules
ips = {
    enable_builtin_rules = true,
    rules = [[
        include $RULE_PATH/snort3-community.rules
    ]],
    variables = default_variables,
}
EOF

# Create Snort systemd service
cat > /etc/systemd/system/snort.service << 'EOF'
[Unit]
Description=Snort 3 IDS
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/snort -c /etc/snort/snort.lua -i eth0 -A alert_fast -l /var/log/snort
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Set permissions
chown -R root:root /etc/snort
chmod -R 755 /etc/snort
chmod -R 755 /var/log/snort

# Enable Snort (but don't start yet - needs testing)
systemctl daemon-reload
systemctl enable snort

echo -e "${YELLOW}Note: Snort installed but not started. Start with: sudo systemctl start snort${NC}"

# =============================================================================
# Pi.Alert (Network Device Discovery)
# =============================================================================
echo -e "${GREEN}[9/12]${NC} Installing Pi.Alert..."

# Install dependencies
apt install -y \
    python3 python3-pip python3-venv \
    arp-scan nmap libwww-perl

# Clone Pi.Alert
cd /opt
if [ ! -d "pialert" ]; then
    git clone https://github.com/leiweibau/Pi.Alert.git pialert
fi

cd /opt/pialert

# Create virtual environment
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install requests mac-vendor-lookup

# Configure Pi.Alert
cp /opt/pialert/config/pialert.conf.bak /opt/pialert/config/pialert.conf 2>/dev/null || true

# Create Pi.Alert service
cat > /etc/systemd/system/pialert.service << 'EOF'
[Unit]
Description=Pi.Alert Network Scanner
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/pialert
ExecStart=/opt/pialert/venv/bin/python /opt/pialert/pialert/pialert.py
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

# Create web server config for Pi.Alert
cat > /etc/lighttpd/conf-available/50-pialert.conf << 'EOF'
# Pi.Alert web interface
$HTTP["url"] =~ "^/pialert" {
    alias.url = ( "/pialert" => "/opt/pialert/front" )
}
EOF

ln -sf /etc/lighttpd/conf-available/50-pialert.conf /etc/lighttpd/conf-enabled/ 2>/dev/null || true

systemctl daemon-reload
systemctl enable pialert
systemctl restart lighttpd

echo -e "${GREEN}✓ Pi.Alert installed${NC}"

# =============================================================================
# Monitoring Scripts
# =============================================================================
echo -e "${GREEN}[10/12]${NC} Setting up monitoring..."

mkdir -p /home/pi/.config/pi-guard
chown pi:pi /home/pi/.config/pi-guard

cp "$SCRIPT_DIR/monitoring/"*.sh /usr/local/bin/
chmod +x /usr/local/bin/monitor-*.sh

mkdir -p /usr/local/bin/alerts
cp "$SCRIPT_DIR/cron/alerts/"*.sh /usr/local/bin/alerts/
chmod +x /usr/local/bin/alerts/*.sh

# Create config templates
cat > /home/pi/.config/pi-guard/telegram.conf.example << 'EOF'
BOT_TOKEN="your-bot-token-here"
CHAT_ID="your-chat-id-here"
EOF

cat > /home/pi/.config/pi-guard/discord.conf.example << 'EOF'
WEBHOOK_URL="https://discord.com/api/webhooks/..."
EOF

chown -R pi:pi /home/pi/.config/pi-guard

# =============================================================================
# Cron Jobs
# =============================================================================
echo -e "${GREEN}[11/12]${NC} Setting up scheduled tasks..."

cat > /tmp/pi-guard-cron << 'EOF'
# Pi Guard Scheduled Tasks (Pi 3A+)

# Monitor fail2ban every 5 minutes
*/5 * * * * /usr/local/bin/monitor-fail2ban.sh

# Monitor Pi-hole every hour
0 * * * * /usr/local/bin/monitor-pihole.sh

# Monitor Snort alerts every 10 minutes
*/10 * * * * /usr/local/bin/monitor-snort.sh

# Scan for new network devices every 30 minutes
*/30 * * * * /opt/pialert/venv/bin/python /opt/pialert/back/pialert.py scan

# Daily security report at 8 AM
0 8 * * * /usr/local/bin/alerts/daily-report.sh

# Update Pi-hole blocklists weekly
0 3 * * 0 pihole -g

# Update Snort rules weekly
0 4 * * 0 /usr/local/bin/update-snort-rules.sh

# Update root hints monthly
0 4 1 * * wget -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root && systemctl restart unbound
EOF

crontab -u root /tmp/pi-guard-cron
rm /tmp/pi-guard-cron

# =============================================================================
# Snort Rule Updater
# =============================================================================
echo -e "${GREEN}[12/12]${NC} Creating update scripts..."

cat > /usr/local/bin/update-snort-rules.sh << 'EOF'
#!/bin/bash
# Update Snort community rules

cd /tmp
wget -q https://www.snort.org/downloads/community/snort3-community-rules.tar.gz -O snort3-rules.tar.gz

if [ -f snort3-rules.tar.gz ]; then
    tar -xzf snort3-rules.tar.gz
    cp -r snort3-community-rules/* /etc/snort/rules/ 2>/dev/null
    systemctl restart snort
    echo "Snort rules updated: $(date)"
fi

rm -rf /tmp/snort3-rules.tar.gz /tmp/snort3-community-rules
EOF

chmod +x /usr/local/bin/update-snort-rules.sh

# =============================================================================
# Final
# =============================================================================
echo ""
echo -e "${BLUE}=============================================="
echo "   Installation Complete!"
echo "==============================================${NC}"
echo ""
echo -e "Pi-hole Dashboard:  ${GREEN}http://$(hostname -I | awk '{print $1}')/admin${NC}"
echo -e "Pi.Alert:           ${GREEN}http://$(hostname -I | awk '{print $1}'):20211${NC}"
echo -e "Pi-hole Password:   ${GREEN}$(cat /root/pihole-password.txt | cut -d: -f2 | tr -d ' ')${NC}"
echo ""
echo "Services installed:"
echo "  ✓ Pi-hole (DNS filtering)"
echo "  ✓ Unbound (Encrypted DNS)"
echo "  ✓ Firewall (iptables)"
echo "  ✓ fail2ban (SSH protection)"
echo "  ✓ auditd (Audit logging)"
echo "  ✓ Snort 3 (IDS - start manually)"
echo "  ✓ Pi.Alert (Device discovery)"
echo ""
echo "Next steps:"
echo "  1. Configure alerts: nano ~/.config/pi-guard/telegram.conf"
echo "  2. Start Snort: sudo systemctl start snort"
echo "  3. Point devices to use this Pi for DNS"
echo "  4. Verify: bash $SCRIPT_DIR/scripts/verify.sh"
echo ""
echo -e "Memory usage: ${YELLOW}$(free -m | awk 'NR==2{printf "%.0f%% (%dMB / %dMB)", $3*100/$2, $3, $2}')${NC}"
echo ""
