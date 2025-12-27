#!/bin/bash
# =============================================================================
# Pi Guard - Update Script
# Updates all components
# =============================================================================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash $0"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo ""
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}                    Pi Guard Update                           ${NC}"
echo -e "${CYAN}══════════════════════════════════════════════════════════════${NC}"
echo ""

# System packages
echo -e "${GREEN}[1/6]${NC} Updating system packages..."
apt update
apt upgrade -y

# Pi-hole
echo -e "${GREEN}[2/6]${NC} Updating Pi-hole..."
pihole -up || true

# Pi-hole gravity (blocklists)
echo -e "${GREEN}[3/6]${NC} Updating Pi-hole blocklists..."
pihole -g || true

# Root hints
echo -e "${GREEN}[4/6]${NC} Updating DNS root hints..."
wget -q -O /var/lib/unbound/root.hints https://www.internic.net/domain/named.root
chown unbound:unbound /var/lib/unbound/root.hints
systemctl restart unbound

# Pi Guard scripts
echo -e "${GREEN}[5/6]${NC} Updating Pi Guard scripts..."
cd "$SCRIPT_DIR"
if git pull origin main 2>/dev/null; then
    # Update monitoring scripts
    cp "$SCRIPT_DIR/monitoring/"*.sh /usr/local/bin/ 2>/dev/null || true
    cp "$SCRIPT_DIR/cron/alerts/"*.sh /usr/local/bin/alerts/ 2>/dev/null || true
    chmod +x /usr/local/bin/monitor-*.sh 2>/dev/null || true
    chmod +x /usr/local/bin/daily-report.sh 2>/dev/null || true
    chmod +x /usr/local/bin/alerts/*.sh 2>/dev/null || true
    echo "  Scripts updated from repository"
else
    echo "  Not a git repo or no updates available"
fi

# Snort rules (if installed)
echo -e "${GREEN}[6/6]${NC} Updating Snort rules..."
if command -v snort &>/dev/null; then
    cd /tmp
    if wget -q https://www.snort.org/downloads/community/snort3-community-rules.tar.gz -O snort3-rules.tar.gz; then
        tar -xzf snort3-rules.tar.gz
        cp -r snort3-community-rules/* /etc/snort/rules/ 2>/dev/null || true
        rm -rf snort3-rules.tar.gz snort3-community-rules
        systemctl restart snort 2>/dev/null || true
        echo "  Snort rules updated"
    fi
else
    echo "  Snort not installed, skipping"
fi

# Summary
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    Update Complete!                          ${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Current versions:"
echo "  Pi-hole: $(pihole -v 2>/dev/null | head -1 || echo 'N/A')"
echo "  Unbound: $(unbound -V 2>&1 | head -1 || echo 'N/A')"
if command -v snort &>/dev/null; then
    echo "  Snort: $(snort -V 2>&1 | head -1 || echo 'N/A')"
fi
echo ""
echo "Run verification: bash $SCRIPT_DIR/scripts/verify.sh"
echo ""
