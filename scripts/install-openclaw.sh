#!/bin/bash

# Install OpenClaw
# Sets up OpenClaw gateway as systemd service

set -e

echo "🤖 Installing OpenClaw..."

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "Installing Node.js..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
fi

echo "Installing OpenClaw globally..."
sudo npm install -g openclaw

echo ""
echo "Creating OpenClaw service configuration..."
sudo mkdir -p /etc/openclaw
sudo mkdir -p /srv/openclaw/{logs,cache,credentials}

# Create service file
sudo bash -c 'cat > /etc/systemd/user/openclaw-gateway.service << '\''EOF'\''
[Unit]
Description=OpenClaw Gateway
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=%u
WorkingDirectory=%h/.openclaw
ExecStart=/usr/bin/openclaw gateway --port 18789
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=default.target
EOF
'

echo "✅ OpenClaw installed"

echo ""
echo "Next steps:"
echo "1. Start the gateway:"
echo "   systemctl --user start openclaw-gateway"
echo ""
echo "2. Enable on boot:"
echo "   systemctl --user enable openclaw-gateway"
echo ""
echo "3. Check status:"
echo "   systemctl --user status openclaw-gateway"
echo ""
