# Troubleshooting Guide

Common problems and solutions.

---

## Can't Find Pi on Network

### Check Power
- Red LED should be on (power)
- Green LED should blink (activity)
- Use proper power supply (5V 2.5A for Pi 3A+)

### Check Network
```bash
# Scan your network
nmap -sn 192.168.1.0/24 | grep -i raspberry

# Or use hostname
ping pi-guard.local
```

### Re-flash SD Card
If Pi won't boot, re-flash with Raspberry Pi Imager. Make sure to enable SSH in settings.

---

## SSH Connection Refused

### Wait for Boot
First boot takes 2-3 minutes. Wait for green LED to stop constant blinking.

### Verify SSH Enabled
When flashing, you MUST enable SSH in Raspberry Pi Imager settings.

### Check IP Address
```bash
# Pi's IP may have changed
nmap -sn 192.168.1.0/24
```

---

## Pi-hole Not Blocking

### Check Service
```bash
sudo systemctl status pihole-FTL
# If not running:
sudo systemctl restart pihole-FTL
```

### Check DNS Settings
Your devices must use Pi's IP for DNS:
```bash
# On any device
nslookup google.com
# Server should show Pi's IP
```

### Clear Cache
```bash
# Clear DNS cache on Pi
pihole restartdns

# On Windows: ipconfig /flushdns
# On Mac: sudo dscacheutil -flushcache
```

---

## DNS Not Resolving

### Check Unbound
```bash
# Test Unbound directly
dig @127.0.0.1 -p 5335 google.com

# If fails, restart
sudo systemctl restart unbound

# Check logs
sudo journalctl -u unbound -n 50
```

### Check Internet
```bash
ping 1.1.1.1
```

---

## Snort Not Running

### Check Status
```bash
sudo systemctl status snort
sudo journalctl -u snort -n 100
```

### Memory Issues
```bash
# Check memory
free -m

# Check for OOM kills
dmesg | grep -i "out of memory"
```

If memory issues, tune rules (see SNORT-TUNING.md).

### Start Manually
```bash
sudo systemctl start snort
```

---

## Alerts Not Sending

### Check Config
```bash
cat ~/.config/pi-guard/telegram.conf
# Should show BOT_TOKEN and CHAT_ID
```

### Test Directly
```bash
# Verbose output
bash -x ~/pi-guard/cron/alerts/send-telegram.sh "test"
```

### Check Internet
```bash
curl https://api.telegram.org
```

---

## High Memory Usage

### Check What's Using Memory
```bash
ps aux --sort=-%mem | head -10
```

### Free Memory
```bash
# Clear caches
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches

# Check zram
swapon --show
```

### Reduce Pi-hole Cache
```bash
# Edit config
sudo nano /etc/pihole/pihole-FTL.conf
# Add: MAXDBDAYS=3

sudo systemctl restart pihole-FTL
```

---

## SD Card Full

```bash
# Check usage
df -h

# Clean package cache
sudo apt clean
sudo apt autoremove -y

# Reduce log retention
sudo journalctl --vacuum-size=50M

# Delete old logs
sudo rm /var/log/*.gz
sudo rm /var/log/pi-guard/*.log.*
```

---

## fail2ban Not Banning

### Check Jail
```bash
sudo fail2ban-client status sshd
```

### Check Logs
```bash
# fail2ban watches auth.log
tail /var/log/auth.log
```

### Test Regex
```bash
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf
```

---

## Services Keep Stopping

### Check Logs
```bash
sudo journalctl -u <service-name> -n 100
```

### Check Memory
Services crash when memory exhausted:
```bash
dmesg | grep -i oom
```

### Restart All
```bash
sudo systemctl restart pihole-FTL
sudo systemctl restart unbound
sudo systemctl restart fail2ban
```

---

## Complete Reset

If all else fails:

```bash
# Re-run installation
cd ~/pi-guard
sudo bash scripts/install.sh

# Or just specific components
pihole -r  # Repair Pi-hole
```

---

## Getting Help

1. Check this guide
2. Search [GitHub Issues](https://github.com/yourusername/pi-guard/issues)
3. Create new issue with:
   - What you tried
   - What happened
   - Output of `bash ~/pi-guard/scripts/verify.sh`
