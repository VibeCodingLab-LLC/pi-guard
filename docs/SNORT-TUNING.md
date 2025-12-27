# Snort IDS Tuning Guide

**Optimizing Snort 3 for Raspberry Pi 3A+ (512MB RAM)**

---

## Why Tuning Matters

Running Snort on 512MB RAM is like putting a V8 engine in a lawnmower. Without tuning:
- **Alert fatigue** - 50 alerts/day where 49 are false positives
- **Memory exhaustion** - OOM kills Snort, leaving you blind
- **CPU overload** - Pi becomes unresponsive

The goal: **Minimum Viable Detection** - catch real threats, ignore noise.

---

## Step 1: Find Your Top Alerts

After running Snort for a few days, identify your noisiest rules:

```bash
# Top 10 most frequent alerts
grep "Priority:" /var/log/snort/alert | \
    cut -d'[' -f2 | cut -d']' -f1 | \
    sort | uniq -c | sort -nr | head -10
```

Example output:
```
   1523 1:1917:0    <- SSDP discovery (Chromecasts)
    847 1:2103:0    <- SMB negotiate (Windows file sharing)
    234 1:384:0     <- ICMP unreachable (normal)
     45 1:2000001:0 <- Actual concern
```

The first three are **false positives** - normal home network traffic.

---

## Step 2: Suppress False Positives

Edit `/etc/snort/threshold.conf`:

```bash
sudo nano /etc/snort/threshold.conf
```

Add suppression rules for your noisy alerts:

```
# Suppress by SID (signature ID)
suppress gen_id 1, sig_id 1917    # SSDP (Chromecasts)
suppress gen_id 1, sig_id 2103    # SMB negotiate
suppress gen_id 1, sig_id 384     # ICMP unreachable

# Suppress by source IP (your trusted devices)
suppress gen_id 1, sig_id 0, track by_src, ip 192.168.1.1    # Router
suppress gen_id 1, sig_id 0, track by_src, ip 192.168.1.50   # NAS
```

---

## Step 3: Disable Heavy Rule Categories

Edit `/etc/snort/snort.lua` and disable irrelevant categories:

**Categories to DISABLE for home networks:**
- `protocol-icmp` - Pings are normal
- `policy-social` - Social media policies (irrelevant)
- `info-leak` - Information disclosure (noisy)
- `policy-other` - Various policies (noisy)

**Categories to KEEP:**
- `malware-cnc` - Command & control (critical!)
- `exploit-kit` - Browser exploits (important)
- `indicator-shellcode` - Shell code (important)
- `server-webapp` - Web attacks (if you host anything)

---

## Step 4: Monitor Memory Usage

```bash
# Watch memory while Snort runs
htop

# Check Snort memory specifically
ps aux | grep snort | awk '{print $6/1024 "MB"}'
```

If memory is consistently >250MB, you need to strip more rules.

---

## Step 5: Rate Limiting

Add rate limits to prevent alert floods. Edit `/etc/snort/threshold.conf`:

```
# Limit SSH alerts to 5 per minute per source
event_filter gen_id 1, sig_id 0, type limit, track by_src, count 5, seconds 60

# Limit port scan alerts
event_filter gen_id 122, sig_id 0, type limit, track by_src, count 3, seconds 60
```

---

## Step 6: Verify Snort is Running

```bash
# Check status
sudo systemctl status snort

# Check for OOM kills
sudo dmesg | grep -i "out of memory"

# Check alert file is being written
ls -la /var/log/snort/alert

# Watch alerts in real-time
sudo tail -f /var/log/snort/alert
```

---

## Recommended Pi 3A+ Settings

The Pi Guard install already configures these, but verify:

**systemd limits** (`/etc/systemd/system/snort.service`):
```ini
[Service]
MemoryMax=300M      # Hard memory limit
CPUQuota=50%        # Don't starve other services
```

**Snort config** (`/etc/snort/snort.lua`):
```lua
stream = {
    max_flows = 8192,           # Reduced from 64k
}
stream_tcp = {
    max_queued_bytes = 1048576, # 1MB instead of 8MB
}
```

---

## Common False Positive Sources

| Device | Alert Type | Action |
|--------|------------|--------|
| Chromecast/Smart TV | SSDP discovery | Suppress SID 1917/1918 |
| Windows PCs | SMB/NetBIOS | Suppress SID 2103, 2465 |
| Apple devices | mDNS/Bonjour | Suppress SID 23756 |
| IoT devices | Various probes | Suppress by IP |
| Router | ICMP | Suppress SID 384/385 |

---

## Testing Detection

Trigger a test alert to verify Snort is working:

```bash
# Generate test traffic (from another device)
nmap -sS -p 1-100 YOUR_PI_IP

# Check for alerts
grep "scan" /var/log/snort/alert
```

---

## When to Run Snort

Options:

**1. Always On (recommended if stable)**
```bash
sudo systemctl enable snort
sudo systemctl start snort
```

**2. Scheduled (reduce load)**
```bash
# Run 6 hours/day (add to crontab)
0 18 * * * systemctl start snort
0 0 * * * systemctl stop snort
```

**3. Manual (troubleshooting)**
```bash
sudo systemctl start snort
# ... investigate ...
sudo systemctl stop snort
```

---

## Troubleshooting

### Snort keeps crashing
```bash
# Check logs
sudo journalctl -u snort -n 100

# Check for OOM
sudo dmesg | grep -i oom

# Solution: Strip more rules or increase zram
```

### Too many alerts
```bash
# Find noisy rules
grep "Priority:" /var/log/snort/alert | cut -d'[' -f2 | cut -d']' -f1 | sort | uniq -c | sort -nr | head

# Suppress them
echo "suppress gen_id 1, sig_id XXXX" >> /etc/snort/threshold.conf
sudo systemctl restart snort
```

### No alerts at all
```bash
# Check Snort is seeing traffic
sudo snort -c /etc/snort/snort.lua -i eth0 -A console

# Check interface
ip link show
```

---

## Summary

1. **Run for a few days** - Collect baseline alerts
2. **Identify noise** - Top 10 alert query
3. **Suppress false positives** - threshold.conf
4. **Monitor memory** - Keep under 300MB
5. **Watch for real threats** - Priority 1 alerts matter

Your goal: **Alert on wolves, not sheep.**
