# JustLayMe Implementation Guide

## Chat History Storage & Professional Email Verification

### Overview

This guide provides a comprehensive implementation plan for adding chat history storage for premium users and professional email verification to the JustLayMe platform.

## 1. Database Schema Updates

### Required Schema Changes

Run the SQL commands in `database-schema-recommendations.sql` to add:

1. **Email Verification Fields** to users table:
   - `email_verified` (BOOLEAN)
   - `email_verification_token` (VARCHAR)
   - `email_verification_expires` (TIMESTAMP)
   - `professional_email` (BOOLEAN)
   - `company_domain` (VARCHAR)

2. **Conversations Table** for organizing chats:
   - Stores conversation metadata
   - Links users to character chats
   - Supports archiving and favorites

3. **Enhanced Messages Table**:
   - Links to conversations via UUID
   - Supports soft delete
   - Tracks model usage and response times

4. **Supporting Tables**:
   - `message_attachments` - For future multimedia support
   - `conversation_tags` - For organization
   - `chat_exports` - For tracking exports
   - `email_verification_logs` - For audit trail

### Migration Steps

```bash
# Connect to PostgreSQL
psql -U justlayme -d justlayme

# Run the schema updates
\i database-schema-recommendations.sql
```

## 2. Email Verification Implementation

### Setup Requirements

1. **Install Dependencies**:
```bash
npm install nodemailer
# OR for production
npm install @sendgrid/mail
```

2. **Environment Variables** to add:
```env
# Email Configuration
EMAIL_USER=your-email@gmail.com
EMAIL_APP_PASSWORD=your-app-specific-password
# OR for SendGrid
SENDGRID_API_KEY=your-sendgrid-api-key

# Frontend URL for verification links
FRONTEND_URL=https://justlay.me
```

3. **Implementation Steps**:

   a. Copy the email service code from `email-verification-implementation.js`
   
   b. Update `character-api.js` to include:
   - Modified registration endpoint
   - Email verification endpoint
   - Resend verification endpoint
   - Email verification middleware

   c. Add verification check to protected routes:
   ```javascript
   app.use('/api/chat', requireEmailVerification);
   app.use('/api/conversations', requireEmailVerification);
   ```

### Professional Email Detection

The system automatically detects professional emails by:
- Excluding common free email providers (Gmail, Yahoo, etc.)
- Checking for company domains
- Auto-upgrading professional emails to premium status

## 3. Chat History Implementation

### Core Features

1. **Conversation Management**:
   - Automatic conversation creation
   - Smart title generation
   - Message pagination
   - Search functionality

2. **Premium Features**:
   - Full conversation history
   - Search across all conversations
   - Export in multiple formats (JSON, TXT, Markdown)
   - Conversation tagging
   - Archive functionality

3. **Free User Limitations**:
   - Access to last 3 conversations only
   - No export functionality
   - Limited search capabilities

### Implementation Steps

1. **Add ConversationManager** to `character-api.js`:
```javascript
const { ConversationManager } = require('./chat-history-implementation');
const conversationManager = new ConversationManager(pg);
```

2. **Update Chat Endpoint** to use conversations:
```javascript
// In the /api/chat endpoint, after getting AI response:
const conversation = await conversationManager.getOrCreateConversation(userId, characterId);

// Store message with conversation UUID
await pg.query(`
    INSERT INTO messages (conversation_uuid, sender_type, content, metadata)
    VALUES ($1, $2, $3, $4)
`, [conversation.id, 'human', message, metadata]);
```

3. **Add New API Endpoints**:
```javascript
// Conversations list
app.get('/api/conversations', authenticateToken, requirePremiumForHistory, 
    (req, res) => chatHistoryEndpoints['/api/conversations'](req, res, pg, conversationManager));

// Conversation messages
app.get('/api/conversations/:id/messages', authenticateToken,
    (req, res) => chatHistoryEndpoints['/api/conversations/:id/messages'](req, res, pg, conversationManager));

// Search
app.get('/api/conversations/search', authenticateToken, requirePremiumForHistory,
    (req, res) => chatHistoryEndpoints['/api/conversations/search'](req, res, pg, conversationManager));

// Export
app.get('/api/conversations/:id/export', authenticateToken,
    (req, res) => chatHistoryEndpoints['/api/conversations/:id/export'](req, res, pg, conversationManager));
```

## 4. Frontend Updates Required

### Email Verification UI

1. **Registration Form Update**:
```javascript
// Show professional email detection
if (EmailVerification.isProfessionalEmail(email)) {
    showMessage("Professional email detected! You'll get premium access after verification.");
}
```

2. **Verification Page** (`/verify-email`):
```html
<div class="verification-container">
    <h2>Verifying your email...</h2>
    <div class="spinner"></div>
</div>
```

3. **Verification Banner** for unverified users:
```html
<div class="verification-banner" v-if="!user.email_verified">
    Please verify your email to access all features.
    <button @click="resendVerification">Resend Email</button>
</div>
```

### Chat History UI

1. **Conversations Sidebar**:
```html
<div class="conversations-sidebar">
    <div class="search-box">
        <input type="text" placeholder="Search conversations..." />
    </div>
    <div class="conversation-list">
        <!-- Conversation items -->
    </div>
</div>
```

2. **Conversation Features**:
   - Load more messages on scroll
   - Export button (premium only)
   - Archive/Delete options
   - Tag management

## 5. Testing Checklist

### Email Verification Testing
- [ ] Register with free email (Gmail) - should remain free user
- [ ] Register with professional email - should get premium pending status
- [ ] Verify email link works correctly
- [ ] Verification expires after 24 hours
- [ ] Resend verification works
- [ ] Can't access premium features without verification

### Chat History Testing
- [ ] Conversations are created automatically
- [ ] Messages are properly linked to conversations
- [ ] Pagination works correctly
- [ ] Search finds messages across conversations
- [ ] Export generates correct formats
- [ ] Free users see limited history
- [ ] Premium users see full history
- [ ] Archive/Delete functions work

## 6. Performance Considerations

### Database Optimizations

1. **Indexes** (already included in schema):
   - User/character conversation lookup
   - Message timestamp ordering
   - Full-text search on message content

2. **Query Optimization**:
   - Use pagination for all list endpoints
   - Implement caching for frequently accessed conversations
   - Consider message summarization for old conversations

### Scalability

1. **Message Storage**:
   - Consider archiving old messages to cold storage
   - Implement message compression for long conversations
   - Use JSONB efficiently for metadata

2. **Email Sending**:
   - Implement queue for bulk email operations
   - Use email service webhooks for delivery tracking
   - Rate limit verification emails per user

## 7. Security Considerations

1. **Email Verification**:
   - Use cryptographically secure tokens
   - Expire tokens after 24 hours
   - Log all verification attempts
   - Rate limit verification endpoints

2. **Chat History**:
   - Verify user ownership on all operations
   - Implement proper access controls
   - Sanitize export data
   - Encrypt sensitive conversation data

## 8. Monitoring & Analytics

### Track Key Metrics

1. **Email Verification**:
   - Verification rate by email domain
   - Time to verify
   - Professional vs free email ratio

2. **Chat History Usage**:
   - Average conversations per user
   - Search usage frequency
   - Export format preferences
   - Storage growth rate

### Implementation Priority

1. **Phase 1** (Immediate):
   - Database schema updates
   - Basic email verification
   - Conversation storage

2. **Phase 2** (Next Sprint):
   - Full chat history UI
   - Search functionality
   - Export features

3. **Phase 3** (Future):
   - Advanced search with filters
   - Conversation insights
   - Multimedia attachments

## Support & Maintenance

### Regular Tasks

1. **Daily**:
   - Monitor email delivery rates
   - Check verification success rates

2. **Weekly**:
   - Review conversation storage growth
   - Clean up expired verification tokens

3. **Monthly**:
   - Archive old conversations
   - Analyze user engagement metrics

### Troubleshooting

Common issues and solutions:

1. **Email not sending**:
   - Check SMTP credentials
   - Verify sender domain
   - Check spam filters

2. **Conversations not loading**:
   - Check database indexes
   - Verify user permissions
   - Check query performance

3. **Export failing**:
   - Check memory limits for large exports
   - Verify file permissions
   - Check export format handlers