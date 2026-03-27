#!/usr/bin/env bash

# Exit on error
set -e

# Re-execute with sudo if not already running as root
if [ "$EUID" -ne 0 ]; then 
    echo "This script needs sudo privileges. Re-running with sudo..."
    exec sudo bash "$0" "$@"
    exit
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source OS detection
source "${SCRIPT_DIR}/os_detect.sh"

# Save OS type in variable AND EXPORT IT
OS_TYPE="$os_result"
export OS_TYPE

echo "Detected OS: $OS_TYPE"
echo "Running as: $(whoami)"

# Error handling function
error_exit() {
    echo "Error: $1" >&2
    exit 1
}

install_arch() {
    echo "Installing for Arch Linux..."
    pacman -Sy --noconfirm || error_exit "Failed to update packages"
    pacman -S --noconfirm tor torsocks curl wget base-devel git age || error_exit "Failed to install packages"
    
    if ! command -v yay &> /dev/null; then
        echo "Installing yay..."
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        git clone https://aur.archlinux.org/yay.git || error_exit "Failed to clone yay"
        cd yay
        sudo -u "$SUDO_USER" makepkg -si --noconfirm || error_exit "Failed to install yay"
        cd /
        rm -rf "$TEMP_DIR"
    fi
    
    sudo -u "$SUDO_USER" yay -S --noconfirm obfs4proxy || error_exit "Failed to install obfs4proxy"
}

install_debian() {
    echo "Installing for Debian/Ubuntu..."
    apt update || error_exit "Failed to update packages"
    apt install -y tor torsocks obfs4proxy curl wget age || error_exit "Failed to install packages"
}

install_fedora() {
    echo "Installing for Fedora/RHEL..."
    dnf update -y || error_exit "Failed to update packages"
    dnf install -y tor torsocks obfs4 curl wget age || error_exit "Failed to install packages"
}

install_macos() {
    echo "Installing for macOS..."
    if ! command -v brew &> /dev/null; then
        error_exit "Homebrew not found. Please install Homebrew first: https://brew.sh"
    fi
    brew update || error_exit "Failed to update Homebrew"
    brew install tor torsocks obfs4 age || error_exit "Failed to install packages"
}

install_native() {
    case "$OS_TYPE" in
        arch)
            install_arch
            ;;
        debian)
            install_debian
            ;;
        fedora|rhel)
            install_fedora
            ;;
        macos)
            install_macos
            ;;
        *)
            error_exit "Unsupported OS: $OS_TYPE"
            ;;
    esac
}

# Verify age is installed after installation
verify_age() {
    echo "Verifying age installation..."
    if ! command -v age &> /dev/null; then
        error_exit "age is not installed. Please install age manually."
    fi
    echo "✓ age is installed: $(which age)"
}

# Main execution
install_native
verify_age
echo "✓ Dependencies installed successfully"

# Now create torrc
echo ""
echo "Creating Tor configuration..."
bash "${SCRIPT_DIR}/torrc_create.sh" || error_exit "Failed to create torrc"

echo ""
echo "Setting up Tor service..."
bash "${SCRIPT_DIR}/tor_service.sh" || error_exit "Failed to setup Tor service"

PROXY_LINK="tg://socks?server=127.0.0.1&port=9150"

echo ""
echo "Click this link in Telegram:"
echo ""
echo "$PROXY_LINK"
echo ""

# Try to open automatically
if command -v xdg-open &> /dev/null; then
    read -p "Open link automatically? (y/n): " open_now
    if [[ "$open_now" == "y" ]]; then
        xdg-open "$PROXY_LINK" || echo "Could not open automatically"
    fi
fi

echo ""
echo "Manual setup if link doesn't work:"
echo "  Settings → Advanced → Connection Type → Use SOCKS5 proxy"
echo "  Server: 127.0.0.1  Port: 9150"
