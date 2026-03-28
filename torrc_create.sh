#!/usr/bin/env bash

# torrc_create.sh - Create torrc with bridges

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/os_detect.sh"
OS_TYPE="$os_result"

CONFIG_DIR="${HOME}/.tor-suite"
TORRC_PATH="${CONFIG_DIR}/torrc"
TOR_DATA_DIR="${CONFIG_DIR}/tor-data"  # Keep data in user's home
BRIDGES_TXT="${CONFIG_DIR}/bridges.txt"

# Look for bridges.age in current dir first, then config dir
if [[ -f "./bridges.age" ]]; then
    BRIDGES_AGE="./bridges.age"
elif [[ -f "${CONFIG_DIR}/bridges.age" ]]; then
    BRIDGES_AGE="${CONFIG_DIR}/bridges.age"
else
    echo "Error: bridges.age not found in current directory or ~/.tor-suite"
    exit 1
fi

# Find obfs4proxy path
find_obfs4_path() {
    if command -v obfs4proxy &> /dev/null; then
        command -v obfs4proxy
    elif [ -f "/usr/bin/obfs4proxy" ]; then
        echo "/usr/bin/obfs4proxy"
    elif [ -f "/usr/local/bin/obfs4proxy" ]; then
        echo "/usr/local/bin/obfs4proxy"
    else
        echo ""
    fi
}

OBFS4_PATH=$(find_obfs4_path)

if [ -z "$OBFS4_PATH" ]; then
    echo "Warning: obfs4proxy not found. Tor will run without obfs4 support."
fi

# Get obfs4 path based on OS (fallback)
get_obfs4_path() {
    if [ -n "$OBFS4_PATH" ]; then
        echo "$OBFS4_PATH"
    else
        case "$OS_TYPE" in
            arch|debian|fedora|rhel)
                echo "/usr/bin/obfs4proxy"
                ;;
            macos)
                echo "/usr/local/bin/obfs4proxy"
                ;;
            *)
                echo "/usr/bin/obfs4proxy"
                ;;
        esac
    fi
}

# Decode bridges
decode_bridges() {
    mkdir -p "$CONFIG_DIR"
    
    echo "Decrypting bridges..."
    age -d "$BRIDGES_AGE" > "$BRIDGES_TXT"
    
    if [[ ! -s "$BRIDGES_TXT" ]]; then
        echo "Error: Failed to decrypt bridges"
        return 1
    fi
    
    # Remove duplicates and empty lines
    sort -u "$BRIDGES_TXT" > "${BRIDGES_TXT}.tmp"
    mv "${BRIDGES_TXT}.tmp" "$BRIDGES_TXT"
    
    local count=$(grep -c '^obfs4' "$BRIDGES_TXT" 2>/dev/null || echo "0")
    echo "Decrypted $count unique bridges"
    return 0
}

# Create torrc
create_torrc() {
    local obfs4_path=$(get_obfs4_path)
    
    mkdir -p "$TOR_DATA_DIR"
    chmod 700 "$TOR_DATA_DIR"
    
    # Build unique bridge lines
    local bridge_lines=""
    if [[ -f "$BRIDGES_TXT" ]] && [[ -s "$BRIDGES_TXT" ]]; then
        bridge_lines=$(awk '!seen[$0]++' "$BRIDGES_TXT" | while IFS= read -r line; do
            [[ -n "$line" ]] && echo "Bridge $line"
        done)
    fi
    
    cat > "$TORRC_PATH" << EOF
SOCKSPort 127.0.0.1:9150
DataDirectory $TOR_DATA_DIR

AutomapHostsOnResolve 1
VirtualAddrNetworkIPv4 10.192.0.0/10
VirtualAddrNetworkIPv6 [FD00::]/8

UseBridges 1
ClientTransportPlugin obfs4 exec $obfs4_path

ClientUseIPv4 1
ClientUseIPv6 0

FascistFirewall 0
ReachableAddresses *:*

$bridge_lines
EOF
    
    chmod 600 "$TORRC_PATH"
    
    echo "Torrc created at $TORRC_PATH"
    local bridge_count=$(grep -c '^Bridge' "$TORRC_PATH" 2>/dev/null || echo "0")
    echo "Added $bridge_count unique bridges"
    
    echo ""
    echo "First 3 bridges:"
    grep '^Bridge' "$TORRC_PATH" | head -3
}

# Main
if decode_bridges; then
    create_torrc
    echo "Tor configuration complete"
else
    echo "Tor configuration failed"
    exit 1
fi
