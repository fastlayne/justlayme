# Email Setup Guide for JustLayMe

## 📧 Setting Up Email Verification

### Option 1: Gmail SMTP (Recommended for Development)

**Step 1: Enable 2-Factor Authentication**
1. Go to [Google Account Settings](https://myaccount.google.com/)
2. Security → 2-Step Verification → Turn On

**Step 2: Generate App Password**
1. Google Account → Security → 2-Step Verification
2. At bottom, click "App passwords"
3. Select app: "Mail" and device: "Other"
4. Name it: "JustLayMe"
5. Copy the 16-character password

**Step 3: Configure Environment**
```bash
export EMAIL_USER="your-email@gmail.com"
export EMAIL_PASSWORD="your-16-char-app-password"
```

### Option 2: SendGrid (Recommended for Production)

**Step 1: Create SendGrid Account**
1. Go to [SendGrid](https://sendgrid.com/)
2. Create free account (100 emails/day)

**Step 2: Create API Key**
1. SendGrid Dashboard → Settings → API Keys
2. Create API Key with "Mail Send" permissions
3. Copy the API key

**Step 3: Update Code**
```javascript
// Replace in character-api.js
const sgMail = require('@sendgrid/mail');
sgMail.setApiKey(process.env.SENDGRID_API_KEY);
```

### Option 3: Custom SMTP

```bash
export EMAIL_USER="your-email@yourdomain.com"
export EMAIL_PASSWORD="your-smtp-password"
export SMTP_HOST="smtp.yourdomain.com"
export SMTP_PORT="587"
```

## 🛠️ Current Implementation

✅ **Email System Ready:**
- Beautiful HTML email templates
- Verification token generation (64-char hex)
- 24-hour token expiration
- Resend verification functionality
- Email verification logging

✅ **Email Templates:**
- Welcome email with verification link
- Clean, professional design
- Mobile-responsive
- Verification expiration warnings

⚠️ **Needs Configuration:**
- SMTP credentials in environment variables
- Testing with real email service

## 🔧 Quick Setup (Gmail)

```bash
# 1. Set environment variables
export EMAIL_USER="your-email@gmail.com"
export EMAIL_PASSWORD="your-app-password"

# 2. Test email sending
curl -X POST http://localhost:3000/api/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

# 3. Check if email was sent
echo "Check your Gmail sent folder"
```

## ✅ Testing Checklist

- [ ] Gmail 2FA enabled
- [ ] App password generated
- [ ] Environment variables set
- [ ] Test registration sends email
- [ ] Email contains verification link
- [ ] Verification link works
- [ ] Token expires after 24 hours
- [ ] Resend verification works

## 🚨 Security Notes

- Never commit email credentials to git
- Use app passwords, not account passwords
- Test with disposable email first
- Set up proper SPF/DKIM for production

## 📝 Email Template Preview

**Subject:** Verify Your JustLayMe Account

**Content:**
```
Welcome to JustLayMe!

Thanks for joining JustLayMe! To complete your registration 
and start chatting with our AI companions, please verify 
your email address.

[Verify Email Address] <- Button

This verification link will expire in 24 hours.
```

## 🆘 Troubleshooting

**"Auth failed" error:**
- Double-check app password (not account password)
- Ensure 2FA is enabled
- Try generating new app password

**Emails going to spam:**
- Set up SPF record for your domain
- Use reputable SMTP service like SendGrid
- Avoid spam trigger words

**"Connection refused" error:**
- Check firewall settings
- Verify SMTP host and port
- Test SMTP credentials separately