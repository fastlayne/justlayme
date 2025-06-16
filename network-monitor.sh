#!/bin/bash

# JustLayMe Network Monitor Script
# Monitors website connectivity and restarts services if needed

LOG_FILE="/home/fastl/JustLayme/network-monitor.log"
WEBSITE_URL="https://justlay.me"
LOCAL_API="http://localhost:3000"
PROTON_BRIDGE="192.168.0.95:1025"

log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

check_website() {
    if curl -s --max-time 10 "$WEBSITE_URL" > /dev/null; then
        return 0
    else
        return 1
    fi
}

check_local_api() {
    if curl -s --max-time 5 "$LOCAL_API" > /dev/null; then
        return 0
    else
        return 1
    fi
}

check_proton_bridge() {
    if timeout 5 bash -c "</dev/tcp/192.168.0.95/1025" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

restart_api_service() {
    log_message "⚠️  Restarting JustLayMe API service..."
    sudo systemctl restart justlayme-api.service
    sleep 10
}

restart_tunnel_service() {
    log_message "⚠️  Restarting Cloudflare tunnel service..."
    sudo systemctl restart justlayme-tunnel.service
    sleep 15
}

# Main monitoring loop
log_message "🔍 Starting JustLayMe network monitoring..."

while true; do
    # Check Proton Bridge connectivity
    if ! check_proton_bridge; then
        log_message "❌ Proton Bridge unreachable at $PROTON_BRIDGE"
    fi
    
    # Check local API
    if ! check_local_api; then
        log_message "❌ Local API unreachable at $LOCAL_API"
        restart_api_service
        continue
    fi
    
    # Check website accessibility
    if ! check_website; then
        log_message "❌ Website unreachable at $WEBSITE_URL"
        restart_tunnel_service
        
        # Wait and check again
        sleep 30
        if ! check_website; then
            log_message "❌ Website still unreachable, restarting API as well..."
            restart_api_service
            sleep 15
            restart_tunnel_service
        fi
    else
        log_message "✅ All services operational"
    fi
    
    # Wait 60 seconds before next check
    sleep 60
done