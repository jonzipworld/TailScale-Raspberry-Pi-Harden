# Quick Setup Guide for Jon

## Repository Setup

Your GitHub repository: **jonzipworld/TailScale-Raspberry-Pi-Harden**

### Initial Setup

```bash
# Create the repository on GitHub first, then:
cd ~/Downloads  # or wherever you want to work
mkdir TailScale-Raspberry-Pi-Harden
cd TailScale-Raspberry-Pi-Harden

# Copy the files (or download from Claude)
# Then initialize git
git init
git add .
git commit -m "Initial commit: Raspberry Pi hardening scripts"
git branch -M main
git remote add origin https://github.com/jonzipworld/TailScale-Raspberry-Pi-Harden.git
git push -u origin main
```

## Your One-Liners (Ready to Use!)

### Interactive Mode (with prompts)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden.sh)
```

### Automated Mode (no prompts)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh)
```

## Zip World Deployment Examples

### Big Base Router
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "zipworld-bigbase-router" \
  --subnets "10.10.10.0/24" \
  --remove-pi \
  --disable-ssh
```

### Aero Router
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "zipworld-aero-router" \
  --subnets "10.20.20.0/24" \
  --remove-pi \
  --disable-ssh
```

### Big Top Router
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "zipworld-bigtop-router" \
  --subnets "10.30.30.0/24" \
  --remove-pi \
  --disable-ssh
```

### Testing Configuration (keeps SSH, no reboot)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "test-router" \
  --subnets "192.168.1.0/24" \
  --skip-reboot
```

## Integration with Your Ansible Setup

Since you're already using Ansible for Zip World, you can add this to your playbook:

```yaml
---
- name: Harden Zip World Raspberry Pi Routers
  hosts: zipworld_routers
  become: yes
  vars:
    hardening_script_url: "https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh"
  
  tasks:
    - name: Run hardening script
      shell: |
        bash <(curl -fsSL {{ hardening_script_url }}) \
          --hostname "{{ inventory_hostname }}" \
          --subnets "{{ tailscale_subnets }}" \
          --remove-pi \
          --disable-ssh \
          --skip-reboot
      args:
        executable: /bin/bash
      register: hardening_result
    
    - name: Display hardening results
      debug:
        var: hardening_result.stdout_lines
    
    - name: Reboot router
      reboot:
        reboot_timeout: 300
      when: hardening_result.rc == 0

- name: Verify Tailscale connectivity
  hosts: zipworld_routers
  tasks:
    - name: Check Tailscale status
      command: tailscale status
      register: ts_status
    
    - name: Display status
      debug:
        var: ts_status.stdout_lines
```

## Inventory Example

```yaml
# inventory/zipworld_routers.yml
all:
  children:
    zipworld_routers:
      hosts:
        zipworld-bigbase-router:
          ansible_host: 192.168.1.10
          tailscale_subnets: "10.10.10.0/24"
        
        zipworld-aero-router:
          ansible_host: 192.168.2.10
          tailscale_subnets: "10.20.20.0/24"
        
        zipworld-bigtop-router:
          ansible_host: 192.168.3.10
          tailscale_subnets: "10.30.30.0/24"
```

## Node-RED Integration

You could also trigger deployments from Node-RED if you wanted:

```javascript
// In a Node-RED exec node
const hostname = msg.payload.hostname;
const subnets = msg.payload.subnets;

const cmd = `bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) --hostname "${hostname}" --subnets "${subnets}" --remove-pi --disable-ssh`;

msg.payload = cmd;
return msg;
```

## Pre-Deployment Checklist for Zip World Sites

- [ ] Fresh Raspberry Pi OS Lite installed (use Raspberry Pi Imager)
- [ ] Initial admin user created (not using default 'pi')
- [ ] Connected to site network
- [ ] Know the subnet CIDR (e.g., 10.10.10.0/24)
- [ ] Tailscale account ready
- [ ] Test Pi available for validation first
- [ ] Backup of existing router config (if replacing)
- [ ] Site contact available during deployment
- [ ] Weather monitoring dashboards updated with new router IP

## Post-Deployment Verification

```bash
# SSH via Tailscale to the new router
ssh jon@zipworld-bigbase-router

# Or use Tailscale IP
ssh jon@100.x.x.x

# Run verification checks
tailscale status
sudo nft list ruleset | grep -A 20 "chain input"
sudo sysctl net.ipv4.ip_forward
systemctl --type=service --state=running
sudo fail2ban-client status
```

## Integration with Your Weather Dashboards

After deployment, update your weather monitoring to use the Tailscale network:

```javascript
// In your Node-RED flow for weather stations
const tailscaleIP = "100.64.x.x"; // Get from tailscale status
const weatherAPI = `http://${tailscaleIP}/api/weather`;

// Now accessible from anywhere on Tailscale network
```

## Monitoring

Add to your existing Node-RED monitoring:

```javascript
// Check router health
const routers = [
    { name: "Big Base", host: "zipworld-bigbase-router" },
    { name: "Aero", host: "zipworld-aero-router" },
    { name: "Big Top", host: "zipworld-bigtop-router" }
];

// Ping check via Tailscale
// Monitor uptime
// Check subnet routing
```

## Troubleshooting During Seasonal Closures

When sites are closed and you need access:

```bash
# All access via Tailscale - works remotely
ssh jon@zipworld-bigbase-router

# Check if router is online
tailscale status | grep bigbase

# Restart services remotely if needed
sudo systemctl restart tailscaled

# Check logs
sudo journalctl -u tailscaled -n 100
```

## Backup Strategy

```bash
# Create backup script for router configs
#!/bin/bash
for router in bigbase aero bigtop; do
    ssh jon@zipworld-${router}-router "
        sudo tar czf /tmp/${router}-backup.tar.gz \
            /etc/nftables.conf \
            /etc/fail2ban/jail.local \
            /etc/tailscale/ \
            /etc/fstab
    "
    scp jon@zipworld-${router}-router:/tmp/${router}-backup.tar.gz ./backups/
done
```

## Update Strategy

```bash
# Update all routers at once
for router in bigbase aero bigtop; do
    ssh jon@zipworld-${router}-router "
        sudo apt update && sudo apt upgrade -y
        sudo reboot
    "
done
```

## Files to Add to Repository

1. `rpi-harden.sh` - Interactive version ✓
2. `rpi-harden-auto.sh` - Automated version ✓
3. `README.md` - Full documentation ✓
4. `QUICK_REFERENCE.md` - One-liner examples ✓
5. `LICENSE` - MIT or your choice
6. `.gitignore` - Standard for shell projects

### Suggested .gitignore

```
# Backup files
*.backup
*.bak
*~

# Logs
*.log

# Temporary files
tmp/
temp/

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*.swo
```

## Quick Commands for You

```bash
# Test on a fresh Pi
ssh pi@192.168.1.100
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) --skip-reboot

# Deploy to production
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "zipworld-bigbase-router" \
  --subnets "10.10.10.0/24" \
  --remove-pi \
  --disable-ssh

# Check status from your main machine
tailscale status
ping 100.x.x.x
```

## Notes for Your Setup

- Works perfectly with your Node-RED flows
- Integrates with Home Assistant if needed
- Compatible with your vMix automation systems
- Supports your multi-site seasonal operations
- Can be monitored via your existing dashboards
- Pairs well with your Ansible automation
