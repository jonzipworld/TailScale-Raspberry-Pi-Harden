#!/bin/bash
set -euo pipefail

# Raspberry Pi Hardening Script - Non-Interactive Version
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/rpi-harden-auto.sh) [OPTIONS]
# Options:
#   --hostname HOSTNAME          Set hostname (default: tailscale-router)
#   --subnets ROUTES             Comma-separated subnet routes (e.g., 192.168.1.0/24,192.168.2.0/24)
#   --disable-pi                 Disable (lock) pi user
#   --remove-pi                  Remove pi user completely
#   --disable-ssh                Disable local SSH after Tailscale setup
#   --skip-reboot                Don't reboot after completion

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Defaults
HOSTNAME="tailscale-router"
SUBNET_ROUTES=""
DISABLE_PI=false
REMOVE_PI=false
DISABLE_SSH=false
SKIP_REBOOT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        --subnets)
            SUBNET_ROUTES="$2"
            shift 2
            ;;
        --disable-pi)
            DISABLE_PI=true
            shift
            ;;
        --remove-pi)
            REMOVE_PI=true
            DISABLE_PI=true
            shift
            ;;
        --disable-ssh)
            DISABLE_SSH=true
            shift
            ;;
        --skip-reboot)
            SKIP_REBOOT=true
            shift
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Check if running as root
[ "$EUID" -eq 0 ] && error "Run as regular user with sudo privileges, not root"

# Check for sudo
command -v sudo &> /dev/null || error "sudo not installed"

echo "========================================"
echo "Raspberry Pi Hardening - Automated Mode"
echo "========================================"
echo ""

# 1. Update System
log "Updating system..."
sudo apt update && sudo apt full-upgrade -y

# 2. Set Hostname
log "Setting hostname to $HOSTNAME..."
sudo hostnamectl set-hostname "$HOSTNAME"
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
grep -q "127.0.1.1" /etc/hosts || echo "127.0.1.1	$HOSTNAME" | sudo tee -a /etc/hosts

# 3. User Management
if [ "$DISABLE_PI" = true ] && id "pi" &>/dev/null; then
    log "Disabling pi user..."
    sudo passwd -l pi
    
    if [ "$REMOVE_PI" = true ]; then
        log "Removing pi user..."
        sudo deluser --remove-home pi || warn "Failed to remove pi user"
    fi
fi

# 4. Disable Services
log "Disabling unnecessary services..."
for service in avahi-daemon bluetooth cups triggerhappy; do
    sudo systemctl disable "$service" 2>/dev/null || true
    sudo systemctl stop "$service" 2>/dev/null || true
done

for socket in avahi-daemon.socket cups.socket cups.path; do
    sudo systemctl disable "$socket" 2>/dev/null || true
    sudo systemctl stop "$socket" 2>/dev/null || true
done

# 5. Install Tailscale
log "Installing Tailscale..."
command -v tailscale &> /dev/null || curl -fsSL https://tailscale.com/install.sh | sh

log "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

log "Starting Tailscale..."
if [ -n "$SUBNET_ROUTES" ]; then
    sudo tailscale up --ssh --advertise-routes="$SUBNET_ROUTES" --accept-routes || \
        warn "Tailscale up failed - may need authorization"
else
    sudo tailscale up --ssh --accept-routes || warn "Tailscale up failed - may need authorization"
fi

# 6. nftables Firewall
log "Installing and configuring nftables..."
sudo apt install nftables -y
sudo systemctl enable nftables

sudo tee /etc/nftables.conf > /dev/null <<'EOF'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        iif lo accept
        ct state established,related accept
        iifname "tailscale0" accept
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        log prefix "nftables-drop: " drop
    }
    chain forward {
        type filter hook forward priority 0; policy drop;
        iifname "tailscale0" accept
        oifname "tailscale0" ct state established,related accept
        ct state established,related accept
    }
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

sudo nft -f /etc/nftables.conf
sudo systemctl restart nftables

# 7. Fail2Ban
log "Installing Fail2Ban..."
sudo apt install fail2ban -y

sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[sshd]
enabled = true
bantime = 1h
findtime = 10m
maxretry = 5
EOF

sudo systemctl enable --now fail2ban

# 8. Filesystem Hardening
log "Hardening filesystem..."
grep -q "tmpfs /tmp" /etc/fstab || \
    echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" | sudo tee -a /etc/fstab
grep -q "tmpfs /var/tmp" /etc/fstab || \
    echo "tmpfs /var/tmp tmpfs defaults,noexec,nosuid,nodev 0 0" | sudo tee -a /etc/fstab
sudo mount -a

# 9. AppArmor
log "Enabling AppArmor..."
sudo apt install apparmor apparmor-utils -y
sudo systemctl enable apparmor
sudo systemctl start apparmor

# 10. Automatic Updates
log "Configuring automatic updates..."
sudo apt install unattended-upgrades -y
echo 'Unattended-Upgrade::Automatic-Reboot "false";' | \
    sudo tee /etc/apt/apt.conf.d/51myunattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# 11. Disable SSH (optional)
if [ "$DISABLE_SSH" = true ]; then
    log "Disabling local SSH..."
    sudo systemctl disable ssh
    sudo systemctl stop ssh
fi

# Verification
log "Verification:"
tailscale status || warn "Tailscale not connected - authorize in admin console"
sudo sysctl net.ipv4.ip_forward
sudo nft list ruleset | head -20

# Complete
echo ""
log "========================================="
log "✓ Hardening Complete!"
log "========================================="
echo ""
log "Configuration:"
log "  Hostname: $HOSTNAME"
log "  Subnet Routes: ${SUBNET_ROUTES:-none}"
log "  Pi User: $([ "$DISABLE_PI" = true ] && echo "disabled" || echo "active")"
log "  Local SSH: $([ "$DISABLE_SSH" = true ] && echo "disabled" || echo "active")"
echo ""
warn "Next steps:"
warn "  1. Authorize device in Tailscale admin console"
warn "  2. Enable subnet routes in Tailscale admin"
warn "  3. Test Tailscale SSH access"
warn "  4. $([ "$SKIP_REBOOT" = true ] && echo "Reboot when ready: sudo reboot" || echo "System will reboot...")"
echo ""

if [ "$SKIP_REBOOT" = false ]; then
    sleep 5
    sudo reboot
fi
