#!/bin/bash
set -euo pipefail

# Raspberry Pi Hardening Script
# Based on Raspberry Pi Hardening Manual
# Usage: bash <(curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/rpi-harden.sh)

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

prompt() {
    echo -e "${YELLOW}[INPUT]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Please run as regular user with sudo privileges, not as root"
fi

# Check for sudo
if ! command -v sudo &> /dev/null; then
    error "sudo is not installed"
fi

echo "=================================="
echo "Raspberry Pi Hardening Script"
echo "=================================="
echo ""

# ==========================================
# 1. Initial OS Preparation
# ==========================================
log "Step 1: Updating system firmware and packages..."
sudo apt update
sudo apt full-upgrade -y

# ==========================================
# 2. Set Hostname
# ==========================================
prompt "Set hostname? (y/n) [default: n]"
read -r SET_HOSTNAME
if [[ "$SET_HOSTNAME" == "y" ]]; then
    prompt "Enter hostname [default: tailscale-router]:"
    read -r HOSTNAME
    HOSTNAME=${HOSTNAME:-tailscale-router}
    
    log "Setting hostname to $HOSTNAME..."
    sudo hostnamectl set-hostname "$HOSTNAME"
    
    log "Updating /etc/hosts..."
    sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$HOSTNAME/" /etc/hosts
    if ! grep -q "127.0.1.1" /etc/hosts; then
        echo "127.0.1.1	$HOSTNAME" | sudo tee -a /etc/hosts
    fi
fi

# ==========================================
# 3. User Management
# ==========================================
prompt "Create dedicated admin user? (y/n) [default: n]"
read -r CREATE_USER
if [[ "$CREATE_USER" == "y" ]]; then
    prompt "Enter admin username:"
    read -r ADMIN_USER
    
    if id "$ADMIN_USER" &>/dev/null; then
        warn "User $ADMIN_USER already exists, skipping..."
    else
        log "Creating admin user $ADMIN_USER..."
        sudo adduser "$ADMIN_USER"
        sudo usermod -aG sudo "$ADMIN_USER"
        warn "Please logout and continue as $ADMIN_USER before proceeding"
        warn "Run: su - $ADMIN_USER"
        exit 0
    fi
fi

prompt "Disable/remove default pi user? (y/n) [default: n]"
read -r DISABLE_PI
if [[ "$DISABLE_PI" == "y" ]]; then
    if id "pi" &>/dev/null; then
        log "Disabling pi user..."
        sudo passwd -l pi
        
        prompt "Permanently delete pi user? (y/n) [default: n]"
        read -r DELETE_PI
        if [[ "$DELETE_PI" == "y" ]]; then
            sudo deluser --remove-home pi
            log "Pi user removed"
        fi
    else
        log "Pi user does not exist, skipping..."
    fi
fi

# ==========================================
# 4. Service Reduction
# ==========================================
log "Step 3: Disabling unnecessary services..."
SERVICES_TO_DISABLE=(
    "avahi-daemon"
    "bluetooth"
    "cups"
    "triggerhappy"
)

SOCKETS_TO_DISABLE=(
    "avahi-daemon.socket"
    "cups.socket"
    "cups.path"
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl list-unit-files | grep -q "^$service"; then
        log "Disabling $service..."
        sudo systemctl disable "$service" 2>/dev/null || true
        sudo systemctl stop "$service" 2>/dev/null || true
    fi
done

for socket in "${SOCKETS_TO_DISABLE[@]}"; do
    if systemctl list-unit-files | grep -q "^$socket"; then
        log "Disabling $socket..."
        sudo systemctl disable "$socket" 2>/dev/null || true
        sudo systemctl stop "$socket" 2>/dev/null || true
    fi
done

log "Active services:"
systemctl --type=service --state=running --no-pager

# ==========================================
# 5. Install and Configure Tailscale
# ==========================================
log "Step 4: Installing Tailscale..."
if command -v tailscale &> /dev/null; then
    log "Tailscale already installed"
else
    curl -fsSL https://tailscale.com/install.sh | sh
fi

log "Enabling IP forwarding..."
echo 'net.ipv4.ip_forward=1' | sudo tee /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

prompt "Enter subnet routes (comma-separated, e.g., 192.168.1.0/24,192.168.2.0/24) or press Enter to skip:"
read -r SUBNET_ROUTES

if [ -n "$SUBNET_ROUTES" ]; then
    log "Bringing up Tailscale with SSH and subnet routing..."
    sudo tailscale up --ssh --advertise-routes="$SUBNET_ROUTES"
else
    log "Bringing up Tailscale with SSH only..."
    sudo tailscale up --ssh
fi

warn "Please authorize this device in the Tailscale admin console"
warn "Then confirm Tailscale SSH access is working before proceeding"
prompt "Press Enter when ready to continue..."
read -r

# ==========================================
# 6. Local Firewall (nftables)
# ==========================================
log "Step 5: Installing nftables..."
sudo apt install nftables -y
sudo systemctl enable nftables

log "Configuring nftables for Tailscale-only access..."
sudo tee /etc/nftables.conf > /dev/null <<'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    chain input {
        type filter hook input priority 0; policy drop;
        
        # Allow loopback
        iif lo accept
        
        # Allow established connections
        ct state established,related accept
        
        # Allow Tailscale interface
        iifname "tailscale0" accept
        
        # Allow ICMP (ping)
        ip protocol icmp accept
        ip6 nexthdr icmpv6 accept
        
        # Log and drop everything else
        log prefix "nftables-drop: " drop
    }
    
    chain forward {
        type filter hook forward priority 0; policy drop;
        
        # Allow forwarding for Tailscale subnet routing
        iifname "tailscale0" accept
        oifname "tailscale0" ct state established,related accept
        
        # Allow forwarding from local subnets to Tailscale
        ct state established,related accept
    }
    
    chain output {
        type filter hook output priority 0; policy accept;
    }
}
EOF

sudo nft -f /etc/nftables.conf
sudo systemctl restart nftables

log "nftables configured and enabled"

# ==========================================
# 7. Fail2Ban
# ==========================================
log "Step 6: Installing Fail2Ban..."
sudo apt install fail2ban -y

log "Configuring Fail2Ban for SSH..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<'EOF'
[sshd]
enabled = true
bantime = 1h
findtime = 10m
maxretry = 5
EOF

sudo systemctl enable --now fail2ban
log "Fail2Ban configured and started"

# ==========================================
# 8. Filesystem Hardening
# ==========================================
log "Step 7: Hardening filesystem mount options..."

# Check if tmpfs entries already exist
if ! grep -q "tmpfs /tmp" /etc/fstab; then
    log "Adding secure tmpfs mounts to /etc/fstab..."
    echo "tmpfs /tmp tmpfs defaults,noexec,nosuid,nodev 0 0" | sudo tee -a /etc/fstab
fi

if ! grep -q "tmpfs /var/tmp" /etc/fstab; then
    echo "tmpfs /var/tmp tmpfs defaults,noexec,nosuid,nodev 0 0" | sudo tee -a /etc/fstab
fi

log "Mounting filesystems..."
sudo mount -a

# ==========================================
# 9. AppArmor
# ==========================================
log "Step 8: Enabling AppArmor..."
sudo apt install apparmor apparmor-utils -y
sudo systemctl enable apparmor
sudo systemctl start apparmor

log "AppArmor status:"
sudo aa-status

# ==========================================
# 10. Automatic Security Updates
# ==========================================
log "Step 9: Configuring automatic security updates..."
sudo apt install unattended-upgrades -y
echo 'Unattended-Upgrade::Automatic-Reboot "false";' | sudo tee /etc/apt/apt.conf.d/51myunattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades

# ==========================================
# 11. Verification
# ==========================================
log "Step 10: Running verification checks..."

echo ""
log "=== Tailscale Interface ==="
ip a show tailscale0

echo ""
log "=== Tailscale Status ==="
tailscale status

echo ""
log "=== NFTables Ruleset ==="
sudo nft list ruleset

echo ""
log "=== IP Forwarding ==="
sudo sysctl net.ipv4.ip_forward

echo ""
log "=== AppArmor Status ==="
sudo aa-status

# ==========================================
# 12. Final Step - Disable Local SSH
# ==========================================
echo ""
warn "IMPORTANT: This will disable local SSH access!"
warn "Ensure Tailscale SSH is working before proceeding"
prompt "Disable local SSH daemon? (y/n) [default: n]"
read -r DISABLE_SSH

if [[ "$DISABLE_SSH" == "y" ]]; then
    log "Disabling local SSH..."
    sudo systemctl disable ssh
    sudo systemctl stop ssh
    log "Local SSH disabled. Access only via Tailscale SSH."
fi

# ==========================================
# Complete
# ==========================================
echo ""
log "=================================="
log "Hardening Complete!"
log "=================================="
echo ""
log "Summary:"
log "  ✓ System updated"
log "  ✓ Unnecessary services disabled"
log "  ✓ Tailscale installed and configured"
log "  ✓ nftables firewall enabled"
log "  ✓ Fail2Ban configured"
log "  ✓ Filesystem hardened"
log "  ✓ AppArmor enabled"
log "  ✓ Automatic updates configured"
echo ""
warn "Operational Notes:"
warn "  - Do not install additional services"
warn "  - Changes require firewall and ACL review"
warn "  - Revoke node immediately if compromise suspected"
echo ""
prompt "Reboot now to apply all changes? (y/n) [default: n]"
read -r REBOOT
if [[ "$REBOOT" == "y" ]]; then
    log "Rebooting..."
    sudo reboot
else
    warn "Please reboot manually when ready: sudo reboot"
fi
