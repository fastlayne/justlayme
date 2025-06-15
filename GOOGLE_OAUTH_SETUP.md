# Google OAuth Setup Guide

## 🔐 Setting Up Google Sign-In for JustLayMe

### Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing project
3. Name it "JustLayMe" or similar

### Step 2: Enable Google Sign-In API

1. In Google Cloud Console, go to **APIs & Services** → **Library**
2. Search for "Google+ API" or "Google Sign-In API"
3. Click **Enable**

### Step 3: Create OAuth 2.0 Credentials

1. Go to **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Select **Web application**
4. Configure the OAuth consent screen if prompted:
   - Application name: "JustLayMe"
   - User support email: your email
   - Developer contact: your email

### Step 4: Configure Authorized Origins

**Authorized JavaScript origins:**
```
http://localhost:3000
https://justlay.me
```

**Authorized redirect URIs:**
```
http://localhost:3000
https://justlay.me
```

### Step 5: Get Your Client ID

1. After creating credentials, copy the **Client ID**
2. It looks like: `123456789-abcdefg.apps.googleusercontent.com`

### Step 6: Update JustLayMe Configuration

**Backend (character-api.js):**
```bash
# Set environment variable
export GOOGLE_CLIENT_ID="your-client-id-here"

# Or create .env file
echo "GOOGLE_CLIENT_ID=your-client-id-here" > .env
```

**Frontend (index.html):**
```javascript
// Replace this line in index.html:
client_id: "YOUR_GOOGLE_CLIENT_ID"

// With your actual client ID:
client_id: "123456789-abcdefg.apps.googleusercontent.com"
```

### Step 7: Test Google Sign-In

1. Open https://justlay.me
2. Click "Continue with Google"
3. Should open Google OAuth popup
4. After authentication, user should be logged in

## 🛠️ Current Implementation Status

✅ **Backend Ready:**
- `/api/auth/google` endpoint implemented
- Google ID token verification working
- Automatic account creation for new users
- Existing user linking by email

✅ **Frontend Ready:**
- Beautiful Google Sign-In button
- OAuth popup handling
- Automatic login after verification

⚠️ **Needs Configuration:**
- Google Client ID in environment variables
- Google Client ID in frontend JavaScript
- OAuth consent screen setup

## 🔧 Quick Setup Commands

```bash
# 1. Set environment variable
export GOOGLE_CLIENT_ID="your-client-id-here"

# 2. Update frontend (replace YOUR_GOOGLE_CLIENT_ID)
sed -i 's/YOUR_GOOGLE_CLIENT_ID/your-actual-client-id/' index.html

# 3. Restart server
npm restart
```

## 🚨 Security Notes

- Keep Client ID public (it's meant to be visible)
- Keep Client Secret private (not used in this implementation)
- Only add trusted domains to authorized origins
- Test on both localhost and production domain

## ✅ Testing Checklist

- [ ] Google OAuth consent screen configured
- [ ] Client ID added to backend environment
- [ ] Client ID added to frontend JavaScript
- [ ] Test on localhost:3000
- [ ] Test on production domain (justlay.me)
- [ ] Verify new user creation works
- [ ] Verify existing user login works
- [ ] Check that Google users are auto-verified

## 🆘 Troubleshooting

**"Invalid client ID" error:**
- Check that Client ID is correct in both backend and frontend
- Verify domain is added to authorized origins

**"Popup blocked" error:**
- Ensure user clicks button directly (not from script)
- Check browser popup blocker settings

**"redirect_uri_mismatch" error:**
- Add exact URL to authorized redirect URIs in Google Console
- Include both http://localhost:3000 and https://justlay.me