# Pi Guard - Installation Guide

## 🚀 One-Command Installation

Pi Guard now features a **smart installer** that automatically detects your Raspberry Pi hardware and installs only what it can support.

### Quick Install

```bash
# Clone the repository
git clone https://github.com/yourusername/pi-guard.git
cd pi-guard

# Run the installer (it will detect your Pi model automatically)
sudo bash scripts/install.sh
```

The installer will:
- ✅ Detect your Pi model (Zero W, 3A+, 3B+, 4, etc.)
- ✅ Automatically select the right components for your hardware
- ✅ Retry failed installations automatically
- ✅ Install everything in one run without stopping
- ✅ Set up convenient command aliases

**No more choosing between different install scripts!**

---

## 📱 Simple Commands

After installation, Pi Guard creates convenient aliases:

```bash
piguard        # Launch interactive control panel
sudo install   # Run/rerun the installer
sudo update    # Update all components
sudo verify    # Check system health
```

---

## 🎛️ Interactive Control Panel

Type `piguard` to access the interactive menu system:

```
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║   ██████╗ ██╗     ██████╗ ██╗   ██╗ █████╗ ██████╗ ██████╗       ║
║   ██╔══██╗██║    ██╔════╝ ██║   ██║██╔══██╗██╔══██╗██╔══██╗      ║
║   ██████╔╝██║    ██║  ███╗██║   ██║███████║██████╔╝██║  ██║      ║
║   ██╔═══╝ ██║    ██║   ██║██║   ██║██╔══██║██╔══██╗██║  ██║      ║
║   ██║     ██║    ╚██████╔╝╚██████╔╝██║  ██║██║  ██║██████╔╝      ║
║   ╚═╝     ╚═╝     ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝       ║
║                                                                   ║
║              Network Security Appliance Control Panel            ║
╚═══════════════════════════════════════════════════════════════════╝

Main Menu:

  [1] System Management
  [2] Service Control
  [3] Alert Configuration
  [4] View Logs
  [5] System Information
  [6] Network Status

  [0] Exit
```

### Menu Features

#### 1. System Management
- Install/Reinstall Pi Guard
- Update all components
- Verify system health
- Harden SSH (key-only authentication)

#### 2. Service Control
- Restart individual services (Pi-hole, Unbound, fail2ban, Snort)
- Start/Stop Snort IDS
- Restart all services at once
- View service logs

#### 3. Alert Configuration
- Configure Telegram alerts (with built-in editor)
- Configure Discord alerts
- Configure Email alerts
- Test each alert type
- View alert documentation

#### 4. View Logs
- Pi-hole logs
- fail2ban logs
- Snort IDS alerts
- Installation logs
- System logs
- SSH authentication logs

#### 5. System Information
- Hardware details (model, RAM, temperature)
- Resource usage (memory, disk, uptime)
- Pi-hole statistics (queries, blocked, blocklist size)
- fail2ban statistics (banned IPs)

#### 6. Network Status
- DNS resolution testing
- Unbound DNS-over-TLS testing
- Internet connectivity check
- Active network connections
- Quick access to Pi-hole dashboard

---

## 🔧 What Gets Installed

The installer automatically selects components based on your hardware:

### All Devices (Minimum)
- ✅ Pi-hole (DNS filtering)
- ✅ Unbound (DNS-over-TLS encryption)
- ✅ fail2ban (SSH brute-force protection)
- ✅ iptables firewall
- ✅ auditd (security logging)
- ✅ zram (memory optimization)

### Pi 3A+ and Higher
Everything above **PLUS**:
- ✅ Snort 3 IDS (intrusion detection)
- ✅ arpwatch (ARP spoofing detection)

### Pi 3B+/4 (1GB+ RAM)
Everything above **PLUS**:
- ✅ Pi.Alert (network device discovery)
- ✅ ntopng (advanced monitoring)

---

## 🔄 Automatic Retry Logic

The new installer includes intelligent retry logic:

- Network operations retry up to 3 times
- Exponential backoff (2s, 4s, 8s delays)
- Continues on non-critical failures
- Reports all errors at the end

**Result**: Installation completes in one run without manual intervention!

---

## 📊 Installation Time

| Device | Typical Time |
|--------|--------------|
| Pi Zero W | 30-45 minutes |
| Pi 3A+ | 45-60 minutes |
| Pi 3B+/4 | 50-70 minutes |

---

## 🎯 After Installation

1. **Access the control panel:**
   ```bash
   piguard
   ```

2. **Configure alerts** (optional but recommended):
   - Select option `[3] Alert Configuration` in the menu
   - Choose your preferred alert method (Telegram/Discord/Email)
   - Follow the built-in instructions

3. **Point your router DNS** to your Pi Guard IP address

4. **Test the system:**
   ```bash
   sudo verify
   ```

5. **Set up SSH keys** and then harden SSH:
   - Generate SSH key on your computer
   - Copy it to the Pi: `ssh-copy-id pi@pi-guard.local`
   - Run: `sudo bash ~/pi-guard/scripts/harden-ssh.sh`

---

## 🛠️ Troubleshooting

If installation fails:

1. **Check the installation log:**
   ```bash
   sudo tail -50 /var/log/pi-guard-install.log
   ```

2. **Verify internet connection:**
   ```bash
   ping -c 3 1.1.1.1
   ```

3. **Re-run the installer:**
   ```bash
   sudo install
   ```
   The installer is idempotent - safe to run multiple times.

4. **Check system resources:**
   ```bash
   free -h
   df -h
   ```

---

## 💡 Pro Tips

1. **Quick status check:**
   ```bash
   piguard status
   ```

2. **Update regularly:**
   ```bash
   sudo update
   ```
   Recommended: Weekly or monthly

3. **Monitor alerts:**
   Set up Telegram alerts for real-time security notifications

4. **Check logs periodically:**
   Use the menu system (option 4) or:
   ```bash
   sudo tail -f /var/log/pihole.log
   sudo fail2ban-client status sshd
   ```

---

## 🔐 Security Notes

- All telemetry is **disabled by default**
- Your DNS queries stay on your Pi
- No data sent to cloud services
- Encrypted DNS (DNS-over-TLS) to Cloudflare
- Firewall blocks all incoming traffic except SSH
- fail2ban protects against brute-force attacks
- Regular security updates via unattended-upgrades

---

## 📚 Additional Documentation

- [ALERTS.md](docs/ALERTS.md) - Detailed alert setup
- [HARDENING.md](docs/HARDENING.md) - Advanced security
- [SNORT-TUNING.md](docs/SNORT-TUNING.md) - IDS optimization
- [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

---

## 🆘 Getting Help

1. Check the troubleshooting guide
2. View logs in the menu system
3. Open an issue on GitHub
4. Include your installation log: `/var/log/pi-guard-install.log`
