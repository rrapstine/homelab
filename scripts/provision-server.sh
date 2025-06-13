#!/bin/bash
# Server Provisioning Script - legends homelab with conservative Btrfs snapshots
# This script ONLY sets up the host - Terraform manages everything else

set -e  # Exit on any error

# Configuration
SERVER_USER="richard"
HOMELAB_DIR="/opt/homelab"

PYTHON_VENV_DIR="/opt/venv"
PYTHON_VENV_PATH="$PYTHON_VENV_DIR/venv_mdns_publisher"

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

# Configure passwordless sudo for the user 'richard'
SUDOERS_FILE_PATH="/etc/sudoers.d/$SERVER_USER-nopasswd"
echo "Configuring passwordless sudo for user $SERVER_USER..."

# Create the sudoers file.
# Using tee with sudo to write to a root-owned directory.
# The > /dev/null is to prevent tee from outputting the content to stdout.
echo "$SERVER_USER ALL=(ALL) NOPASSWD: ALL" | sudo tee "$SUDOERS_FILE_PATH" > /dev/null

# Set the correct permissions for the sudoers file.
# It should be readable by root and not writable by others.
sudo chmod 0440 "$SUDOERS_FILE_PATH"
echo "Passwordless sudo configured for $SERVER_USER."

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
echo "🛠️ Installing essential packages..."
sudo apt install -y curl wget git htop tree jq net-tools ca-certificates

# Container runtime
echo "🐳 Installing Podman container runtime..."
sudo apt install -y podman podman-compose buildah skopeo

# Podman configuration
echo "⚙️ Configuring Podman for user $SERVER_USER..."
sudo loginctl enable-linger $SERVER_USER
systemctl --user enable podman.socket
systemctl --user start podman.socket

if systemctl --user is-active --quiet podman.socket; then
    echo "✅ Podman socket is running"
else
    echo "❌ Podman socket failed to start"
    exit 1
fi

# Allow rootless Podman to bind to privileged ports like 80/443
echo "⚙️ Configuring net.ipv4.ip_unprivileged_port_start for Podman..."
if ! grep -q "net.ipv4.ip_unprivileged_port_start=80" /etc/sysctl.d/90-podman-unprivileged-ports.conf 2>/dev/null; then
  echo "net.ipv4.ip_unprivileged_port_start=80" | sudo tee /etc/sysctl.d/90-podman-unprivileged-ports.conf > /dev/null
  sudo sysctl --system
  echo "✅ Set net.ipv4.ip_unprivileged_port_start=80 and applied sysctl changes."
else
  echo "✅ net.ipv4.ip_unprivileged_port_start=80 already configured."
fi

# Network infrastructure
echo "🌐 Installing mDNS support..."
sudo apt install -y avahi-daemon avahi-utils

# --- Determine Main Network Interface ---
echo "🔎 Determining main network interface..."
# Get the default network interface (usually the one for the default route)
MAIN_INTERFACE=$(ip route | grep '^default' | awk '{print $5}' | head -n1)

if [ -z "$MAIN_INTERFACE" ]; then
    echo "❌ Could not determine the default network interface. Aborting Avahi interface configuration."
    # Decide if you want to exit or just skip this specific Avahi config
    # For now, let's just print a warning and continue, Avahi might still work okay without it
    # if the firewall is the main issue. Or, you could 'exit 1'
    echo "⚠️  Avahi will use its default interface detection."
    # Set MAIN_INTERFACE to empty so the sed logic below doesn't try to use it if not found
    MAIN_INTERFACE=""
else
    echo "💡 Default network interface detected as: $MAIN_INTERFACE"

    # --- Configure Avahi to only use the main network interface ---
    AVAHI_CONF_FILE="/etc/avahi/avahi-daemon.conf"
    EXPECTED_AVAHI_LINE="allow-interfaces=$MAIN_INTERFACE"
    COMMENTED_AVAHI_LINE="#allow-interfaces="

    echo "⚙️  Configuring Avahi to use only interface '$MAIN_INTERFACE'..."

    # Check if the line exists and is correctly configured
    if grep -q "^$EXPECTED_AVAHI_LINE$" "$AVAHI_CONF_FILE"; then
        echo "✅ Avahi allow-interfaces already correctly configured for $MAIN_INTERFACE."
    # Check if the line is commented out and update it
    elif grep -q "^$COMMENTED_AVAHI_LINE" "$AVAHI_CONF_FILE"; then
        sudo sed -i "s|^$COMMENTED_AVAHI_LINE.*|$EXPECTED_AVAHI_LINE|" "$AVAHI_CONF_FILE"
        echo "✅ Avahi allow-interfaces uncommented and set to $MAIN_INTERFACE."
    # Check if the line exists but with a different interface (or no specific interface) and update it
    elif grep -q "^allow-interfaces=" "$AVAHI_CONF_FILE"; then
        sudo sed -i "s|^allow-interfaces=.*|$EXPECTED_AVAHI_LINE|" "$AVAHI_CONF_FILE"
        echo "✅ Avahi allow-interfaces updated to $MAIN_INTERFACE."
    # If the line doesn't exist at all, add it
    else
        echo "$EXPECTED_AVAHI_LINE" | sudo tee -a "$AVAHI_CONF_FILE" > /dev/null
        echo "✅ Avahi allow-interfaces added for $MAIN_INTERFACE."
    fi
fi # End of MAIN_INTERFACE check for Avahi config

# --- Enable and Restart Avahi ---
sudo systemctl enable avahi-daemon
# Restart Avahi to ensure it picks up any configuration changes
sudo systemctl restart avahi-daemon # Use restart to ensure it applies new config
echo "✅ Avahi daemon enabled and (re)started."

# Install python3, venv, build dependencies, and mdns-publisher package
echo "🐍 Installing Python3, venv, build dependencies, and setting up mdns-publisher in a virtual environment..."
sudo apt install -y python3 python3-pip python3-venv pkg-config libdbus-1-dev build-essential python3-dev libglib2.0-dev

# Create the virtual environment for Python
echo "🐍 Creating virtual environment at $PYTHON_VENV_PATH..."
sudo mkdir -p "$PYTHON_VENV_DIR"

if [ -d "$PYTHON_VENV_PATH" ]; then
    echo "🐍 Python virtual environment already exists at $PYTHON_VENV_PATH..."
    echo "Skipping creation..."
else
    sudo python3 -m venv "$PYTHON_VENV_PATH"
fi

# Install mdns-publisher into the new virtual environment
echo "🐍 Installing mdns-publisher package into $PYTHON_VENV_PATH"
sudo "$PYTHON_VENV_PATH/bin/pip" install --upgrade mdns-publisher

# Basic firewall
echo "🔥 Configuring basic firewall..."

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow essential services
sudo ufw allow ssh
sudo ufw allow 5353/udp  # For mDNS / Avahi for legends.local resolution

# Allow Caddy ports
sudo ufw allow 80/tcp   # For Caddy HTTP
sudo ufw allow 443/tcp  # For Caddy HTTPS

# Enable the firewall (if not already enabled)
# The --force flag will enable without prompting if it's currently disabled.
# If it's already enabled, this command doesn't hurt.
sudo ufw --force enable

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
