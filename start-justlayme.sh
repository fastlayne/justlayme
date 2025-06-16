#!/bin/bash

# JustLayMe Complete Startup Script
# Starts all services with proper dependencies and monitoring

echo "🚀 Starting JustLayMe Complete System..."

# Function to wait for service to be ready
wait_for_service() {
    local service=$1
    local timeout=${2:-30}
    local count=0
    
    while [ $count -lt $timeout ]; do
        if systemctl is-active --quiet $service; then
            echo "✅ $service is running"
            return 0
        fi
        echo "⏳ Waiting for $service... ($count/$timeout)"
        sleep 1
        ((count++))
    done
    
    echo "❌ $service failed to start within $timeout seconds"
    return 1
}

# Stop any existing processes
echo "📛 Stopping existing processes..."
pkill -f character-api.js
pkill -f cloudflared
pkill -f network-monitor.sh

# Start services in order
echo "🎯 Starting JustLayMe API server..."
sudo systemctl start justlayme-api.service

if wait_for_service justlayme-api.service; then
    echo "🌐 Starting Cloudflare tunnel..."
    sudo systemctl start justlayme-tunnel.service
    
    if wait_for_service justlayme-tunnel.service; then
        echo "🔍 Starting network monitor..."
        sudo systemctl start justlayme-monitor.service
        
        # Test connectivity
        echo "🧪 Testing connectivity..."
        sleep 10
        
        if curl -s https://justlay.me > /dev/null; then
            echo "✅ Website is accessible at https://justlay.me"
        else
            echo "⚠️  Website may take a moment to be accessible"
        fi
        
        if curl -s http://localhost:3000 > /dev/null; then
            echo "✅ Local API is accessible at http://localhost:3000"
        else
            echo "❌ Local API is not accessible"
        fi
        
        echo ""
        echo "📊 Service Status:"
        sudo systemctl status justlayme-api.service --no-pager -l | head -10
        sudo systemctl status justlayme-tunnel.service --no-pager -l | head -10
        
        echo ""
        echo "✅ JustLayMe system startup complete!"
        echo "🌐 Your website should be live at: https://justlay.me"
    else
        echo "❌ Failed to start Cloudflare tunnel"
        exit 1
    fi
else
    echo "❌ Failed to start API server"
    exit 1
fi