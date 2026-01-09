# Quick Reference - One-Liner Commands

## Basic Usage (Interactive)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden.sh)
```

## Automated Usage (Non-Interactive)

### Minimal Setup
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh)
```

### Full Setup with All Options
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "subnet-router-01" \
  --subnets "192.168.1.0/24,192.168.100.0/24" \
  --remove-pi \
  --disable-ssh
```

### Setup Without Reboot (for testing)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "test-router" \
  --subnets "192.168.1.0/24" \
  --skip-reboot
```

### Setup for Zip World Sites
```bash
# Big Base Router
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "zipworld-bigbase-router" \
  --subnets "10.10.10.0/24" \
  --remove-pi \
  --disable-ssh

# Aero Router
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "zipworld-aero-router" \
  --subnets "10.20.20.0/24" \
  --remove-pi \
  --disable-ssh

# Big Top Router
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "zipworld-bigtop-router" \
  --subnets "10.30.30.0/24" \
  --remove-pi \
  --disable-ssh
```

## Available Options

| Option | Description | Example |
|--------|-------------|---------|
| `--hostname` | Set custom hostname | `--hostname "my-router"` |
| `--subnets` | Advertise subnet routes | `--subnets "192.168.1.0/24,10.0.0.0/8"` |
| `--disable-pi` | Lock the pi user | `--disable-pi` |
| `--remove-pi` | Delete pi user completely | `--remove-pi` |
| `--disable-ssh` | Disable local SSH | `--disable-ssh` |
| `--skip-reboot` | Don't reboot automatically | `--skip-reboot` |

## Pre-Installation Checklist

- [ ] Fresh Raspberry Pi OS Lite installation
- [ ] Device connected to network
- [ ] SSH or console access available
- [ ] Tailscale account created
- [ ] Know which subnets to route
- [ ] Backup any existing data

## Post-Installation Steps

1. **Authorize in Tailscale**
   - Go to https://login.tailscale.com/admin/machines
   - Find your new device
   - Authorize it

2. **Enable Subnet Routes**
   - Click on the device in Tailscale admin
   - Go to "Edit route settings"
   - Enable the advertised routes

3. **Test Access**
   ```bash
   # From another Tailscale device
   ssh username@hostname
   
   # Or use Tailscale IP
   ssh username@100.x.x.x
   ```

4. **Verify Routing**
   ```bash
   # On the router
   tailscale status
   ip route
   
   # From another Tailscale device
   ping <subnet-ip>
   ```

## Verification Commands

Run these on the router after setup:

```bash
# Check Tailscale status
tailscale status

# Verify IP forwarding
sysctl net.ipv4.ip_forward

# Check firewall rules
sudo nft list ruleset

# View active services
systemctl --type=service --state=running

# Check AppArmor status
sudo aa-status

# Fail2Ban status
sudo fail2ban-client status sshd

# Check for updates
apt list --upgradable
```

## Common Scenarios

### Home Network Router
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "home-router" \
  --subnets "192.168.1.0/24" \
  --disable-ssh
```

### Multiple VLANs
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "vlan-router" \
  --subnets "192.168.1.0/24,192.168.10.0/24,192.168.20.0/24" \
  --remove-pi \
  --disable-ssh
```

### Testing/Development (Don't disable SSH or reboot)
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "test-router" \
  --subnets "10.0.0.0/24" \
  --skip-reboot
```

### Site-to-Site VPN
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
  --hostname "site-a-router" \
  --subnets "10.10.0.0/16" \
  --remove-pi \
  --disable-ssh
```

## Troubleshooting One-Liners

```bash
# Check if Tailscale is running
sudo systemctl status tailscaled

# Restart Tailscale
sudo systemctl restart tailscaled

# View Tailscale logs
sudo journalctl -u tailscaled -f

# Check firewall is active
sudo systemctl status nftables

# Temporarily disable firewall (for debugging)
sudo systemctl stop nftables

# Re-enable firewall
sudo systemctl start nftables

# Check what's listening on network
sudo ss -tulpn

# View fail2ban logs
sudo tail -f /var/log/fail2ban.log

# Unban an IP from fail2ban
sudo fail2ban-client set sshd unbanip <IP_ADDRESS>
```

## Recovery One-Liners

```bash
# Re-enable local SSH (from console)
sudo systemctl start ssh
sudo systemctl enable ssh

# Reset firewall to allow all
sudo nft flush ruleset

# Disconnect from Tailscale
sudo tailscale down

# Remove Tailscale completely
sudo tailscale down
sudo apt remove tailscale -y

# Check system logs for errors
sudo journalctl -xe

# View boot messages
dmesg | tail -50
```

## Update Commands

```bash
# Update the script itself
bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh)

# Manual system updates
sudo apt update && sudo apt upgrade -y

# Check for security updates only
sudo unattended-upgrade --dry-run -d

# Force security updates now
sudo unattended-upgrade -d
```

## Integration with Ansible

You can call this script from Ansible for fleet deployment:

```yaml
---
- name: Harden Raspberry Pi Fleet
  hosts: pi_routers
  tasks:
    - name: Download and run hardening script
      shell: |
        bash <(curl -fsSL https://raw.githubusercontent.com/jonzipworld/TailScale-Raspberry-Pi-Harden/main/rpi-harden-auto.sh) \
          --hostname "{{ inventory_hostname }}" \
          --subnets "{{ tailscale_subnets }}" \
          --remove-pi \
          --disable-ssh \
          --skip-reboot
      args:
        executable: /bin/bash
    
    - name: Reboot after hardening
      reboot:
        reboot_timeout: 300
```

## GitHub Setup

1. Create a new repository
2. Add the scripts:
   ```bash
   git init
   git add rpi-harden.sh rpi-harden-auto.sh README.md
   git commit -m "Initial commit"
   git branch -M main
   git remote add origin https://github.com/jonzipworld/TailScale-Raspberry-Pi-Harden.git
   git push -u origin main
   ```

3. Update the raw URLs in the scripts:
   - Replace `YOUR_USERNAME` with your GitHub username
   - Replace `YOUR_REPO` with your repository name

4. Make scripts executable in GitHub:
   - No special action needed - curl will handle it

## Security Notes

- **Always test in a non-production environment first**
- **Verify Tailscale SSH works before disabling local SSH**
- **Keep a backup of working configuration**
- **Document any customizations you make**
- **Review firewall rules before going to production**
- **Monitor logs regularly: `sudo journalctl -f`**
