#!/bin/bash

# JustLayMe Service Installation Script
# This script sets up automatic startup for JustLayMe API and Cloudflare tunnel

echo "🚀 Installing JustLayMe Services..."

# Stop any currently running services
echo "📛 Stopping current processes..."
pkill -f character-api.js
pkill -f cloudflared

# Copy service files to systemd directory
echo "📋 Installing systemd service files..."
sudo cp /home/fastl/JustLayme/justlayme-api.service /etc/systemd/system/
sudo cp /home/fastl/JustLayme/justlayme-tunnel.service /etc/systemd/system/
sudo cp /home/fastl/JustLayme/justlayme-monitor.service /etc/systemd/system/

# Set correct permissions
sudo chmod 644 /etc/systemd/system/justlayme-api.service
sudo chmod 644 /etc/systemd/system/justlayme-tunnel.service
sudo chmod 644 /etc/systemd/system/justlayme-monitor.service

# Reload systemd daemon
echo "🔄 Reloading systemd daemon..."
sudo systemctl daemon-reload

# Enable services to start on boot
echo "✅ Enabling services for auto-start..."
sudo systemctl enable justlayme-api.service
sudo systemctl enable justlayme-tunnel.service
sudo systemctl enable justlayme-monitor.service

# Start services
echo "🎯 Starting services..."
sudo systemctl start justlayme-api.service
sleep 5
sudo systemctl start justlayme-tunnel.service
sleep 5
sudo systemctl start justlayme-monitor.service

# Check status
echo "📊 Service Status:"
echo "=================================="
echo "JustLayMe API:"
sudo systemctl status justlayme-api.service --no-pager -l
echo "=================================="
echo "Cloudflare Tunnel:"
sudo systemctl status justlayme-tunnel.service --no-pager -l

echo "✅ Installation complete!"
echo ""
echo "📝 Service Management Commands:"
echo "  Start API:     sudo systemctl start justlayme-api"
echo "  Start Tunnel:  sudo systemctl start justlayme-tunnel"
echo "  Stop API:      sudo systemctl stop justlayme-api"
echo "  Stop Tunnel:   sudo systemctl stop justlayme-tunnel"
echo "  Check Status:  sudo systemctl status justlayme-api"
echo "  View Logs:     sudo journalctl -u justlayme-api -f"
echo ""
echo "🔄 Services will now automatically:"
echo "  • Start on system boot"
echo "  • Restart on failures"
echo "  • Reconnect after network disconnects"