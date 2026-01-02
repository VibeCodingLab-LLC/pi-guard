#!/bin/bash
# =============================================================================
# Pi Guard - Interactive Menu System
# Easy terminal interface for managing Pi Guard
# =============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Get Pi Guard directory
if [ -d "$HOME/pi-guard" ]; then
    PIGUARD_DIR="$HOME/pi-guard"
elif [ -d "/home/pi/pi-guard" ]; then
    PIGUARD_DIR="/home/pi/pi-guard"
else
    PIGUARD_DIR="/opt/pi-guard"
fi

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║   ██████╗ ██╗     ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗       ║"
    echo "║   ██╔══██╗██║    ██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗      ║"
    echo "║   ██████╔╝██║    ██║  ███╗██║   ██║███████║██████╔╝██║  ██║      ║"
    echo "║   ██╔═══╝ ██║    ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║      ║"
    echo "║   ██║     ██║    ╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝      ║"
    echo "║   ╚═╝     ╚═╝     ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝       ║"
    echo "║                                                                   ║"
    echo "║              Network Security Appliance Control Panel            ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_status() {
    local PI_IP=$(hostname -I | awk '{print $1}')
    local MEMORY=$(free -m | awk 'NR==2{printf "%dMB / %dMB (%.0f%%)", $3, $2, $3*100/$2}')
    local UPTIME=$(uptime -p | sed 's/up //')

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  ${BOLD}System Status${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "  IP Address: ${GREEN}$PI_IP${NC}"
    echo -e "  Memory:     ${YELLOW}$MEMORY${NC}"
    echo -e "  Uptime:     ${BLUE}$UPTIME${NC}"
    echo ""
    echo -e "  ${BOLD}Services:${NC}"

    check_service_status "Pi-hole" "pihole-FTL"
    check_service_status "Unbound" "unbound"
    check_service_status "fail2ban" "fail2ban"
    check_service_status "Snort IDS" "snort"
    check_service_status "arpwatch" "arpwatch"

    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_service_status() {
    local name=$1
    local service=$2

    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "    ${GREEN}●${NC} $name (running)"
    elif systemctl list-unit-files 2>/dev/null | grep -q "^${service}"; then
        echo -e "    ${RED}●${NC} $name (stopped)"
    else
        echo -e "    ${YELLOW}○${NC} $name (not installed)"
    fi
}

pause() {
    echo ""
    read -p "Press Enter to continue..."
}

confirm() {
    local prompt="$1"
    read -p "$prompt [y/N]: " -n 1 -r
    echo
    [[ $REPLY =~ ^[Yy]$ ]]
}

# =============================================================================
# Main Menu Functions
# =============================================================================

show_main_menu() {
    print_header
    print_status

    echo -e "${BOLD}Main Menu:${NC}"
    echo ""
    echo "  ${CYAN}[1]${NC} System Management"
    echo "  ${CYAN}[2]${NC} Service Control"
    echo "  ${CYAN}[3]${NC} Alert Configuration"
    echo "  ${CYAN}[4]${NC} View Logs"
    echo "  ${CYAN}[5]${NC} System Information"
    echo "  ${CYAN}[6]${NC} Network Status"
    echo ""
    echo "  ${CYAN}[0]${NC} Exit"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1) system_management_menu ;;
        2) service_control_menu ;;
        3) alert_config_menu ;;
        4) view_logs_menu ;;
        5) system_info_menu ;;
        6) network_status_menu ;;
        0) exit 0 ;;
        *) echo "Invalid option"; sleep 1; show_main_menu ;;
    esac
}

# =============================================================================
# System Management Menu
# =============================================================================

system_management_menu() {
    print_header
    echo -e "${BOLD}System Management${NC}"
    echo ""
    echo "  ${CYAN}[1]${NC} Install/Reinstall Pi Guard"
    echo "  ${CYAN}[2]${NC} Update All Components"
    echo "  ${CYAN}[3]${NC} Verify System Health"
    echo "  ${CYAN}[4]${NC} Harden SSH (Key-only Auth)"
    echo ""
    echo "  ${CYAN}[0]${NC} Back to Main Menu"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1)
            if confirm "This will run the full Pi Guard installer. Continue?"; then
                sudo bash "$PIGUARD_DIR/scripts/install.sh"
                pause
            fi
            system_management_menu
            ;;
        2)
            echo -e "\n${GREEN}Updating Pi Guard...${NC}\n"
            sudo bash "$PIGUARD_DIR/scripts/update.sh"
            pause
            system_management_menu
            ;;
        3)
            echo -e "\n${GREEN}Verifying system...${NC}\n"
            sudo bash "$PIGUARD_DIR/scripts/verify.sh"
            pause
            system_management_menu
            ;;
        4)
            if confirm "This will disable SSH password authentication. Ensure you have SSH keys set up! Continue?"; then
                sudo bash "$PIGUARD_DIR/scripts/harden-ssh.sh"
                pause
            fi
            system_management_menu
            ;;
        0) show_main_menu ;;
        *) echo "Invalid option"; sleep 1; system_management_menu ;;
    esac
}

# =============================================================================
# Service Control Menu
# =============================================================================

service_control_menu() {
    print_header
    echo -e "${BOLD}Service Control${NC}"
    echo ""

    # Show current status
    echo -e "${CYAN}Current Status:${NC}"
    check_service_status "Pi-hole" "pihole-FTL"
    check_service_status "Unbound" "unbound"
    check_service_status "fail2ban" "fail2ban"
    check_service_status "Snort IDS" "snort"
    check_service_status "arpwatch" "arpwatch"
    echo ""

    echo "  ${CYAN}[1]${NC} Restart Pi-hole"
    echo "  ${CYAN}[2]${NC} Restart Unbound (DNS)"
    echo "  ${CYAN}[3]${NC} Restart fail2ban"
    echo "  ${CYAN}[4]${NC} Start/Stop Snort IDS"
    echo "  ${CYAN}[5]${NC} Restart All Services"
    echo "  ${CYAN}[6]${NC} View Service Logs"
    echo ""
    echo "  ${CYAN}[0]${NC} Back to Main Menu"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1)
            echo -e "\n${GREEN}Restarting Pi-hole...${NC}"
            sudo systemctl restart pihole-FTL
            echo "Done!"
            pause
            service_control_menu
            ;;
        2)
            echo -e "\n${GREEN}Restarting Unbound...${NC}"
            sudo systemctl restart unbound
            echo "Done!"
            pause
            service_control_menu
            ;;
        3)
            echo -e "\n${GREEN}Restarting fail2ban...${NC}"
            sudo systemctl restart fail2ban
            echo "Done!"
            pause
            service_control_menu
            ;;
        4)
            if systemctl is-active --quiet snort; then
                echo -e "\n${YELLOW}Stopping Snort IDS...${NC}"
                sudo systemctl stop snort
                echo "Snort stopped."
            else
                echo -e "\n${GREEN}Starting Snort IDS...${NC}"
                sudo systemctl start snort
                echo "Snort started."
            fi
            pause
            service_control_menu
            ;;
        5)
            if confirm "Restart all services?"; then
                echo -e "\n${GREEN}Restarting all services...${NC}"
                sudo systemctl restart pihole-FTL
                sudo systemctl restart unbound
                sudo systemctl restart fail2ban
                sudo systemctl restart snort 2>/dev/null || true
                sudo systemctl restart arpwatch 2>/dev/null || true
                echo "All services restarted!"
                pause
            fi
            service_control_menu
            ;;
        6)
            service_logs_menu
            ;;
        0) show_main_menu ;;
        *) echo "Invalid option"; sleep 1; service_control_menu ;;
    esac
}

# =============================================================================
# Alert Configuration Menu
# =============================================================================

alert_config_menu() {
    print_header
    echo -e "${BOLD}Alert Configuration${NC}"
    echo ""

    local CONFIG_DIR="$HOME/.config/pi-guard"

    # Check which alerts are configured
    echo -e "${CYAN}Alert Status:${NC}"
    if [ -f "$CONFIG_DIR/telegram.conf" ]; then
        echo -e "  ${GREEN}●${NC} Telegram configured"
    else
        echo -e "  ${YELLOW}○${NC} Telegram not configured"
    fi

    if [ -f "$CONFIG_DIR/discord.conf" ]; then
        echo -e "  ${GREEN}●${NC} Discord configured"
    else
        echo -e "  ${YELLOW}○${NC} Discord not configured"
    fi

    if [ -f "$CONFIG_DIR/email.conf" ]; then
        echo -e "  ${GREEN}●${NC} Email configured"
    else
        echo -e "  ${YELLOW}○${NC} Email not configured"
    fi

    echo ""
    echo "  ${CYAN}[1]${NC} Configure Telegram Alerts"
    echo "  ${CYAN}[2]${NC} Configure Discord Alerts"
    echo "  ${CYAN}[3]${NC} Configure Email Alerts"
    echo "  ${CYAN}[4]${NC} Test Telegram Alert"
    echo "  ${CYAN}[5]${NC} Test Discord Alert"
    echo "  ${CYAN}[6]${NC} Test Email Alert"
    echo "  ${CYAN}[7]${NC} View Alert Documentation"
    echo ""
    echo "  ${CYAN}[0]${NC} Back to Main Menu"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1)
            echo -e "\n${CYAN}Telegram Configuration${NC}"
            echo "Opening config file..."
            sleep 1
            if [ ! -f "$CONFIG_DIR/telegram.conf" ]; then
                cp "$CONFIG_DIR/telegram.conf.example" "$CONFIG_DIR/telegram.conf" 2>/dev/null || true
            fi
            nano "$CONFIG_DIR/telegram.conf"
            alert_config_menu
            ;;
        2)
            echo -e "\n${CYAN}Discord Configuration${NC}"
            echo "Opening config file..."
            sleep 1
            if [ ! -f "$CONFIG_DIR/discord.conf" ]; then
                cp "$CONFIG_DIR/discord.conf.example" "$CONFIG_DIR/discord.conf" 2>/dev/null || true
            fi
            nano "$CONFIG_DIR/discord.conf"
            alert_config_menu
            ;;
        3)
            echo -e "\n${CYAN}Email Configuration${NC}"
            echo "Opening config file..."
            sleep 1
            if [ ! -f "$CONFIG_DIR/email.conf" ]; then
                cp "$CONFIG_DIR/email.conf.example" "$CONFIG_DIR/email.conf" 2>/dev/null || true
            fi
            nano "$CONFIG_DIR/email.conf"
            alert_config_menu
            ;;
        4)
            echo -e "\n${GREEN}Sending test Telegram alert...${NC}"
            bash /usr/local/bin/alerts/send-telegram.sh "Test alert from Pi Guard"
            pause
            alert_config_menu
            ;;
        5)
            echo -e "\n${GREEN}Sending test Discord alert...${NC}"
            bash /usr/local/bin/alerts/send-discord.sh "Test alert from Pi Guard"
            pause
            alert_config_menu
            ;;
        6)
            echo -e "\n${GREEN}Sending test Email alert...${NC}"
            bash /usr/local/bin/alerts/send-email.sh "Test alert from Pi Guard"
            pause
            alert_config_menu
            ;;
        7)
            if [ -f "$PIGUARD_DIR/docs/ALERTS.md" ]; then
                less "$PIGUARD_DIR/docs/ALERTS.md"
            else
                echo "Documentation not found"
                pause
            fi
            alert_config_menu
            ;;
        0) show_main_menu ;;
        *) echo "Invalid option"; sleep 1; alert_config_menu ;;
    esac
}

# =============================================================================
# View Logs Menu
# =============================================================================

view_logs_menu() {
    print_header
    echo -e "${BOLD}View Logs${NC}"
    echo ""
    echo "  ${CYAN}[1]${NC} Pi-hole Logs"
    echo "  ${CYAN}[2]${NC} fail2ban Logs"
    echo "  ${CYAN}[3]${NC} Snort IDS Logs"
    echo "  ${CYAN}[4]${NC} Pi Guard Installation Log"
    echo "  ${CYAN}[5]${NC} System Logs (syslog)"
    echo "  ${CYAN}[6]${NC} SSH Authentication Logs"
    echo ""
    echo "  ${CYAN}[0]${NC} Back to Main Menu"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1)
            echo -e "\n${GREEN}Pi-hole Logs (last 50 lines):${NC}\n"
            sudo tail -n 50 /var/log/pihole.log 2>/dev/null || echo "Log file not found"
            pause
            view_logs_menu
            ;;
        2)
            echo -e "\n${GREEN}fail2ban Logs (last 50 lines):${NC}\n"
            sudo tail -n 50 /var/log/fail2ban.log 2>/dev/null || echo "Log file not found"
            pause
            view_logs_menu
            ;;
        3)
            echo -e "\n${GREEN}Snort IDS Alerts:${NC}\n"
            sudo tail -n 50 /var/log/snort/alert 2>/dev/null || echo "Log file not found"
            pause
            view_logs_menu
            ;;
        4)
            echo -e "\n${GREEN}Pi Guard Installation Log:${NC}\n"
            sudo tail -n 50 /var/log/pi-guard-install.log 2>/dev/null || echo "Log file not found"
            pause
            view_logs_menu
            ;;
        5)
            echo -e "\n${GREEN}System Logs (last 50 lines):${NC}\n"
            sudo journalctl -n 50 --no-pager
            pause
            view_logs_menu
            ;;
        6)
            echo -e "\n${GREEN}SSH Authentication Logs:${NC}\n"
            sudo grep "sshd" /var/log/auth.log | tail -n 50 2>/dev/null || echo "Log file not found"
            pause
            view_logs_menu
            ;;
        0) show_main_menu ;;
        *) echo "Invalid option"; sleep 1; view_logs_menu ;;
    esac
}

service_logs_menu() {
    print_header
    echo -e "${BOLD}Service Logs${NC}"
    echo ""
    echo "  ${CYAN}[1]${NC} Pi-hole Service Log"
    echo "  ${CYAN}[2]${NC} Unbound Service Log"
    echo "  ${CYAN}[3]${NC} fail2ban Service Log"
    echo "  ${CYAN}[4]${NC} Snort Service Log"
    echo ""
    echo "  ${CYAN}[0]${NC} Back"
    echo ""
    read -p "Select option: " choice

    case $choice in
        1)
            echo -e "\n${GREEN}Pi-hole Service Status:${NC}\n"
            sudo systemctl status pihole-FTL --no-pager
            pause
            service_logs_menu
            ;;
        2)
            echo -e "\n${GREEN}Unbound Service Status:${NC}\n"
            sudo systemctl status unbound --no-pager
            pause
            service_logs_menu
            ;;
        3)
            echo -e "\n${GREEN}fail2ban Service Status:${NC}\n"
            sudo systemctl status fail2ban --no-pager
            pause
            service_logs_menu
            ;;
        4)
            echo -e "\n${GREEN}Snort Service Status:${NC}\n"
            sudo systemctl status snort --no-pager
            pause
            service_logs_menu
            ;;
        0) service_control_menu ;;
        *) echo "Invalid option"; sleep 1; service_logs_menu ;;
    esac
}

# =============================================================================
# System Information Menu
# =============================================================================

system_info_menu() {
    print_header
    echo -e "${BOLD}System Information${NC}"
    echo ""

    local PI_IP=$(hostname -I | awk '{print $1}')
    local MODEL=$(cat /proc/device-tree/model 2>/dev/null || echo "Unknown")
    local MEMORY=$(free -m | awk 'NR==2{printf "%dMB total, %dMB used, %dMB free", $2, $3, $4}')
    local DISK=$(df -h / | awk 'NR==2{printf "%s total, %s used, %s free (%s)", $2, $3, $4, $5}')
    local CPU_TEMP=$(vcgencmd measure_temp 2>/dev/null | cut -d= -f2 || echo "N/A")
    local UPTIME=$(uptime -p | sed 's/up //')

    echo -e "${CYAN}Hardware:${NC}"
    echo -e "  Model:       $MODEL"
    echo -e "  IP Address:  ${GREEN}$PI_IP${NC}"
    echo -e "  Temperature: $CPU_TEMP"
    echo ""
    echo -e "${CYAN}Resources:${NC}"
    echo -e "  Memory:      $MEMORY"
    echo -e "  Disk:        $DISK"
    echo -e "  Uptime:      $UPTIME"
    echo ""

    # Check Pi-hole stats
    if command -v pihole &>/dev/null; then
        echo -e "${CYAN}Pi-hole Statistics:${NC}"
        local BLOCKED=$(pihole -c -j 2>/dev/null | jq -r '.ads_blocked_today' 2>/dev/null || echo "N/A")
        local QUERIES=$(pihole -c -j 2>/dev/null | jq -r '.dns_queries_today' 2>/dev/null || echo "N/A")
        local BLOCKLIST=$(pihole -c -j 2>/dev/null | jq -r '.domains_being_blocked' 2>/dev/null || echo "N/A")

        echo -e "  Queries today:       $QUERIES"
        echo -e "  Blocked today:       ${RED}$BLOCKED${NC}"
        echo -e "  Domains on blocklist: $BLOCKLIST"
        echo ""
    fi

    # Check fail2ban stats
    if command -v fail2ban-client &>/dev/null; then
        echo -e "${CYAN}fail2ban Statistics:${NC}"
        local BANNED=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
        local TOTAL_BANNED=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Total banned" | awk '{print $NF}')
        echo -e "  Currently banned:    ${RED}$BANNED${NC}"
        echo -e "  Total banned (ever): $TOTAL_BANNED"
        echo ""
    fi

    pause
    show_main_menu
}

# =============================================================================
# Network Status Menu
# =============================================================================

network_status_menu() {
    print_header
    echo -e "${BOLD}Network Status${NC}"
    echo ""

    echo -e "${CYAN}Testing network connectivity...${NC}"
    echo ""

    # Test DNS resolution
    if dig @127.0.0.1 google.com +short +time=2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Local DNS resolution working"
    else
        echo -e "  ${RED}✗${NC} Local DNS resolution failed"
    fi

    # Test Unbound
    if dig @127.0.0.1 -p 5335 cloudflare.com +short +time=2 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Unbound DNS-over-TLS working"
    else
        echo -e "  ${RED}✗${NC} Unbound DNS-over-TLS failed"
    fi

    # Test internet connectivity
    if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} Internet connectivity working"
    else
        echo -e "  ${RED}✗${NC} Internet connectivity failed"
    fi

    # Test Pi-hole web interface
    local PI_IP=$(hostname -I | awk '{print $1}')
    echo ""
    echo -e "${CYAN}Access URLs:${NC}"
    echo -e "  Pi-hole Admin: ${GREEN}http://$PI_IP/admin${NC}"

    # Show current connections
    echo ""
    echo -e "${CYAN}Active Network Connections:${NC}"
    sudo netstat -tuln 2>/dev/null | grep LISTEN | head -10

    echo ""
    pause
    show_main_menu
}

# =============================================================================
# Main Entry Point
# =============================================================================

# Check if running with arguments (for future CLI interface)
if [ $# -gt 0 ]; then
    case "$1" in
        status)
            print_header
            print_status
            ;;
        install)
            sudo bash "$PIGUARD_DIR/scripts/install.sh"
            ;;
        update)
            sudo bash "$PIGUARD_DIR/scripts/update.sh"
            ;;
        verify)
            sudo bash "$PIGUARD_DIR/scripts/verify.sh"
            ;;
        *)
            echo "Usage: piguard [status|install|update|verify]"
            echo "  Or run without arguments for interactive menu"
            exit 1
            ;;
    esac
else
    # Interactive mode
    while true; do
        show_main_menu
    done
fi
