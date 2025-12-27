# Pi Guard Deployment Guide

**Complete step-by-step setup with exact commands**

---

## Table of Contents

1. [Hardware Requirements](#1-hardware-requirements)
2. [Download & Flash OS](#2-download--flash-os)
3. [First Boot](#3-first-boot)
4. [Install Pi Guard](#4-install-pi-guard)
5. [Configure Alerts](#5-configure-alerts)
6. [Harden SSH](#6-harden-ssh)
7. [Verify Installation](#7-verify-installation)
8. [Point Devices to Pi Guard](#8-point-devices-to-pi-guard)

**Total time: 45-90 minutes**

---

## 1. Hardware Requirements

### Minimum (Pi Zero W) - €28
| Item | Price | Link |
|------|-------|------|
| Raspberry Pi Zero W | €15 | [RPi Official](https://www.raspberrypi.com/products/raspberry-pi-zero-w/) |
| MicroSD Card 16GB+ | €8 | Any Class 10 card |
| Micro USB Power 5V 2A | €5 | Phone charger works |

### Recommended (Pi 3A+) - €43
| Item | Price | Link |
|------|-------|------|
| Raspberry Pi 3 Model A+ | €25 | [RPi Official](https://www.raspberrypi.com/products/raspberry-pi-3-model-a-plus/) |
| MicroSD Card 32GB+ | €10 | Any Class 10 card |
| USB-C Power 5V 3A | €8 | Official PSU recommended |

### Optional
- USB Ethernet Adapter (€5) - More reliable than WiFi
- Case (€5) - Physical protection

---

## 2. Download & Flash OS

### Step 2.1: Download Raspberry Pi Imager

**Windows/Mac:**
1. Go to: https://www.raspberrypi.com/software/
2. Download and install Raspberry Pi Imager

**Linux:**
```bash
sudo apt update
sudo apt install -y rpi-imager
```

### Step 2.2: Flash the SD Card

1. **Insert MicroSD card** into your computer

2. **Open Raspberry Pi Imager**

3. **Click "CHOOSE OS"**
   - Select **"Raspberry Pi OS (other)"**
   - Select **"Raspberry Pi OS Lite (64-bit)"** for Pi 3A+
   - Select **"Raspberry Pi OS Lite (32-bit)"** for Pi Zero W

4. **Click "CHOOSE STORAGE"**
   - Select your MicroSD card

5. **Click the gear icon ⚙️ (IMPORTANT!)**
   
   Configure these settings:
   ```
   ✅ Set hostname: pi-guard
   ✅ Enable SSH: Use password authentication
   ✅ Set username: pi
   ✅ Set password: [choose a strong password]
   ✅ Configure wireless LAN (if using WiFi):
      - SSID: [your WiFi name]
      - Password: [your WiFi password]
      - Country: [your country code]
   ✅ Set locale settings:
      - Time zone: [your timezone]
      - Keyboard layout: [your layout]
   ```

6. **Click "SAVE"** then **"WRITE"**

7. **Wait for completion** (5-10 minutes)

8. **Remove SD card** when done

---

## 3. First Boot

### Step 3.1: Boot the Pi

1. Insert MicroSD card into Pi
2. Connect ethernet cable (recommended) or use WiFi
3. Connect power cable
4. **Wait 2-3 minutes** for first boot

### Step 3.2: Find Your Pi's IP Address

**Option A: Use hostname (easiest)**
```bash
ping pi-guard.local
```

**Option B: Check your router**
- Open router admin page (usually 192.168.1.1)
- Look for "pi-guard" in connected devices

**Option C: Network scan**
```bash
# Linux/Mac
nmap -sn 192.168.1.0/24 | grep -B2 -i raspberry

# Windows PowerShell
arp -a | findstr "b8-27-eb"
```

### Step 3.3: Connect via SSH

```bash
ssh pi@pi-guard.local
# Or: ssh pi@192.168.1.X (use actual IP)

# Enter the password you set in Step 2.5
```

You should see:
```
pi@pi-guard:~ $
```

---

## 4. Install Pi Guard

### Step 4.1: Update System

```bash
sudo apt update && sudo apt upgrade -y
```

### Step 4.2: Install Git

```bash
sudo apt install -y git
```

### Step 4.3: Clone Pi Guard

```bash
git clone https://github.com/yourusername/pi-guard.git
cd pi-guard
```

### Step 4.4: Run Installer

```bash
sudo bash scripts/install.sh
```

**The installer will:**
1. Detect your hardware (Zero W vs 3A+ vs 3B+/4)
2. Install appropriate components
3. Configure all services
4. Disable telemetry
5. Set up monitoring
6. Display summary when complete

**Installation time:**
- Pi Zero W: ~30 minutes
- Pi 3A+: ~45 minutes
- Pi 3B+/4: ~60 minutes

### Step 4.5: Note Your Credentials

At the end, the installer shows:
```
Pi-hole admin password: [random password]
Dashboard URL: http://192.168.1.X/admin
```

**Write these down!**

---

## 5. Configure Alerts

### Step 5.1: Choose Alert Method

Pick one or more:
- **Telegram** (recommended) - Free, instant, easy setup
- **Discord** - Good for teams
- **Email** - Good for logging

### Step 5.2: Setup Telegram

**On your phone:**

1. Open Telegram app
2. Search for `@BotFather`
3. Send: `/newbot`
4. Name it: `Pi Guard Alerts`
5. Username: `YourNamePiGuardBot` (must end in "bot")
6. **Copy the token** (looks like `123456:ABC-xyz...`)
7. Start a chat with your new bot (click Start)
8. Open browser: `https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates`
9. **Copy your chat_id** (number like `123456789`)

**On your Pi:**

```bash
nano ~/.config/pi-guard/telegram.conf
```

Add:
```bash
BOT_TOKEN="123456:ABC-DEF1234ghIkl-xyz"
CHAT_ID="123456789"
```

Save: `Ctrl+X`, `Y`, `Enter`

**Test it:**
```bash
bash ~/pi-guard/cron/alerts/send-telegram.sh "Pi Guard test!"
```

### Step 5.3: Setup Discord (Optional)

1. Right-click Discord channel → Edit Channel
2. Integrations → Webhooks → New Webhook
3. Copy Webhook URL

```bash
nano ~/.config/pi-guard/discord.conf
```

Add:
```bash
WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

---

## 6. Harden SSH

After verifying everything works, switch to SSH keys.

### Step 6.1: Generate SSH Key (on your computer)

**Windows PowerShell:**
```powershell
ssh-keygen -t ed25519 -f $HOME\.ssh\pi-guard -N '""'
```

**Mac/Linux:**
```bash
ssh-keygen -t ed25519 -f ~/.ssh/pi-guard -N ""
```

### Step 6.2: Copy Key to Pi

```bash
ssh-copy-id -i ~/.ssh/pi-guard pi@pi-guard.local
```

### Step 6.3: Test Key Login

```bash
ssh -i ~/.ssh/pi-guard pi@pi-guard.local
# Should connect WITHOUT asking for password
```

### Step 6.4: Disable Password Authentication

**Only after confirming key login works!**

```bash
# On the Pi
sudo bash ~/pi-guard/scripts/harden-ssh.sh
```

This script:
- Disables password authentication
- Restricts SSH to `sshusers` group
- Adds your user to that group
- Restarts SSH

### Step 6.5: Update Your SSH Config (on your computer)

Create/edit `~/.ssh/config`:
```
Host pi-guard
    HostName pi-guard.local
    User pi
    IdentityFile ~/.ssh/pi-guard
```

Now connect with just:
```bash
ssh pi-guard
```

---

## 7. Verify Installation

```bash
bash ~/pi-guard/scripts/verify.sh
```

**Expected output:**
```
======================================
   Pi Guard System Verification
======================================

System Services:
  ✓ Pi-hole FTL is running
  ✓ Unbound is running
  ✓ fail2ban is running
  ✓ auditd is running
  ✓ arpwatch is running        (Pi 3A+ only)
  ✓ Snort is running           (Pi 3A+ only)

Network Tests:
  ✓ DNS resolution working
  ✓ DNS-over-TLS working
  ✓ Ad blocking working

Security Checks:
  ✓ Firewall active
  ✓ fail2ban SSH jail active
  ✓ SSH hardened

All checks passed!
```

---

## 8. Point Devices to Pi Guard

### Option A: Router-Level (Recommended)

This protects ALL devices on your network.

1. Open router admin page (usually 192.168.1.1)
2. Find "DHCP Settings" or "LAN Settings"
3. Change "DNS Server" to your Pi's IP
4. Save and reboot router

### Option B: Per-Device

**Windows:**
1. Settings → Network & Internet → Change adapter options
2. Right-click connection → Properties
3. Select "Internet Protocol Version 4" → Properties
4. "Use the following DNS server": Enter Pi's IP

**Mac:**
1. System Preferences → Network → Advanced → DNS
2. Add Pi's IP address

**iPhone/Android:**
1. WiFi settings → Your network → Configure DNS → Manual
2. Add Pi's IP address

### Option C: Verify It's Working

```bash
# On any device, open terminal/command prompt
nslookup google.com
```

Server should show your Pi's IP.

---

## Post-Installation

### Access Dashboards

| Dashboard | URL |
|-----------|-----|
| Pi-hole | `http://pi-guard.local/admin` |

### Daily Operations

Pi Guard runs automatically. Check on it occasionally:

```bash
# SSH in
ssh pi-guard

# Quick status
bash ~/pi-guard/scripts/verify.sh

# View today's stats
pihole -c

# Check for attacks
sudo fail2ban-client status sshd
```

### Updates

```bash
ssh pi-guard
cd ~/pi-guard
git pull
sudo bash scripts/update.sh
```

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

**Quick fixes:**

```bash
# Pi-hole not working
sudo systemctl restart pihole-FTL

# DNS not resolving
sudo systemctl restart unbound

# Check logs
sudo journalctl -u pihole-FTL -n 50
```

---

## Success!

You now have:
- ✅ DNS-level ad/malware blocking
- ✅ Encrypted DNS queries
- ✅ Firewall protection
- ✅ SSH attack prevention
- ✅ System audit logging
- ✅ Intrusion detection (Pi 3A+)
- ✅ ARP spoofing detection (Pi 3A+)
- ✅ Real-time alerts

**Cost:** €28-43 one-time, €0.15-0.30/month electricity

Welcome to proper network security! 🛡️
