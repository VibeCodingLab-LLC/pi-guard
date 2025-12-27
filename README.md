## 🔮 Tech Stack

<img src="https://img.shields.io/badge/Raspberry%20Pi-0D1117?style=for-the-badge&logo=raspberrypi&logoColor=FF1493" height="90">
<img src="https://img.shields.io/badge/Linux-0D1117?style=for-the-badge&logo=linux&logoColor=00FFFF" height="90">
<img src="https://img.shields.io/badge/Shell_Script-0D1117?style=for-the-badge&logo=gnu-bash&logoColor=FF00FF" height="90">

![Pi-hole](https://img.shields.io/badge/Pi--hole-0D1117?style=for-the-badge&logo=pihole&logoColor=00D4FF)
![Docker](https://img.shields.io/badge/Docker-0D1117?style=for-the-badge&logo=docker&logoColor=FF1493)
![Snort](https://img.shields.io/badge/Snort-0D1117?style=for-the-badge&logo=snort&logoColor=00FFFF)

--

## ⚡ Cloud / Infrastructure

![DigitalOcean](https://img.shields.io/badge/DigitalOcean-0D1117?style=for-the-badge&logo=digitalocean&logoColor=FF00FF)
![Cloudflare](https://img.shields.io/badge/Cloudflare-0D1117?style=for-the-badge&logo=cloudflare&logoColor=00D4FF)

---

# Pi Guard

**Hardened network security appliance for Raspberry Pi**

Turn any Raspberry Pi into a 24/7 security appliance that blocks malware, encrypts DNS, detects intrusions, and alerts you on your phone.

---

## What Does Pi Guard Do?

1. **Blocks bad websites** - Stops ads, trackers, and malware domains (1M+ blocklist)
2. **Encrypts your DNS** - Your ISP can't see what websites you visit
3. **Detects attacks** - Intrusion detection with priority-based alerting
4. **Monitors your network** - Detects ARP spoofing and rogue devices
5. **Alerts you instantly** - Telegram/Discord/Email with retry logic

---

## Hardware Support

| Device | RAM | What Gets Installed | Best For |
|--------|-----|---------------------|----------|
| **Pi Zero W** | 512MB | Pi-hole + Unbound + fail2ban | DNS filtering only |
| **Pi 3A+** | 512MB | Above + Snort IDS + arpwatch | Full security stack |
| **Pi 3B+/4** | 1GB+ | Above + Pi.Alert + ntopng | Complete monitoring |

The installer **automatically detects your hardware** and installs appropriate components.

---

## Quick Start

```bash
# 1. Flash Raspberry Pi OS Lite to SD card (use Raspberry Pi Imager)
#    Enable SSH in settings, set hostname to "pi-guard"

# 2. Boot Pi and SSH in
ssh pi@pi-guard.local

# 3. Clone and install
git clone https://github.com/yourusername/pi-guard.git
cd pi-guard
sudo bash scripts/install.sh

# 4. Follow the prompts
```

**Total time:** 30-60 minutes depending on hardware

---

## Security Features

| Feature | Description |
|---------|-------------|
| **DNS Filtering** | Pi-hole blocks ads, trackers, malware domains |
| **Encrypted DNS** | Unbound with DNS-over-TLS to Cloudflare |
| **Firewall** | iptables with rate limiting, deny-by-default |
| **SSH Hardening** | Key-only auth, fail2ban, restricted user group |
| **Intrusion Detection** | Snort 3 with tuned rules (Pi 3A+ only) |
| **ARP Monitoring** | Detects MITM attacks and rogue devices |
| **Audit Logging** | Full system audit trail with auditd |
| **Memory Optimization** | zram for better performance on limited RAM |

---

## Telemetry

**All telemetry is disabled by default.** Your DNS queries and network data stay on your Pi.

---

## Repository Structure

```
pi-guard/
├── scripts/
│   ├── install.sh           # Single modular installer (detects hardware)
│   ├── verify.sh            # System health check
│   ├── update.sh            # Update all components
│   └── harden-ssh.sh        # Switch to key-only SSH
│
├── configs/
│   ├── sshd_config          # Hardened SSH
│   ├── unbound.conf         # DNS-over-TLS
│   ├── iptables.sh          # Firewall rules
│   ├── jail.local           # fail2ban config
│   ├── auditd.rules         # Security audit rules
│   └── snort/
│       ├── snort.lua        # Optimized Snort config
│       └── threshold.conf   # False positive suppression
│
├── monitoring/
│   ├── monitor-*.sh         # Individual monitors
│   └── daily-report.sh      # Daily security summary
│
├── cron/
│   └── alerts/
│       ├── send-telegram.sh # With retry logic
│       ├── send-discord.sh  
│       └── send-email.sh    
│
├── docs/
│   ├── ALERTS.md            # Alert setup guide
│   ├── HARDENING.md         # Advanced hardening
│   ├── SNORT-TUNING.md      # IDS optimization
│   └── TROUBLESHOOTING.md   
│
└── tests/
    └── test-*.sh            # Verification scripts
```

---

## Cost

| Setup | Hardware | Monthly |
|-------|----------|---------|
| Pi Zero W | €28 | €0.15 |
| Pi 3A+ | €43 | €0.30 |

**No subscriptions. No cloud fees. Your data stays home.**

---

## Documentation

- [DEPLOYMENT.md](DEPLOYMENT.md) - Step-by-step setup guide
- [docs/ALERTS.md](docs/ALERTS.md) - Configure notifications
- [docs/HARDENING.md](docs/HARDENING.md) - Advanced security
- [docs/SNORT-TUNING.md](docs/SNORT-TUNING.md) - IDS optimization
- [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - Common issues

---

## License

MIT License - See [LICENSE](LICENSE)

**Disclaimer:** For authorized security monitoring only. You are responsible for complying with all applicable laws.
