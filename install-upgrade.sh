#!/bin/bash
#
# vibebin install/upgrade script
# Installs or upgrades vibebin to the latest version
#
# Usage: ./install-upgrade.sh [branch]
#   branch: optional git branch to checkout (default: main)
#

set -e

BRANCH="${1:-main}"
REPO_URL="https://github.com/jgbrwn/vibebin.git"
INSTALL_DIR="/usr/local/bin"
TEMP_DIR="/tmp/vibebin-install-$$"

echo "════════════════════════════════════════════════════════════════════"
echo "  vibebin Install/Upgrade Script"
echo "════════════════════════════════════════════════════════════════════"
echo ""
echo "  Branch: $BRANCH"
echo ""

# Check if running as root or with sudo available
if [ "$EUID" -ne 0 ]; then
    if ! command -v sudo &> /dev/null; then
        echo "❌ Error: This script requires root privileges or sudo"
        exit 1
    fi
    SUDO="sudo"
else
    SUDO=""
fi

# Check for required tools
for cmd in git go; do
    if ! command -v $cmd &> /dev/null; then
        echo "❌ Error: $cmd is required but not installed"
        exit 1
    fi
done

# Check if systemd service file exists (before any changes)
SYSTEMD_FILE_EXISTED=false
if [ -f /etc/systemd/system/vibebin-sync.service ]; then
    SYSTEMD_FILE_EXISTED=true
fi

# Detect if this is an upgrade (vibebin-sync service exists and is running)
IS_UPGRADE=false
if systemctl is-active --quiet vibebin-sync 2>/dev/null; then
    IS_UPGRADE=true
    echo "📦 Detected existing installation - performing upgrade"
    echo ""
    echo "🛑 Step 1: Stopping vibebin-sync daemon..."
    $SUDO systemctl stop vibebin-sync
else
    echo "📦 No existing installation detected - performing fresh install"
fi

echo ""
echo "📥 Cloning repository..."
rm -rf "$TEMP_DIR"
git clone --branch "$BRANCH" "$REPO_URL" "$TEMP_DIR"
cd "$TEMP_DIR"

echo ""
echo "🔨 Building binaries..."
go build -o vibebin vibebin.go
go build -o vibebin_sync_daemon vibebin_sync_daemon.go

echo ""
echo "📋 Installing binaries to $INSTALL_DIR..."
$SUDO cp vibebin vibebin_sync_daemon "$INSTALL_DIR/"

echo ""
echo "📋 Installing systemd service file..."
$SUDO cp vibebin-sync.service /etc/systemd/system/

echo ""
echo "🔄 Reloading systemd daemon..."
$SUDO systemctl daemon-reload

# Only start vibebin-sync if the service file existed before (meaning it was previously set up)
if [ "$SYSTEMD_FILE_EXISTED" = true ]; then
    echo ""
    echo "🚀 Starting vibebin-sync daemon..."
    $SUDO systemctl start vibebin-sync
fi

echo ""
echo "🧹 Cleaning up..."
cd /
rm -rf "$TEMP_DIR"

echo ""
echo "════════════════════════════════════════════════════════════════════"
echo "  ✅ Installation complete!"
echo ""
echo "  Installed:"
echo "    vibebin:             $INSTALL_DIR/vibebin"
echo "    vibebin_sync_daemon: $INSTALL_DIR/vibebin_sync_daemon"
echo "    vibebin-sync.service: /etc/systemd/system/vibebin-sync.service"
echo ""
if [ "$SYSTEMD_FILE_EXISTED" = true ]; then
    echo "  To start the TUI:"
    echo "    sudo vibebin"
else
    echo "  Next steps for first-time setup:"
    echo ""
    echo "    1. Run the TUI to auto-install Incus, Caddy, and SSHPiper:"
    echo "       sudo vibebin"
    echo ""
    echo "    2. After first run, verify SSHPiper is running:"
    echo "       sudo systemctl status sshpiperd"
    echo ""
    echo "    3. If SSHPiper is not running, start it:"
    echo "       sudo systemctl enable --now sshpiperd"
fi
echo ""
echo "════════════════════════════════════════════════════════════════════"
