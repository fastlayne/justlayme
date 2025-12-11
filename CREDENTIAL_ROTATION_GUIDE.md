# CRITICAL: Credential Rotation Required

## Security Alert
The .env file contains live production credentials. While it's in .gitignore, these credentials need rotation as a security best practice.

## Credentials to Rotate Immediately

### 1. Stripe Keys
- `STRIPE_SECRET_KEY` - Generate new key at https://dashboard.stripe.com/apikeys
- `STRIPE_PUBLISHABLE_KEY` - Regenerate with new secret
- `STRIPE_WEBHOOK_SECRET` - Regenerate webhook endpoint secret
- **Update all Price IDs** if changed

### 2. JWT & Session Secrets
```bash
# Generate new secure secrets (64 bytes recommended):
openssl rand -base64 64 > jwt_secret.txt
openssl rand -base64 64 > session_secret.txt
openssl rand -base64 64 > cookie_secret.txt
```

### 3. Email Credentials
- Review `EMAIL_USER` and `EMAIL_PASSWORD`
- Consider using app-specific passwords

### 4. Admin PIN
- Change `ADMIN_PIN` to new secure PIN
- Document securely in password manager

### 5. Google OAuth
- Rotate `GOOGLE_CLIENT_ID` and `GOOGLE_CLIENT_SECRET` if exposed
- Update OAuth consent screen

## Rotation Steps
1. Generate all new credentials
2. Update .env file
3. Update production environment variables
4. Restart services: `npm run restart` or `pm2 restart all`
5. Test all functionality
6. Invalidate old credentials at providers

## Post-Rotation Verification
- [ ] Stripe webhooks working
- [ ] User login functional
- [ ] Google OAuth working
- [ ] Email sending functional
- [ ] Admin panel accessible
