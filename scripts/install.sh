#!/bin/bash
# =============================================================================
# Pi Guard - Unified Installer
# Automatically detects hardware and installs appropriate components
#
# Features:
#   - Hardware auto-detection (Zero W / 3A+ / 3B+/4)
#   - zram for memory optimization
#   - Telemetry disabled
#   - Tuned Snort rules for Pi hardware
#   - ARP spoofing detection
#   - Priority-based alerting
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging
LOG_FILE="/var/log/pi-guard-install.log"
exec > >(tee -a "$LOG_FILE") 2>&1

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# =============================================================================
# =============================================================================
# Functions
# =============================================================================

# Function to restart zram, pihole, and unbound before the script stops
finalize_services() {
    echo -e "\n[*] Finalizing core services before exit..."

    # Restart ZRAM (Force reset to handle 'device busy' errors)
    sudo swapoff /dev/zram0 2>/dev/null || true
    sudo zramctl --reset /dev/zram0 2>/dev/null || true
    sudo systemctl restart zramswap.service 2>/dev/null || true

    # Restart Pi-hole and Unbound
    sudo systemctl restart pihole-FTL 2>/dev/null || true
    sudo systemctl restart unbound 2>/dev/null || true

    echo "[*] Service sync complete."
}

# Set trap to run finalize_services on script exit, error, or interruption
trap finalize_services EXIT

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║   ██████╗ ██╗     ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗║"
    echo "║   ██╔══██╗██║    ██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗"
    echo "║   ██████╔╝██║    ██║  ███╗██║   ██║███████║██████╔╝██║  ██║"
    echo "║   ██╔═══╝ ██║    ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║"
    echo "║   ██║     ██║    ╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝"
    echo "║   ╚═╝     ╚═╝     ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ "
    echo "║                                                           ║"
    echo "║              Network Security Appliance                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║                                                           ║"
    echo "║   ██████╗ ██╗     ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗║"
    echo "║   ██╔══██╗██║    ██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗"
    echo "║   ██████╔╝██║    ██║  ███╗██║   ██║███████║██████╔╝██║  ██║"
    echo "║   ██╔═══╝ ██║    ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║"
    echo "║   ██║     ██║    ╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝"
    echo "║   ╚═╝     ╚═╝     ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ "
    echo "║                                                           ║"
    echo "║              Network Security Appliance                   ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# =============================================================================
# Hardware Detection
# =============================================================================

detect_hardware() {
    log "Detecting hardware..."
    
    MODEL=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
    MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    MEMORY_MB=$((MEMORY_KB / 1024))
    CPU_CORES=$(nproc)
    
    echo ""
    echo -e "  ${CYAN}Model:${NC}  $MODEL"
    echo -e "  ${CYAN}Memory:${NC} ${MEMORY_MB}MB"
    echo -e "  ${CYAN}CPU:${NC}    $CPU_CORES cores"
    echo ""
    
    # Determine installation profile
    if [[ "$MODEL" == *"Zero"* ]]; then
        PROFILE="minimal"
        INSTALL_IDS=false
        INSTALL_ARPWATCH=false
        INSTALL_PIALERT=false
        log "Profile: MINIMAL (Pi Zero - DNS security only)"
        
    elif [[ "$MODEL" == *"3 Model A"* ]] || [[ "$MODEL" == *"3A+"* ]]; then
        PROFILE="standard"
        INSTALL_IDS=true
        INSTALL_ARPWATCH=true
        INSTALL_PIALERT=false
        log "Profile: STANDARD (Pi 3A+ - Full IDS stack)"
        
    elif [[ "$MEMORY_MB" -gt 900 ]]; then
        PROFILE="full"
        INSTALL_IDS=true
        INSTALL_ARPWATCH=true
        INSTALL_PIALERT=true
        log "Profile: FULL (1GB+ RAM - Complete monitoring)"
        
    else
        PROFILE="standard"
        INSTALL_IDS=true
        INSTALL_ARPWATCH=true
        INSTALL_PIALERT=false
        log "Profile: STANDARD (Default)"
    fi
    
    echo ""
    read -p "Continue with $PROFILE profile? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        error "Installation cancelled"
    fi
}

# =============================================================================
# Pre-Installation
# =============================================================================

check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Please run as root: sudo bash $0"
    fi
}

check_internet() {
    log "Checking internet connection..."
    if ! ping -c 1 1.1.1.1 &> /dev/null; then
        error "No internet connection. Please connect and try again."
    fi
}

# =============================================================================
# System Setup
# =============================================================================

update_system() {
    log "Updating system packages..."
    apt update
    apt upgrade -y
}

install_dependencies() {
    log "Installing dependencies..."
    apt install -y \
        curl wget git \
        dnsutils net-tools \
        iptables iptables-persistent \
        fail2ban \
        auditd audispd-plugins \
        libcap2-bin \
        sqlite3 \
        jq \
        bc \
        msmtp msmtp-mta \
        unattended-upgrades
}

# =============================================================================
# zram (Memory Optimization)
# =============================================================================

install_zram() {
    log "Installing zram for memory optimization..."
    apt install -y zram-tools
    
    # Configure zram
    cat > /etc/default/zramswap << 'EOF'
# Pi Guard zram configuration
# Compress RAM to get more effective memory

# Percentage of RAM to use for zram (50% is safe)
PERCENT=50

# Compression algorithm (lz4 is fastest)
ALGO=lz4

# Priority (higher than disk swap)
PRIORITY=100
EOF
    
    systemctl enable zramswap
    systemctl restart zramswap
    
    log "zram configured: $(swapon --show | grep zram)"
}

# =============================================================================
# Pi-hole Installation
# =============================================================================

install_pihole() {
    log "Installing Pi-hole..."
    
    # Determine interface
    if ip link show eth0 &>/dev/null; then
        INTERFACE="eth0"
    else
        INTERFACE="wlan0"
    fi
    
    mkdir -p /etc/pihole
cat > /etc/pihole/setupVars.conf << EOF 2>/dev/null || true\nWEBPASSWORD=
PIHOLE_INTERFACE=$INTERFACE
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

    # Install Pi-hole (unattended)
    curl -sSL https://install.pi-hole.net | bash /dev/stdin --unattended
    
    # Generate and save password
    PIHOLE_PASSWORD=$(openssl rand -base64 12)
    pihole -a -p "$PIHOLE_PASSWORD"
    echo "$PIHOLE_PASSWORD" > /root/.pihole-password
    chmod 600 /root/.pihole-password
    
    # Disable Pi-hole telemetry
    pihole checkout master
    echo "PRIVACYLEVEL=0" >> /etc/pihole/pihole-FTL.conf
    
    log "Pi-hole installed. Password saved to /root/.pihole-password"
}

# =============================================================================
# Unbound (DNS-over-TLS)
# =============================================================================

install_unbound() {
    log "Installing Unbound (DNS-over-TLS)..."
    apt install -y unbound
    
    # Download root hints
    wget -q -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root
    
    # Determine thread count based on CPU
    if [ "$CPU_CORES" -gt 2 ]; then
        THREADS=2
    else
        THREADS=1
    fi
    
    # Configure Unbound
    cat > /etc/unbound/unbound.conf.d/pi-hole.conf << EOF
server:
    verbosity: 0
    interface: 127.0.0.1
    port: 5335
    do-ip4: yes
    do-ip6: no
    do-udp: yes
    do-tcp: yes
    
    # Security
    hide-identity: yes
    hide-version: yes
    harden-glue: yes
    harden-dnssec-stripped: yes
    harden-referral-path: yes
    harden-below-nxdomain: yes
    use-caps-for-id: no
    
    # TLS for upstream
    tls-cert-bundle: /etc/ssl/certs/ca-certificates.crt
    
    # Performance (tuned for Pi)
    num-threads: $THREADS
    msg-cache-slabs: 2
    rrset-cache-slabs: 2
    infra-cache-slabs: 2
    key-cache-slabs: 2
    rrset-cache-size: 16m
    msg-cache-size: 8m
    prefetch: yes
    prefetch-key: yes
    
    # Root hints
    root-hints: "/var/lib/unbound/root.hints"
    
    # Access control
    access-control: 127.0.0.0/8 allow
    access-control: 192.168.0.0/16 allow
    access-control: 10.0.0.0/8 allow
    access-control: 172.16.0.0/12 allow
    access-control: 0.0.0.0/0 refuse
    
    # Private addresses
    private-address: 192.168.0.0/16
    private-address: 169.254.0.0/16
    private-address: 172.16.0.0/12
    private-address: 10.0.0.0/8

forward-zone:
    name: "."
    forward-tls-upstream: yes
    forward-addr: 1.1.1.1@853#cloudflare-dns.com
    forward-addr: 1.0.0.1@853#cloudflare-dns.com
EOF

    chown -R unbound:unbound /var/lib/unbound
    systemctl enable unbound
    systemctl restart unbound
    
    # Update Pi-hole to use Unbound
sed -i 's/PIHOLE_DNS_1=.*/PIHOLE_DNS_1=127.0.0.1#5335/' /etc/pihole/setupVars.conf 2>/dev/null || true\n    pihole restartdns
    
    # Verify
    sleep 2
    if dig @127.0.0.1 -p 5335 google.com +short > /dev/null; then
        log "Unbound DNS-over-TLS working"
    else
        warn "Unbound test failed - check configuration"
    fi
}

# =============================================================================
# Firewall
# =============================================================================

configure_firewall() {
    log "Configuring firewall..."
    
    # Copy and apply firewall rules
    cp "$SCRIPT_DIR/configs/iptables.sh" /usr/local/bin/pi-guard-firewall.sh
    chmod +x /usr/local/bin/pi-guard-firewall.sh
    bash /usr/local/bin/pi-guard-firewall.sh
    
    # Save rules
    netfilter-persistent save
    
    log "Firewall configured"
}

# =============================================================================
# fail2ban
# =============================================================================

configure_fail2ban() {
    log "Configuring fail2ban..."
    
    cp "$SCRIPT_DIR/configs/jail.local" /etc/fail2ban/jail.local
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log "fail2ban configured"
}

# =============================================================================
# SSH Hardening (Initial)
# =============================================================================

configure_ssh() {
    log "Configuring SSH..."
    
    # Backup original
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Apply hardened config (password auth still enabled for initial setup)
    cp "$SCRIPT_DIR/configs/sshd_config" /etc/ssh/sshd_config
    
    # Create sshusers group
    groupadd -f sshusers
    usermod -aG sshusers pi
    
    systemctl restart sshd
    
    log "SSH configured (password auth enabled - run harden-ssh.sh after setting up keys)"
}

# =============================================================================
# Auditd (Enhanced)
# =============================================================================

configure_auditd() {
    log "Configuring audit logging..."
    
    cp "$SCRIPT_DIR/configs/auditd.rules" /etc/audit/rules.d/pi-guard.rules
    
    systemctl enable auditd
    systemctl restart auditd
    
    log "Audit logging configured"
}

# =============================================================================
# arpwatch (MITM Detection)
# =============================================================================

install_arpwatch() {
    if [ "$INSTALL_ARPWATCH" = true ]; then
        log "Installing arpwatch (ARP spoofing detection)..."
        
        apt install -y arpwatch
        
        # Configure arpwatch
        if ip link show eth0 &>/dev/null; then
            INTERFACE="eth0"
        else
            INTERFACE="wlan0"
        fi
        
        # Create systemd override for interface
        mkdir -p /etc/systemd/system/arpwatch.service.d
        cat > /etc/systemd/system/arpwatch.service.d/interface.conf << EOF
[Service]
ExecStart=
ExecStart=/usr/sbin/arpwatch -i $INTERFACE -f /var/lib/arpwatch/arp.dat
EOF
        
        systemctl daemon-reload
        systemctl enable arpwatch
        systemctl start arpwatch
        
        log "arpwatch configured on $INTERFACE"
    fi
}

# =============================================================================
# Snort 3 IDS (Optimized for Pi)
# =============================================================================

install_snort() {
    if [ "$INSTALL_IDS" = true ]; then
        log "Installing Snort 3 IDS (optimized for Pi)..."
        
        apt install -y snort
        
        # Create directories
        mkdir -p /var/log/snort
        mkdir -p /etc/snort/rules
        mkdir -p /etc/snort/lists
        
        # Download community rules
        log "Downloading Snort community rules..."
        cd /tmp
        wget -q https://www.snort.org/downloads/community/snort3-community-rules.tar.gz -O snort3-rules.tar.gz || true
        
        if [ -f snort3-rules.tar.gz ]; then
            tar -xzf snort3-rules.tar.gz
            cp -r snort3-community-rules/* /etc/snort/rules/ 2>/dev/null || true
            rm -rf snort3-rules.tar.gz snort3-community-rules
        fi
        
        # Copy optimized Snort config
        mkdir -p /etc/snort
        cp "$SCRIPT_DIR/configs/snort/snort.lua" /etc/snort/snort.lua
        cp "$SCRIPT_DIR/configs/snort/threshold.conf" /etc/snort/threshold.conf
        
        # Determine interface
        if ip link show eth0 &>/dev/null; then
            SNORT_INTERFACE="eth0"
        else
            SNORT_INTERFACE="wlan0"
        fi
        
        # Create systemd service
        cat > /etc/systemd/system/snort.service << EOF
[Unit]
Description=Snort 3 IDS
After=network.target

[Service]
Type=simple
ExecStart=/usr/bin/snort -c /etc/snort/snort.lua -i $SNORT_INTERFACE -A alert_fast -l /var/log/snort --tweaks=pi
Restart=on-failure
RestartSec=30
MemoryMax=300M
CPUQuota=50%

[Install]
WantedBy=multi-user.target
EOF

        chown -R root:root /etc/snort
        chmod -R 755 /etc/snort /var/log/snort
        
        systemctl daemon-reload
        systemctl enable snort
        
        log "Snort installed (start manually with: sudo systemctl start snort)"
        warn "Snort disabled by default - tune rules first, then enable"
    fi
}

# =============================================================================
# Monitoring Scripts
# =============================================================================

setup_monitoring() {
    log "Setting up monitoring scripts..."
    
    # Create directories
    mkdir -p /var/log/pi-guard
    mkdir -p /home/pi/.config/pi-guard
    chown -R pi:pi /home/pi/.config/pi-guard
    
    # Copy monitoring scripts
    cp "$SCRIPT_DIR/monitoring/"*.sh /usr/local/bin/
    chmod +x /usr/local/bin/monitor-*.sh
    chmod +x /usr/local/bin/daily-report.sh
    
    # Copy alert scripts
    mkdir -p /usr/local/bin/alerts
    cp "$SCRIPT_DIR/cron/alerts/"*.sh /usr/local/bin/alerts/
    chmod +x /usr/local/bin/alerts/*.sh
    
    # Create config templates
    cat > /home/pi/.config/pi-guard/telegram.conf.example << 'EOF'
# Telegram Configuration
# See docs/ALERTS.md for setup instructions
BOT_TOKEN="your-bot-token"
CHAT_ID="your-chat-id"
EOF

    cat > /home/pi/.config/pi-guard/discord.conf.example << 'EOF'
# Discord Configuration
WEBHOOK_URL="https://discord.com/api/webhooks/..."
EOF

    cat > /home/pi/.config/pi-guard/email.conf.example << 'EOF'
# Email Configuration
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT="587"
EMAIL_FROM="your@email.com"
EMAIL_TO="your@email.com"
EMAIL_PASSWORD="your-app-password"
EOF

    chown -R pi:pi /home/pi/.config/pi-guard
    
    log "Monitoring scripts installed"
}

# =============================================================================
# Cron Jobs
# =============================================================================

setup_cron() {
    log "Setting up scheduled tasks..."
    
    cat > /tmp/pi-guard-cron << 'EOF'
# Pi Guard Scheduled Tasks
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin

# Monitor fail2ban every 5 minutes
*/5 * * * * /usr/local/bin/monitor-fail2ban.sh >> /var/log/pi-guard/cron.log 2>&1

# Monitor Pi-hole every hour
0 * * * * /usr/local/bin/monitor-pihole.sh >> /var/log/pi-guard/cron.log 2>&1

# Monitor Snort every 10 minutes (if installed)
*/10 * * * * [ -f /var/log/snort/alert ] && /usr/local/bin/monitor-snort.sh >> /var/log/pi-guard/cron.log 2>&1

# Monitor arpwatch every 15 minutes (if installed)
*/15 * * * * [ -f /var/lib/arpwatch/arp.dat ] && /usr/local/bin/monitor-arpwatch.sh >> /var/log/pi-guard/cron.log 2>&1

# Daily security report at 8 AM
0 8 * * * /usr/local/bin/daily-report.sh >> /var/log/pi-guard/cron.log 2>&1

# Update Pi-hole blocklists weekly (Sunday 3 AM)
0 3 * * 0 pihole -g >> /var/log/pi-guard/pihole-update.log 2>&1

# Update DNS root hints monthly
0 4 1 * * wget -q -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root && systemctl restart unbound

# Rotate logs weekly
0 0 * * 0 find /var/log/pi-guard -name "*.log" -mtime +14 -delete

# Auto-restart services if down
*/15 * * * * systemctl is-active --quiet pihole-FTL || systemctl restart pihole-FTL
*/15 * * * * systemctl is-active --quiet unbound || systemctl restart unbound
EOF

    crontab -u root /tmp/pi-guard-cron
    rm /tmp/pi-guard-cron
    
    log "Cron jobs configured"
}

# =============================================================================
# Disable Telemetry
# =============================================================================

disable_telemetry() {
    log "Disabling telemetry..."
    
    # Disable Raspberry Pi telemetry service (if exists)
    systemctl disable rpi-telemetry 2>/dev/null || true
    systemctl stop rpi-telemetry 2>/dev/null || true
    
    # Disable apt telemetry
    echo 'APT::Periodic::Download-Upgradeable-Packages "0";' > /etc/apt/apt.conf.d/99disable-telemetry
    
    # Pi-hole telemetry (already done in install)
    if [ -f /etc/pihole/pihole-FTL.conf ]; then
        grep -q "PRIVACYLEVEL" /etc/pihole/pihole-FTL.conf || echo "PRIVACYLEVEL=0" >> /etc/pihole/pihole-FTL.conf
    fi
    
    log "Telemetry disabled"
}

# =============================================================================
# Enable Automatic Security Updates
# =============================================================================

setup_auto_updates() {
    log "Enabling automatic security updates..."
    
    cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
Unattended-Upgrade::Origins-Pattern {
    "origin=Debian,codename=${distro_codename},label=Debian-Security";
    "origin=Raspbian,codename=${distro_codename},label=Raspbian";
};
Unattended-Upgrade::AutoFixInterruptedDpkg "true";
Unattended-Upgrade::MinimalSteps "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
Unattended-Upgrade::Automatic-Reboot "false";
EOF

    cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

    log "Automatic security updates enabled"
}

# =============================================================================
# Final Summary
# =============================================================================

print_summary() {
    PI_IP=$(hostname -I | awk '{print $1}')
    PIHOLE_PASS=$(cat /root/.pihole-password 2>/dev/null || echo "check /root/.pihole-password")
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Installation Complete!                          ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "  ${CYAN}Profile:${NC}           $PROFILE"
    echo -e "  ${CYAN}Pi-hole Dashboard:${NC} http://$PI_IP/admin"
    echo -e "  ${CYAN}Pi-hole Password:${NC}  $PIHOLE_PASS"
    echo ""
    echo -e "  ${CYAN}Components Installed:${NC}"
    echo "    ✓ Pi-hole (DNS filtering)"
    echo "    ✓ Unbound (DNS-over-TLS)"
    echo "    ✓ Firewall (iptables)"
    echo "    ✓ fail2ban (SSH protection)"
    echo "    ✓ auditd (audit logging)"
    echo "    ✓ zram (memory optimization)"
    [ "$INSTALL_ARPWATCH" = true ] && echo "    ✓ arpwatch (ARP spoofing detection)"
    [ "$INSTALL_IDS" = true ] && echo "    ✓ Snort 3 (IDS - disabled, tune first)"
    echo ""
    echo -e "  ${YELLOW}Next Steps:${NC}"
    echo "    1. Configure alerts: nano ~/.config/pi-guard/telegram.conf"
    echo "    2. Test alerts: bash /usr/local/bin/alerts/send-telegram.sh 'Test'"
    echo "    3. Verify: bash ~/pi-guard/scripts/verify.sh"
    echo "    4. Setup SSH keys, then run: sudo bash ~/pi-guard/scripts/harden-ssh.sh"
    echo "    5. Point router DNS to: $PI_IP"
    [ "$INSTALL_IDS" = true ] && echo "    6. Tune Snort: see docs/SNORT-TUNING.md"
    echo ""
    echo -e "  ${CYAN}Memory:${NC} $(free -m | awk 'NR==2{printf "%dMB / %dMB (%.0f%%)", $3, $2, $3*100/$2}')"
    echo ""
    echo "  Log file: $LOG_FILE"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_banner
    check_root
    check_internet
    detect_hardware
    
    log "Starting installation..."
    
    update_system
    install_dependencies
    install_zram
    install_pihole
    install_unbound
    configure_firewall
    configure_fail2ban
    configure_ssh
    configure_auditd
    install_arpwatch
    install_snort
    setup_monitoring
    setup_cron
    disable_telemetry
    setup_auto_updates
    
    print_summary
}

main "$@"
