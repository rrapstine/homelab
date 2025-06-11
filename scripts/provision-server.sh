#!/bin/bash
# Server Provisioning Script - legends homelab with conservative Btrfs snapshots
# This script ONLY sets up the host - Terraform manages everything else

set -e  # Exit on any error

# Configuration
SERVER_USER="richard"
HOMELAB_DIR="/opt/homelab"

echo "🚀 Provisioning Ubuntu Server (host-level setup only)..."
echo "User: $SERVER_USER"
echo "Homelab Directory: $HOMELAB_DIR"
echo ""

# Verify we're running as the correct user
if [ "$USER" != "$SERVER_USER" ]; then
    echo "❌ This script must be run as user '$SERVER_USER'"
    echo "Current user: $USER"
    exit 1
fi

# Basic system updates
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Snapper FIRST for snapshot management
echo "📸 Installing Snapper for Btrfs snapshots..."
sudo apt install -y snapper

# Configure snapper (same configuration as before)
if ! sudo snapper list-configs | grep -q root; then
    echo "⚙️  Creating snapper config for root filesystem..."
    sudo snapper -c root create-config /
fi

# Conservative homelab snapshot configuration
echo "⚙️  Configuring snapper for conservative homelab use..."
sudo sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' /etc/snapper/configs/root
sudo sed -i 's/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/' /etc/snapper/configs/root
sudo sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' /etc/snapper/configs/root
sudo sed -i 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="5"/' /etc/snapper/configs/root

# Timeline limits
for setting in "TIMELINE_LIMIT_HOURLY=\"0\"" "TIMELINE_LIMIT_DAILY=\"7\"" "TIMELINE_LIMIT_WEEKLY=\"0\"" "TIMELINE_LIMIT_MONTHLY=\"0\"" "TIMELINE_LIMIT_YEARLY=\"0\""; do
    key=$(echo $setting | cut -d'=' -f1)
    if ! grep -q "^$key" /etc/snapper/configs/root; then
        echo $setting | sudo tee -a /etc/snapper/configs/root > /dev/null
    fi
done

# Configure twice-daily snapshots
sudo mkdir -p /etc/systemd/system/snapper-timeline.timer.d/
cat << 'EOF' | sudo tee /etc/systemd/system/snapper-timeline.timer.d/override.conf > /dev/null
[Timer]
OnCalendar=
OnCalendar=06:00
OnCalendar=18:00
Persistent=true
EOF

sudo systemctl enable snapper-timeline.timer snapper-cleanup.timer
sudo systemctl start snapper-timeline.timer snapper-cleanup.timer
sudo systemctl daemon-reload

# Baseline snapshot
echo "📸 Creating baseline snapshot..."
sudo snapper -c root create --description "Baseline - Fresh Ubuntu before homelab provisioning - $(date -u)" --userdata "important=yes"

# Install essential packages
echo "🛠️  Installing essential packages..."
sudo apt install -y curl wget git htop tree jq net-tools ca-certificates

# Container runtime
echo "🐳 Installing Podman container runtime..."
sudo apt install -y podman podman-compose buildah skopeo

# Podman configuration
echo "⚙️  Configuring Podman for user $SERVER_USER..."
sudo loginctl enable-linger $SERVER_USER
systemctl --user enable podman.socket
systemctl --user start podman.socket

if systemctl --user is-active --quiet podman.socket; then
    echo "✅ Podman socket is running"
else
    echo "❌ Podman socket failed to start"
    exit 1
fi

# Network infrastructure
echo "🌐 Installing mDNS support..."
sudo apt install -y avahi-daemon avahi-utils
sudo systemctl enable avahi-daemon
sudo systemctl start avahi-daemon

# Basic firewall
echo "🔥 Configuring basic firewall..."
sudo ufw --force enable
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh

# Set hostname
if [ "$(hostname)" != "legends" ]; then
    echo "🏷️  Setting hostname to 'legends'"
    sudo hostnamectl set-hostname legends
fi

# Create ONLY the base homelab directory - Terraform will manage service directories
echo "📁 Creating base homelab directory..."
sudo mkdir -p $HOMELAB_DIR
sudo chown -R $SERVER_USER:$SERVER_USER $HOMELAB_DIR

# Create snapshot management helpers
echo "🔧 Creating snapshot management helpers..."
cat > $HOMELAB_DIR/snapshot-helpers.sh <<'EOF'
#!/bin/bash
# Homelab snapshot management helpers

homelab-snapshot-pre() {
    local description="${1:-Manual pre-deployment snapshot}"
    sudo snapper -c root create --description "$description - $(date -u)" --userdata "important=yes"
    echo "📸 Pre-deployment snapshot created: $description"
}

homelab-snapshot-post() {
    local description="${1:-Manual post-deployment snapshot}"
    sudo snapper -c root create --description "$description - $(date -u)" --userdata "important=yes"
    echo "📸 Post-deployment snapshot created: $description"
}

homelab-snapshots() {
    echo "📸 All snapshots:"
    sudo snapper -c root list
    echo ""
    echo "🏠 Homelab-related snapshots:"
    sudo snapper -c root list | grep -E "(homelab|deployment|provisioning|Baseline|Terraform)"
}

homelab-snapshot-usage() {
    echo "💾 Snapshot disk usage:"
    sudo btrfs filesystem show
}

homelab-rollback() {
    local snapshot_num="$1"
    if [ -z "$snapshot_num" ]; then
        echo "Usage: homelab-rollback <snapshot_number>"
        homelab-snapshots
        return 1
    fi

    echo "⚠️  Rolling back to snapshot $snapshot_num"
    echo "This will reboot the system. Continue? (y/N)"
    read -r confirm
    if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
        sudo snapper -c root undochange $snapshot_num..0
        echo "🔄 Rollback prepared. Rebooting..."
        sudo reboot
    fi
}
EOF

chmod +x $HOMELAB_DIR/snapshot-helpers.sh

if ! grep -q "snapshot-helpers.sh" ~/.bashrc; then
    echo "source $HOMELAB_DIR/snapshot-helpers.sh" >> ~/.bashrc
fi

# Final snapshot
echo "📸 Creating final provisioning snapshot..."
sudo snapper -c root create --description "Host provisioning complete - Ready for Terraform - $(date -u)" --userdata "important=yes"

# Mark as provisioned
touch $HOMELAB_DIR/.provisioned
echo "$(date -u)" > $HOMELAB_DIR/.provisioned

echo ""
echo "✅ Host provisioning complete!"
echo "🔑 Next step: Terraform will create all service directories and containers"
