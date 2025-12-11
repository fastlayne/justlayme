# Password Reset Implementation

## Overview

Complete password reset flow implementation with security best practices, rate limiting, and seamless user experience.

## Architecture

### Components

1. **Database Layer** (`/database/migration-password-reset.sql`)
   - `password_reset_tokens` table for secure token storage
   - Token expiration tracking
   - One-time use enforcement
   - IP and user agent logging for security

2. **Backend Service** (`/src/services/password-reset.js`)
   - Secure token generation (32-byte crypto.randomBytes)
   - Token hashing (SHA-256) for database storage
   - Rate limiting (3 requests per hour per IP/email)
   - Email enumeration protection
   - Password validation integration

3. **API Endpoints** (`/src/ai-server.js`)
   - `POST /api/password-reset/request` - Request reset link
   - `GET /api/password-reset/verify` - Verify token validity
   - `POST /api/password-reset/complete` - Complete reset and auto-login

4. **Frontend Components**
   - `/client/src/pages/ForgotPasswordPage.jsx` - Request reset
   - `/client/src/pages/ResetPasswordPage.jsx` - Complete reset
   - Updated `/client/src/pages/LoginPage.jsx` with "Forgot password?" link

## Security Features

### 1. Secure Token Generation
```javascript
// 32-byte cryptographically secure random token
const token = crypto.randomBytes(32).toString('hex')
```

### 2. Token Hashing
```javascript
// SHA-256 hash stored in database, not plain token
const tokenHash = crypto.createHash('sha256').update(token).digest('hex')
```

### 3. Rate Limiting
- 3 requests per hour per IP address
- 3 requests per hour per email
- Prevents brute force and DoS attacks

### 4. Email Enumeration Protection
```javascript
// Always return success message, never reveal if email exists
return {
  success: true,
  message: 'If an account exists with this email, a password reset link has been sent.'
}
```

### 5. Token Expiration
- 1-hour expiration time
- Configurable via `CONFIG.TOKEN_EXPIRY_HOURS`

### 6. One-Time Use Tokens
- Token marked as `used = 1` after successful reset
- Prevents token reuse attacks

### 7. Password Strength Validation
- Minimum 8 characters
- At least one uppercase letter
- At least one lowercase letter
- At least one number
- At least one special character (@$!%*?&#)
- Common password blacklist check

## User Flow

### 1. Request Password Reset
1. User clicks "Forgot password?" on login page
2. Navigates to `/forgot-password`
3. Enters email address
4. System generates secure token and sends email
5. Generic success message displayed (prevents email enumeration)

### 2. Receive Reset Email
1. Email contains reset link: `https://yourapp.com/reset-password?token=<TOKEN>`
2. Link expires in 1 hour
3. Professional email template with security notice

### 3. Complete Password Reset
1. User clicks reset link
2. Token verified on page load
3. User enters new password (with strength validation)
4. Password updated in database
5. Token marked as used
6. User automatically logged in with new JWT
7. Redirected to chat page

## API Endpoints

### POST /api/password-reset/request

Request a password reset link.

**Request Body:**
```json
{
  "email": "user@example.com"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "If an account exists with this email, a password reset link has been sent."
}
```

**Rate Limited Response (429):**
```json
{
  "error": "Too many password reset requests. Please try again later."
}
```

### GET /api/password-reset/verify

Verify if a reset token is valid.

**Query Parameters:**
- `token` - Reset token from email link

**Success Response (200):**
```json
{
  "valid": true,
  "email": "user@example.com"
}
```

**Invalid Token Response (400):**
```json
{
  "valid": false,
  "error": "Invalid or expired reset link"
}
```

### POST /api/password-reset/complete

Complete the password reset.

**Request Body:**
```json
{
  "token": "abc123...",
  "newPassword": "NewSecurePass123!"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Password reset successful",
  "token": "jwt_token_here",
  "user": {
    "id": 123,
    "email": "user@example.com",
    "emailVerified": true,
    "subscriptionStatus": "free",
    "isPremium": false,
    "isAdmin": false
  }
}
```

**Error Response (400):**
```json
{
  "error": "Password must be at least 8 characters with uppercase, lowercase, number, and special character"
}
```

## Database Schema

```sql
CREATE TABLE password_reset_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT UNIQUE NOT NULL,
  email TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  used INTEGER DEFAULT 0,
  created_at TEXT DEFAULT (datetime('now')),
  used_at TEXT,
  ip_address TEXT,
  user_agent TEXT
);

-- Indexes for performance
CREATE INDEX idx_password_reset_token_hash ON password_reset_tokens(token_hash);
CREATE INDEX idx_password_reset_email ON password_reset_tokens(email);
CREATE INDEX idx_password_reset_expires ON password_reset_tokens(expires_at);
```

## Configuration

Edit `/src/services/password-reset.js` to customize:

```javascript
const CONFIG = {
    TOKEN_EXPIRY_HOURS: 1,           // Token expiration time
    MAX_REQUESTS_PER_HOUR: 3,        // Rate limit per IP/email
    TOKEN_LENGTH: 32,                 // Token byte length
    CLEANUP_INTERVAL_HOURS: 6        // Cleanup frequency
};
```

## Email Templates

Email templates are defined in `/src/services/email-service.js`.

The password reset email includes:
- Professional branded design
- Clear reset button
- Security warning about unsolicited requests
- 1-hour expiration notice
- Fallback plain text link

## Frontend Routes

- `/forgot-password` - Request password reset
- `/reset-password?token=<TOKEN>` - Complete password reset
- `/login` - Login page (with "Forgot password?" link)

## Error Handling

### Backend
- All errors logged with context
- Generic messages returned to prevent information disclosure
- Specific validation errors for password strength

### Frontend
- Token verification on page load
- Real-time password validation
- User-friendly error messages
- Loading states for all operations

## Testing the Implementation

### 1. Manual Testing Flow

```bash
# 1. Request password reset
curl -X POST http://localhost:3000/api/password-reset/request \
  -H "Content-Type: application/json" \
  -d '{"email": "test@example.com"}'

# 2. Check email for reset link (or check server logs for token)

# 3. Verify token
curl "http://localhost:3000/api/password-reset/verify?token=YOUR_TOKEN"

# 4. Complete password reset
curl -X POST http://localhost:3000/api/password-reset/complete \
  -H "Content-Type: application/json" \
  -d '{"token": "YOUR_TOKEN", "newPassword": "NewSecure123!"}'
```

### 2. Test Cases

- Valid email, token generated and email sent
- Invalid email format rejected
- Rate limiting after 3 requests
- Expired token rejected
- Used token rejected
- Invalid token rejected
- Weak password rejected
- Successful password reset and auto-login

## Security Considerations

1. **Never store plain tokens** - Only SHA-256 hashes in database
2. **Rate limiting** - Prevents abuse and DoS attacks
3. **Email enumeration protection** - Don't reveal if email exists
4. **Token expiration** - 1-hour limit reduces attack window
5. **One-time use** - Tokens cannot be reused
6. **HTTPS required** - Tokens transmitted over secure connection
7. **IP and user agent logging** - Audit trail for security
8. **Password strength validation** - Prevents weak passwords
9. **Invalidate all tokens** - After successful reset (optional)

## Maintenance

### Cleanup Expired Tokens

The service includes automatic cleanup, but you can manually trigger:

```javascript
const passwordResetService = require('./services/password-reset');
await passwordResetService.cleanupExpiredTokens();
```

### Invalidate User Tokens

To invalidate all reset tokens for a user (e.g., security incident):

```javascript
await passwordResetService.invalidateUserTokens(userId);
```

## Integration with Existing Systems

- Uses existing `EmailService` for email delivery
- Uses existing `authService` for password validation
- Uses existing `Database` singleton for queries
- Uses existing `authLimiter` middleware for rate limiting
- Follows existing authentication patterns (JWT tokens)

## Future Enhancements

1. Two-factor authentication for password reset
2. Email verification before allowing password change
3. Password reset history logging
4. Suspicious activity detection (multiple countries, etc.)
5. Custom email templates per brand
6. SMS-based password reset as alternative
7. Password reset cooldown period
8. Account lockout after multiple failed resets

## Files Modified/Created

### Backend
- `/database/migration-password-reset.sql` - Database schema
- `/src/services/password-reset.js` - Password reset service (NEW)
- `/src/ai-server.js` - API endpoints (MODIFIED)

### Frontend
- `/client/src/pages/ForgotPasswordPage.jsx` - Request reset page (NEW)
- `/client/src/pages/ResetPasswordPage.jsx` - Complete reset page (NEW)
- `/client/src/pages/LoginPage.jsx` - Added "Forgot password?" link (MODIFIED)
- `/client/src/App.jsx` - Added routes (MODIFIED)

## Support

For issues or questions:
1. Check server logs for detailed error messages
2. Verify email service is configured correctly
3. Ensure database migration has been applied
4. Test with curl/Postman before blaming frontend
5. Check browser console for frontend errors
