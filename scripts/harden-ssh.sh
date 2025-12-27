#!/bin/bash
# =============================================================================
# Pi Guard - SSH Hardening Script
# Run AFTER setting up SSH keys
#
# This script:
#   - Disables password authentication
#   - Restricts SSH to sshusers group
#   - Adds current user to sshusers
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo bash $0${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${YELLOW}║              SSH HARDENING WARNING                        ║${NC}"
echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "This script will DISABLE password authentication for SSH."
echo ""
echo -e "${RED}BEFORE CONTINUING, MAKE SURE:${NC}"
echo "  1. You have generated an SSH key"
echo "  2. You have copied it to this Pi (ssh-copy-id)"
echo "  3. You can login WITHOUT a password"
echo ""
echo "Test with: ssh -i ~/.ssh/your-key pi@$(hostname -I | awk '{print $1}')"
echo ""
read -p "Have you tested key-based login successfully? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo ""
    echo "Aborted. Setup SSH keys first:"
    echo "  1. On your computer: ssh-keygen -t ed25519 -f ~/.ssh/pi-guard"
    echo "  2. Copy to Pi: ssh-copy-id -i ~/.ssh/pi-guard pi@$(hostname -I | awk '{print $1}')"
    echo "  3. Test: ssh -i ~/.ssh/pi-guard pi@$(hostname -I | awk '{print $1}')"
    echo "  4. Run this script again"
    exit 1
fi

echo ""
echo "Proceeding with SSH hardening..."

# Ensure sshusers group exists
groupadd -f sshusers

# Add pi user (and any other users)
for user in pi $(who | awk '{print $1}' | sort -u); do
    if id "$user" &>/dev/null; then
        usermod -aG sshusers "$user"
        echo -e "  ${GREEN}✓${NC} Added $user to sshusers group"
    fi
done

# Update SSH config
SSHD_CONFIG="/etc/ssh/sshd_config"

# Backup
cp "$SSHD_CONFIG" "${SSHD_CONFIG}.pre-hardening"

# Disable password auth
sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#*ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' "$SSHD_CONFIG"
sed -i 's/^#*UsePAM.*/UsePAM no/' "$SSHD_CONFIG"

# Ensure key auth is enabled
sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' "$SSHD_CONFIG"

# Restrict to sshusers group (if not already)
if ! grep -q "^AllowGroups" "$SSHD_CONFIG"; then
    echo "" >> "$SSHD_CONFIG"
    echo "# Pi Guard: Restrict SSH to sshusers group" >> "$SSHD_CONFIG"
    echo "AllowGroups sshusers" >> "$SSHD_CONFIG"
fi

# Test config before restarting
echo ""
echo "Testing SSH configuration..."
if sshd -t; then
    echo -e "${GREEN}✓ SSH config valid${NC}"
else
    echo -e "${RED}✗ SSH config invalid! Reverting...${NC}"
    cp "${SSHD_CONFIG}.pre-hardening" "$SSHD_CONFIG"
    exit 1
fi

# Restart SSH
systemctl restart sshd

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              SSH Hardening Complete                       ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Changes applied:"
echo "  ✓ Password authentication disabled"
echo "  ✓ SSH restricted to sshusers group"
echo "  ✓ Key-based authentication required"
echo ""
echo -e "${YELLOW}DO NOT close this SSH session until you verify you can login!${NC}"
echo ""
echo "Open a NEW terminal and test:"
echo "  ssh -i ~/.ssh/pi-guard pi@$(hostname -I | awk '{print $1}')"
echo ""
