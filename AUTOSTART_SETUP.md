# JustLayMe Automatic Startup & Network Management

This documentation explains how to set up automatic startup and network management for JustLayMe.

## 🚀 Quick Setup

To install all automatic services, run:

```bash
cd /home/fastl/JustLayme
./install-services.sh
```

## 📋 Services Created

### 1. **justlayme-api.service**
- Runs the Node.js Character API server
- Automatically starts on boot
- Restarts on failures (up to 5 times per minute)
- Includes all environment variables for Proton Bridge

### 2. **justlayme-tunnel.service** 
- Runs the Cloudflare tunnel
- Depends on API service being running first
- Automatically reconnects on network issues
- Restarts with longer delays for network stability

### 3. **justlayme-monitor.service**
- Monitors website and API connectivity
- Automatically restarts failed services
- Logs all network issues and recovery actions

## 🔧 Manual Service Management

```bash
# Start all services
sudo systemctl start justlayme-api
sudo systemctl start justlayme-tunnel
sudo systemctl start justlayme-monitor

# Stop all services
sudo systemctl stop justlayme-monitor
sudo systemctl stop justlayme-tunnel
sudo systemctl stop justlayme-api

# Check service status
sudo systemctl status justlayme-api
sudo systemctl status justlayme-tunnel
sudo systemctl status justlayme-monitor

# View live logs
sudo journalctl -u justlayme-api -f
sudo journalctl -u justlayme-tunnel -f
sudo journalctl -u justlayme-monitor -f

# Restart a specific service
sudo systemctl restart justlayme-api
```

## 📊 Monitoring & Logs

### Service Logs
- **API Server**: `sudo journalctl -u justlayme-api -f`
- **Cloudflare Tunnel**: `sudo journalctl -u justlayme-tunnel -f`
- **Network Monitor**: `sudo journalctl -u justlayme-monitor -f`

### Monitor Log File
- Location: `/home/fastl/JustLayme/network-monitor.log`
- Contains connectivity checks and restart actions

### Real-time Status
```bash
# Quick status check
systemctl is-active justlayme-api justlayme-tunnel justlayme-monitor

# Detailed status
sudo systemctl status justlayme-*
```

## 🔄 Automatic Features

### On System Boot:
1. **justlayme-api** starts first
2. **justlayme-tunnel** starts after API is ready
3. **justlayme-monitor** starts to watch both services

### On Network Issues:
- Services automatically restart with exponential backoff
- Monitor detects connectivity issues and triggers restarts
- Logs all recovery actions for troubleshooting

### On Service Failures:
- **API failures**: Immediate restart (up to 5 times/minute)
- **Tunnel failures**: Restart with 15-second delay
- **Monitor failures**: Restart with 30-second delay

## 🛠️ Configuration Files

### Environment Variables (in service files):
```bash
BRIDGE_HOST=192.168.0.95
BRIDGE_PORT=1025
EMAIL_USER=please@justlay.me
EMAIL_PASSWORD=m3hmibhwObqUBPq4TOe_jg
```

### Service Dependencies:
- Tunnel waits for API to be running
- Monitor waits for both API and Tunnel
- All services wait for network to be online

## 🧪 Testing Automatic Recovery

```bash
# Test API recovery
sudo systemctl stop justlayme-api
# Watch it restart automatically

# Test tunnel recovery  
sudo systemctl stop justlayme-tunnel
# Watch it restart automatically

# Test network connectivity
# Temporarily disconnect network
# Services will detect and attempt reconnection
```

## 📝 Troubleshooting

### Services Won't Start
```bash
# Check systemd status
sudo systemctl status justlayme-api
sudo systemctl status justlayme-tunnel

# Check logs for errors
sudo journalctl -u justlayme-api --since "5 minutes ago"
```

### Website Not Accessible
```bash
# Check if tunnel is connected
sudo systemctl status justlayme-tunnel

# Check monitor logs
tail -f /home/fastl/JustLayme/network-monitor.log

# Manual tunnel restart
sudo systemctl restart justlayme-tunnel
```

### Email Not Working
```bash
# Check Proton Bridge connectivity
timeout 5 bash -c "</dev/tcp/192.168.0.95/1025"

# Test with different credentials
# Edit service file: sudo systemctl edit justlayme-api
```

## 🔒 Security Features

- Services run as `fastl` user (not root)
- Limited file system access
- Private temp directories
- No new privileges allowed

## ✅ Verification

After installation, verify everything works:

```bash
# Check all services are running
systemctl is-active justlayme-api justlayme-tunnel justlayme-monitor

# Test website accessibility
curl -I https://justlay.me

# Test email functionality
curl -X POST https://justlay.me/api/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
```

The system is now fully automated and will:
- ✅ Start automatically on boot
- ✅ Restart on failures 
- ✅ Reconnect after network issues
- ✅ Monitor and log all activity
- ✅ Maintain high availability