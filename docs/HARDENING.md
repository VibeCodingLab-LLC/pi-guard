# Advanced Hardening Guide

Extra security measures beyond the default installation.

---

## SSH Key-Only Authentication

Already covered in DEPLOYMENT.md, but critical:

```bash
# Generate key (on your computer)
ssh-keygen -t ed25519 -f ~/.ssh/pi-guard

# Copy to Pi
ssh-copy-id -i ~/.ssh/pi-guard pi@pi-guard.local

# Test key login
ssh -i ~/.ssh/pi-guard pi@pi-guard.local

# THEN disable passwords
sudo bash ~/pi-guard/scripts/harden-ssh.sh
```

---

## Change SSH Port

Reduces automated attacks:

```bash
# Edit SSH config
sudo nano /etc/ssh/sshd_config
# Change: Port 2222

# Update firewall
sudo iptables -A INPUT -p tcp --dport 2222 -j ACCEPT
sudo netfilter-persistent save

# Restart SSH
sudo systemctl restart sshd
```

Connect with: `ssh -p 2222 pi@pi-guard.local`

---

## Honeypot (Advanced)

Set up a fake SSH on port 22 while real SSH runs on another port:

```bash
# Install Cowrie (lightweight honeypot)
sudo apt install -y python3-virtualenv

cd /opt
sudo git clone https://github.com/cowrie/cowrie.git
cd cowrie
sudo virtualenv cowrie-env
source cowrie-env/bin/activate
pip install -r requirements.txt

# Configure to run on port 22
# (Move real SSH to port 2222 first!)
```

---

## Restrict Service Management

Prevent unauthorized service control:

```bash
# Only allow root to manage services
sudo chmod 700 /usr/bin/systemctl
```

---

## Audit Configuration

### Enable Immutable Rules

After verifying audit rules work, make them immutable:

```bash
sudo nano /etc/audit/rules.d/pi-guard.rules
# Uncomment last line: -e 2

# Reboot to apply
sudo reboot
```

Now rules can't be changed without reboot.

### Review Audit Logs

```bash
# Authentication events
sudo ausearch -k auth

# SSH changes
sudo ausearch -k ssh_config

# Pi-hole config changes
sudo ausearch -k pihole_config

# Privilege escalation
sudo ausearch -k exec_sudo
```

---

## USB Device Protection

Disable USB storage to prevent data theft:

```bash
echo "blacklist usb-storage" | sudo tee /etc/modprobe.d/usb-storage.conf
```

---

## Network Segmentation

If your router supports VLANs:

1. Put Pi Guard on dedicated VLAN
2. Allow only DNS (port 53) from other VLANs
3. Allow SSH only from management VLAN
4. Block all other traffic

---

## Automatic Updates

Already enabled by install script, but verify:

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades
# Should show:
# APT::Periodic::Update-Package-Lists "1";
# APT::Periodic::Unattended-Upgrade "1";
```

---

## Rootkit Detection

```bash
# Install rkhunter
sudo apt install -y rkhunter

# Update database
sudo rkhunter --update

# Run scan
sudo rkhunter --check --skip-keypress
```

Add to weekly cron:
```bash
0 3 * * 0 /usr/bin/rkhunter --check --skip-keypress --report-warnings-only
```

---

## File Integrity Monitoring

```bash
# Install AIDE
sudo apt install -y aide

# Initialize database
sudo aideinit

# Check for changes
sudo aide --check
```

---

## Centralized Logging

Send logs to remote server:

```bash
sudo nano /etc/rsyslog.conf
# Add:
*.* @192.168.1.200:514

sudo systemctl restart rsyslog
```

---

## Backup Strategy

### Automated Backups

```bash
cat > ~/backup-pi-guard.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/home/pi/backups"
DATE=$(date +%Y%m%d)
mkdir -p $BACKUP_DIR

# Backup configs
tar -czf $BACKUP_DIR/pi-guard-$DATE.tar.gz \
    /etc/pihole \
    /etc/unbound \
    /etc/fail2ban \
    /etc/ssh \
    /etc/snort \
    ~/.config/pi-guard

# Keep 7 days
find $BACKUP_DIR -mtime +7 -delete

echo "Backup complete: $BACKUP_DIR/pi-guard-$DATE.tar.gz"
EOF

chmod +x ~/backup-pi-guard.sh

# Add to cron (weekly)
echo "0 2 * * 0 /home/pi/backup-pi-guard.sh" | sudo tee -a /var/spool/cron/crontabs/root
```

### Off-site Copy

```bash
# From your computer
scp -r pi@pi-guard.local:~/backups ./pi-guard-backups/
```

---

## Security Checklist

Run through periodically:

- [ ] SSH keys working, passwords disabled
- [ ] SSH on non-standard port (optional)
- [ ] fail2ban active with bans
- [ ] Firewall rules reviewed
- [ ] Audit logs checked
- [ ] No unknown services running
- [ ] Backups working
- [ ] All services running (verify.sh)
- [ ] No unknown devices on network
- [ ] Pi-hole blocklists updated
- [ ] Snort rules tuned (if running)

---

## Monthly Review

```bash
# Check for rootkits
sudo rkhunter --check

# Review login attempts
sudo lastb | head -20

# Review sudo usage
sudo ausearch -k exec_sudo | tail -50

# Check open ports
sudo ss -tulpn

# Review firewall logs
grep "IPTables-Dropped" /var/log/syslog | tail -20
```
