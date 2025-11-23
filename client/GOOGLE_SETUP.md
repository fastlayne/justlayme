# Google Analytics & Search Console Setup Guide

This guide will help you configure Google Analytics 4 (GA4) and Google Search Console for the JustLayMe platform.

## Table of Contents
1. [Google Analytics 4 Setup](#google-analytics-4-setup)
2. [Google Search Console Setup](#google-search-console-setup)
3. [Environment Variables](#environment-variables)
4. [Testing](#testing)

---

## Google Analytics 4 Setup

### Step 1: Create a GA4 Property

1. Go to [Google Analytics](https://analytics.google.com/)
2. Click **Admin** (gear icon in bottom left)
3. Click **Create Property**
4. Fill in the property details:
   - **Property name**: JustLayMe
   - **Reporting time zone**: Select your timezone
   - **Currency**: Select your currency
5. Click **Next** and fill in business details
6. Click **Create** and accept the terms

### Step 2: Get Your Measurement ID

1. In your new property, go to **Admin** → **Data Streams**
2. Click **Add stream** → **Web**
3. Enter your website URL and stream name
4. Click **Create stream**
5. Copy the **Measurement ID** (format: G-XXXXXXXXXX)

### Step 3: Configure in JustLayMe

1. Open `/home/fastl/JustLayMe/client/index.html`
2. Replace **both instances** of `G-XXXXXXXXXX` with your actual Measurement ID:
   ```html
   <script async src="https://www.googletagmanager.com/gtag/js?id=G-YOUR_ACTUAL_ID"></script>
   <script>
     window.dataLayer = window.dataLayer || [];
     function gtag(){dataLayer.push(arguments);}
     gtag('js', new Date());
     gtag('config', 'G-YOUR_ACTUAL_ID', {
       send_page_view: false
     });
   </script>
   ```

3. Create a `.env` file in `/home/fastl/JustLayMe/client/` (copy from `.env.example`):
   ```bash
   cp .env.example .env
   ```

4. Add your Measurement ID to `.env`:
   ```
   VITE_GA_MEASUREMENT_ID=G-YOUR_ACTUAL_ID
   ```

### Step 4: Rebuild and Deploy

```bash
cd /home/fastl/JustLayMe/client
npm run build
```

The build process will use the Measurement ID from your `.env` file and the gtag.js script from `index.html`.

---

## Google Search Console Setup

### Step 1: Add Your Property

1. Go to [Google Search Console](https://search.google.com/search-console)
2. Click **Add Property**
3. Choose **URL prefix** and enter your full site URL (e.g., `https://justlayme.com`)
4. Click **Continue**

### Step 2: Get Verification Code

1. Select **HTML tag** verification method
2. Copy the `content` value from the meta tag
   - Example: `<meta name="google-site-verification" content="abc123xyz..." />`
   - Copy only: `abc123xyz...`

### Step 3: Add Verification Code to JustLayMe

1. Open `/home/fastl/JustLayMe/client/index.html`
2. Find this line:
   ```html
   <meta name="google-site-verification" content="YOUR_VERIFICATION_CODE_HERE" />
   ```
3. Replace `YOUR_VERIFICATION_CODE_HERE` with your actual verification code:
   ```html
   <meta name="google-site-verification" content="abc123xyz..." />
   ```

### Step 4: Rebuild and Deploy

```bash
cd /home/fastl/JustLayMe/client
npm run build
```

### Step 5: Verify in Search Console

1. Return to Google Search Console
2. Click **Verify**
3. Wait for verification (usually instant)
4. Once verified, you'll see "Ownership verified" ✓

---

## Environment Variables

Create a `.env` file in `/home/fastl/JustLayMe/client/`:

```bash
# Google Analytics 4 Measurement ID
VITE_GA_MEASUREMENT_ID=G-YOUR_ACTUAL_ID

# Google OAuth Client ID (if using Google Sign-In)
VITE_GOOGLE_CLIENT_ID=your_client_id.apps.googleusercontent.com

# Other environment variables...
```

**Important**:
- Never commit `.env` to version control
- The `.env` file is already in `.gitignore`
- Use `.env.example` for documentation

---

## Testing

### Test Google Analytics

1. **Development Mode**:
   ```bash
   npm run dev
   ```
   Open browser console and check for GA initialization logs

2. **Check Real-Time Reports**:
   - Go to Google Analytics → Reports → Realtime
   - Visit your site
   - You should see yourself as an active user

3. **Debug with Chrome Extension**:
   - Install [Google Analytics Debugger](https://chrome.google.com/webstore/detail/google-analytics-debugger)
   - Enable the extension
   - Open browser console
   - Navigate your site and check GA events

### Test Google Search Console

1. **Verify Installation**:
   ```bash
   curl -I https://yourdomain.com | grep google-site-verification
   ```

2. **Check in Search Console**:
   - Go to Settings → Ownership verification
   - Ensure your verification method shows as verified

3. **Submit Sitemap** (Optional):
   - In Search Console, go to Sitemaps
   - Submit your sitemap URL (e.g., `https://yourdomain.com/sitemap.xml`)

---

## Tracked Events

The following events are automatically tracked:

### Page Views
- Home page (`/`)
- Login page (`/login`)
- Chat page (`/chat`)
- Black Mirror analysis (`/black-mirror`)
- Premium page (`/premium`)

### User Actions
- Login (with method)
- Sign up (with method)
- Chat message sent
- Character created
- Black Mirror analysis access
- Premium page view
- Purchase/subscription

### Custom Events
See `/home/fastl/JustLayMe/client/src/services/analytics.js` for all available tracking functions.

---

## Troubleshooting

### GA4 Not Tracking

1. **Check browser console** for errors
2. **Verify Measurement ID** is correct in both `index.html` and `.env`
3. **Check ad blockers** - they may block GA
4. **Wait 24-48 hours** for data to appear in reports (real-time should work immediately)

### Search Console Not Verifying

1. **Check meta tag** is in `<head>` section
2. **Verify capitalization** - verification codes are case-sensitive
3. **Clear cache** and rebuild
4. **Check deployed version** has the meta tag (view source)

---

## Security Notes

- Analytics data is anonymized by default
- User IDs are hashed before sending to GA4
- No PII (Personally Identifiable Information) is tracked
- Users can opt-out via browser settings or ad blockers

---

## Additional Resources

- [GA4 Documentation](https://support.google.com/analytics/answer/10089681)
- [Search Console Help](https://support.google.com/webmasters)
- [GA4 Event Reference](https://developers.google.com/analytics/devguides/collection/ga4/events)
