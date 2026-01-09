# Raspberry Pi Hardening Script

Automated hardening script for Raspberry Pi OS Lite configured as a Tailscale subnet router.

## Quick Start

Run directly from GitHub (one-liner):

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/rpi-harden.sh)
```

## What It Does

This script implements the following security hardening measures:

1. **System Updates** - Full system upgrade
2. **Hostname Configuration** - Optional custom hostname
3. **User Management** - Create dedicated admin user, disable/remove default pi user
4. **Service Reduction** - Disable unnecessary services (avahi, bluetooth, cups, triggerhappy)
5. **Tailscale Installation** - Install and configure Tailscale with SSH and subnet routing
6. **Firewall (nftables)** - Configure strict firewall allowing only Tailscale traffic
7. **Fail2Ban** - Protect against brute force attacks
8. **Filesystem Hardening** - Secure tmpfs mounts with noexec, nosuid, nodev
9. **AppArmor** - Enable mandatory access control
10. **Automatic Updates** - Configure unattended security updates
11. **SSH Lockdown** - Optional: disable local SSH (Tailscale SSH only)

## Prerequisites

- Fresh Raspberry Pi OS Lite (64-bit recommended)
- Initial SSH or console access
- sudo privileges
- Internet connection

## Usage

### Method 1: One-Liner (Recommended)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/rpi-harden.sh)
```

### Method 2: Download and Run

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/rpi-harden.sh -o rpi-harden.sh
chmod +x rpi-harden.sh
./rpi-harden.sh
```

### Method 3: Clone Repository

```bash
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
chmod +x rpi-harden.sh
./rpi-harden.sh
```

## Interactive Prompts

The script will prompt you for:

- **Hostname**: Set custom hostname (default: tailscale-router)
- **Admin User**: Create dedicated admin user
- **Pi User**: Disable or remove default pi user
- **Subnet Routes**: Specify subnet routes for Tailscale (e.g., `192.168.1.0/24,192.168.2.0/24`)
- **SSH Lockdown**: Disable local SSH after verifying Tailscale SSH works

## Example Run

```bash
# Run the script
bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/rpi-harden.sh)

# When prompted for subnet routes:
192.168.1.0/24,192.168.100.0/24

# Authorize in Tailscale admin console
# Test Tailscale SSH access
# Continue with script
```

## Post-Installation

### Verify Installation

```bash
# Check Tailscale status
tailscale status

# Check firewall rules
sudo nft list ruleset

# Check IP forwarding
sudo sysctl net.ipv4.ip_forward

# Check AppArmor
sudo aa-status

# Check Fail2Ban
sudo fail2ban-client status
```

### Access via Tailscale SSH

```bash
# From another Tailscale device
ssh username@tailscale-hostname

# Or use Tailscale IP
ssh username@100.x.x.x
```

### Enable Subnet Routing in Tailscale Admin

1. Go to Tailscale admin console
2. Navigate to your device
3. Enable "Subnet routes" toggle
4. Approve the advertised routes

## Operational Notes

- **Do not install additional services** without reviewing firewall rules
- **All changes require firewall and ACL review**
- **Revoke node immediately if compromise suspected**
- Access only via Tailscale SSH after local SSH is disabled

## Recovery

If the device is compromised:

1. Disable subnet routing in Tailscale admin console
2. Revoke device key
3. Reflash OS
4. Re-run this hardening script

## Configuration Files

The script creates/modifies:

- `/etc/nftables.conf` - Firewall rules
- `/etc/fail2ban/jail.local` - Fail2Ban SSH jail
- `/etc/fstab` - Secure mount options
- `/etc/sysctl.d/99-tailscale.conf` - IP forwarding
- `/etc/apt/apt.conf.d/51myunattended-upgrades` - Update settings

## Security Features

### Network Security
- Firewall blocks all traffic except Tailscale
- IP forwarding only for subnet routing
- Fail2Ban protection against brute force
- Local SSH optionally disabled

### System Security
- Minimal services running
- AppArmor mandatory access control
- Secure tmpfs mounts (noexec, nosuid, nodev)
- Automatic security updates
- No default pi user

### Access Control
- Tailscale ACLs control access
- SSH only via Tailscale network
- Dedicated admin user (optional)

## Customization

### Modify Firewall Rules

Edit `/etc/nftables.conf` and reload:

```bash
sudo nano /etc/nftables.conf
sudo nft -f /etc/nftables.conf
```

### Add More Subnet Routes

```bash
sudo tailscale set --advertise-routes=192.168.1.0/24,192.168.2.0/24
```

### Adjust Fail2Ban Settings

```bash
sudo nano /etc/fail2ban/jail.local
sudo systemctl restart fail2ban
```

## Troubleshooting

### Can't Access After Script

- Ensure Tailscale is running: `sudo tailscale status`
- Check if local SSH was disabled
- Use console access if needed
- Verify Tailscale SSH is enabled in admin console

### Subnet Routing Not Working

- Verify IP forwarding: `sysctl net.ipv4.ip_forward`
- Check firewall allows forwarding: `sudo nft list ruleset`
- Enable subnet routes in Tailscale admin console
- Verify routes: `tailscale status`

### Firewall Blocking Legitimate Traffic

- Check nftables rules: `sudo nft list ruleset`
- Review logs: `sudo journalctl -u nftables`
- Temporarily disable to test: `sudo systemctl stop nftables`

## License

MIT License - Feel free to modify and distribute

## Contributing

Pull requests welcome! Please test thoroughly before submitting.

## Support

For issues or questions:
- Check the troubleshooting section
- Review Tailscale documentation: https://tailscale.com/kb/
- Open an issue on GitHub
