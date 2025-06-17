# JustLayMe - AI Chat Platform

## Project Overview
JustLayMe is a premium AI chat platform with multiple character models, Stripe payment integration, and real-time admin monitoring.

## Live URLs
- **Main Site**: https://justlay.me
- **Admin Monitor**: https://justlay.me/admin-monitor (password: admin123)

## Server Configuration
- **Port**: 3000
- **Database**: SQLite
- **WebSocket**: Enabled for real-time monitoring
- **Payment**: Stripe integration with live API keys

## AI Models Available
1. **Layme V1** 🆓 - FREE & Unlimited (default)
2. **LayMe Uncensored** - Premium (3 free messages)
3. **Mythomax Roleplay** - Premium (3 free messages)
4. **FastLayMe** - Premium (3 free messages)

## Stripe Configuration
- **Publishable Key**: [STORED LOCALLY - pk_test_51RaZd...]
- **Secret Key**: [STORED LOCALLY - sk_test_51RaZd...]
- **Pricing**: Monthly $9.99, Yearly $79.99, Lifetime $199

## Server Startup Command
```bash
STRIPE_SECRET_KEY=[SECRET_KEY] nohup node character-api.js > server.log 2>&1 &
```

## Key Features
- **Free Model**: Layme V1 with unlimited messages for all users
- **Premium Models**: 3 free messages, then payment required
- **Real-time Monitoring**: WebSocket-powered admin dashboard
- **User Authentication**: Login/signup with email verification
- **Character Creation**: Premium users can create custom characters
- **Settings & Profile**: Working modals for user preferences
- **Stripe Payments**: Full checkout integration

## File Structure
- `character-api.js` - Main server file
- `index.html` - Main website
- `admin-monitor.html` - Live chat monitoring dashboard
- `server.log` - Server logs
- `database.js` - Database adapter
- `prompt-layer.js` - AI prompt management
- `model-manager.js` - AI model selection

## Working Features
✅ Chat with AI models
✅ User registration/login
✅ Stripe payment processing
✅ Settings modal (works for all users)
✅ Profile modal (requires login)
✅ Character creator (premium only)
✅ Real-time admin monitoring
✅ Free unlimited Layme V1 model
✅ Session tracking
✅ WebSocket live updates

## Admin Functions
- View all live conversations in real-time
- Monitor user activity and model usage
- Track payment conversions
- Session management

## Technical Stack
- **Backend**: Node.js, Express
- **Database**: SQLite
- **Payment**: Stripe
- **WebSocket**: ws library
- **Frontend**: Vanilla JavaScript, HTML5, CSS3
- **AI Models**: Ollama integration

## Recent Changes
- Removed dominant/submissive AI models
- Added Layme V1 as free unlimited default model
- Fixed all button functionality issues
- Implemented live chat monitoring
- Completed Stripe payment integration
- Added proper error handling and user authentication

## Git Repository
- Repository: https://github.com/fastlayne/justlayme.git
- Token: [STORED LOCALLY - ghp_MiuS...]

## Server Status Commands
```bash
# Check server status
ps aux | grep node

# Restart server
pkill -f node && sleep 3 && STRIPE_SECRET_KEY=[SECRET_KEY] nohup node character-api.js > server.log 2>&1 &

# View logs
tail -f server.log

# Test site
curl -I https://justlay.me
```

## Environment Variables
- `STRIPE_SECRET_KEY`: Required for payment processing
- `PORT`: 3000 (default)

Last Updated: June 17, 2025 - All systems operational