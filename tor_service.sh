#!/usr/bin/env bash

# tor_service.sh - Setup systemd service for Tor with progress tracking

CONFIG_DIR="${HOME}/.tor-suite"
TORRC_PATH="${CONFIG_DIR}/torrc"
LOG_FILE="${CONFIG_DIR}/tor-bootstrap.log"
CURRENT_USER=$(whoami)

echo "Detected OS: $OS_TYPE"
echo "Using torrc: $TORRC_PATH"
echo "Running as user: $CURRENT_USER"

# Verify torrc exists
if [ ! -f "$TORRC_PATH" ]; then
    echo "Error: torrc not found at $TORRC_PATH"
    exit 1
fi

# Function to show bootstrap progress
track_bootstrap() {
    local timeout=600
    local elapsed=0
    local last_percent=0
    
    echo "Waiting for Tor to bootstrap..."
    echo ""
    
    while [ $elapsed -lt $timeout ]; do
        if [ -f "$LOG_FILE" ]; then
            local percent=$(tail -n 50 "$LOG_FILE" 2>/dev/null | grep -oP 'Bootstrapped \K[0-9]+' | tail -1)
            
            if [ -n "$percent" ] && [ "$percent" -gt "$last_percent" ]; then
                last_percent=$percent
                
                local width=50
                local filled=$((width * percent / 100))
                local empty=$((width - filled))
                
                printf "\r["
                printf "%${filled}s" | tr ' ' '='
                printf "%${empty}s" | tr ' ' ' '
                printf "] %3d%%" "$percent"
                
                if [ "$percent" -eq 100 ]; then
                    echo ""
                    echo ""
                    echo "Tor is fully bootstrapped and ready!"
                    return 0
                fi
            fi
        fi
        
        sleep 2
        elapsed=$((elapsed + 2))
    done
    
    echo ""
    echo "Timeout waiting for Tor bootstrap"
    return 1
}

if [[ "$OS_TYPE" == "arch" ]] || [[ "$OS_TYPE" == "debian" ]] || [[ "$OS_TYPE" == "fedora" ]] || [[ "$OS_TYPE" == "rhel" ]]; then
    echo "Setting up systemd service..."
    
    # Disable and stop the default Tor service to avoid conflicts
    echo "Disabling default Tor service..."
    systemctl stop tor 2>/dev/null || true
    systemctl disable tor 2>/dev/null || true
    systemctl mask tor 2>/dev/null || true
    
    # Stop any existing custom service
    systemctl stop tor-custom 2>/dev/null || true
    systemctl disable tor-custom 2>/dev/null || true
    
    # Create systemd service file that runs as current user
    SERVICE_FILE="/etc/systemd/system/tor-custom.service"
    
    echo "Creating systemd service..."
    cat > "$SERVICE_FILE" << EOF
[Unit]
Description=Tor Custom Proxy with Bridges
After=network.target
Wants=network.target

[Service]
Type=simple
User=$CURRENT_USER
ExecStart=/usr/bin/tor -f $TORRC_PATH

StandardOutput=append:$LOG_FILE
StandardError=append:$LOG_FILE

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable and start service
    echo "Enabling and starting Tor service..."
    systemctl enable tor-custom.service
    systemctl start tor-custom.service
    
    # Track bootstrap progress
    track_bootstrap
    
    if systemctl is-active --quiet tor-custom.service; then
        echo ""
        echo "✓ Tor service is running as user $CURRENT_USER"
        
        # Final verification
        if curl -s --socks5 localhost:9150 --max-time 10 https://check.torproject.org/api/ip 2>/dev/null | grep -q '"IsTor":true'; then
            echo "✓ Tor connection verified"
        else
            echo "⚠ Tor is running but connection not yet fully established"
            echo "  Check logs: journalctl -u tor-custom.service -f"
        fi
    else
        echo "✗ Tor service failed to start"
        echo "  Check logs: journalctl -u tor-custom.service"
        exit 1
    fi
    
    echo ""
    echo "Tor service management:"
    echo "  Start:   systemctl start tor-custom.service"
    echo "  Stop:    systemctl stop tor-custom.service"
    echo "  Status:  systemctl status tor-custom.service"
    echo "  Logs:    journalctl -u tor-custom.service -f"
    echo "  Config:  $TORRC_PATH"
    echo "  Data:    $CONFIG_DIR/tor-data"
    echo ""
    echo "Note: Default Tor service has been disabled to avoid conflicts"
    echo "  To restore: sudo systemctl unmask tor && sudo systemctl enable tor"
    
else
    echo "Systemd not available for $OS_TYPE"
    echo "Run Tor manually:"
    echo "  tor -f $TORRC_PATH"
    
    cat > "${CONFIG_DIR}/start_tor.sh" << EOF
#!/bin/bash
tor -f $TORRC_PATH
EOF
    chmod +x "${CONFIG_DIR}/start_tor.sh"
    echo ""
    echo "Start script created: ${CONFIG_DIR}/start_tor.sh"
fi
