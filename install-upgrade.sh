#!/bin/bash
#
# shelley-lxc install/upgrade script
# Installs or upgrades shelley-lxc to the latest version
#
# Usage: ./install-upgrade.sh [branch]
#   branch: optional git branch to checkout (default: main)
#

set -e

BRANCH="${1:-main}"
REPO_URL="https://github.com/jgbrwn/shelley-lxc.git"
INSTALL_DIR="/usr/local/bin"
TEMP_DIR="/tmp/shelley-lxc-install-$$"

echo "════════════════════════════════════════════════════════════════════"
echo "  shelley-lxc Install/Upgrade Script"
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

# Detect if this is an upgrade (incus-sync service exists and is running)
IS_UPGRADE=false
if systemctl is-active --quiet incus-sync 2>/dev/null; then
    IS_UPGRADE=true
    echo "📦 Detected existing installation - performing upgrade"
    echo ""
    echo "🛑 Step 1: Stopping incus-sync daemon..."
    $SUDO systemctl stop incus-sync
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
go build -o incus_manager incus_manager.go
go build -o incus_sync_daemon incus_sync_daemon.go

echo ""
echo "📋 Installing binaries to $INSTALL_DIR..."
$SUDO cp incus_manager incus_sync_daemon "$INSTALL_DIR/"

if [ "$IS_UPGRADE" = true ]; then
    echo ""
    echo "🚀 Restarting incus-sync daemon..."
    $SUDO systemctl start incus-sync
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
echo "    incus_manager:     $INSTALL_DIR/incus_manager"
echo "    incus_sync_daemon: $INSTALL_DIR/incus_sync_daemon"
echo ""
if [ "$IS_UPGRADE" = false ]; then
    echo "  Next steps:"
    echo "    Run 'sudo incus_manager' to complete first-time setup"
    echo ""
fi
echo "════════════════════════════════════════════════════════════════════"
