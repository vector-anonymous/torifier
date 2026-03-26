#!/usr/bin/env bash

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

install_arch() {
    echo "Installing for Arch Linux..."
    pacman -Sy --noconfirm
    pacman -S --noconfirm tor torsocks curl wget base-devel git age
    
    if ! command -v yay &> /dev/null; then
        echo "Installing yay..."
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR"
        git clone https://aur.archlinux.org/yay.git
        cd yay
        sudo -u "$SUDO_USER" makepkg -si --noconfirm
        cd /
        rm -rf "$TEMP_DIR"
    fi
    
    sudo -u "$SUDO_USER" yay -S --noconfirm obfs4proxy
}

install_debian() {
    echo "Installing for Debian/Ubuntu..."
    apt update
    apt install -y tor torsocks obfs4proxy curl wget age
}

install_fedora() {
    echo "Installing for Fedora/RHEL..."
    dnf update -y
    dnf install -y tor torsocks obfs4 curl wget age
}

install_macos() {
    echo "Installing for macOS..."
    if ! command -v brew &> /dev/null; then
        echo "Error: Homebrew not found"
        exit 1
    fi
    brew update
    brew install tor torsocks obfs4 age
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
            echo "Error: Unsupported OS: $OS_TYPE"
            exit 1
            ;;
    esac
}

install_native
echo "Dependencies installed successfully"

# Now create torrc
echo ""
echo "Creating Tor configuration..."
bash "${SCRIPT_DIR}/torrc_create.sh"

echo ""
echo "Setting up Tor service..."
bash "${SCRIPT_DIR}/tor_service.sh"

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
        xdg-open "$PROXY_LINK"
    fi
fi

echo ""
echo "Manual setup if link doesn't work:"
echo "  Settings → Advanced → Connection Type → Use SOCKS5 proxy"
echo "  Server: 127.0.0.1  Port: 9150"
