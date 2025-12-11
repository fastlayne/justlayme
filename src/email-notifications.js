/**
 * Admin Notification Service for JustLayMe
 *
 * ARCHITECTURAL DESIGN:
 * - Uses the singleton EmailService from ./services/email-service.js
 * - No duplicate transporter configuration
 * - Single source of truth for email sending
 * - Separation of concerns: this service handles admin notification CONTENT,
 *   the EmailService handles the actual TRANSPORT
 */

// Use the existing EmailService singleton (configured with Brevo SMTP)
const emailService = require('./services/email-service');

class AdminNotificationService {
    constructor() {
        this.adminEmail = process.env.ADMIN_EMAIL || 'mrweant@pm.me';
        this.fromName = 'JustLayMe Admin';

        // Log initialization status
        if (emailService.isConfigured) {
            console.log(`✅ Admin Notification Service: Ready (sending to ${this.adminEmail})`);
        } else {
            console.warn(`⚠️ Admin Notification Service: Email service not configured - notifications will be logged only`);
        }
    }

    /**
     * Internal method to send admin emails
     * Uses the EmailService singleton for actual transport
     */
    async _sendAdminEmail(subject, html, text = null) {
        const plainText = text || this._stripHtml(html);

        // Always log the notification for audit trail
        console.log(`📧 ADMIN NOTIFICATION: ${subject}`);

        // Use the existing email service's internal send method
        // The EmailService handles the actual SMTP transport
        return emailService._sendEmail(this.adminEmail, subject, html, plainText);
    }

    /**
     * Strip HTML tags for plain text version
     */
    _stripHtml(html) {
        return html.replace(/<[^>]*>?/gm, '').replace(/\s+/g, ' ').trim();
    }

    /**
     * Generate styled email wrapper for admin notifications
     */
    _wrapInTemplate(title, content) {
        return `
        <div style="font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 600px; margin: 0 auto; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 2px; border-radius: 12px;">
            <div style="background: #1a1a1a; padding: 30px; border-radius: 10px;">
                <h1 style="color: #fff; margin: 0 0 20px; font-size: 24px; text-align: center;">
                    ${title}
                </h1>
                ${content}
                <p style="color: #6b7280; font-size: 12px; text-align: center; margin-top: 30px; border-top: 1px solid #333; padding-top: 20px;">
                    JustLayMe Admin Notification System<br>
                    <span style="color: #4b5563;">${new Date().toISOString()}</span>
                </p>
            </div>
        </div>
        `;
    }

    /**
     * Send notification when a new user registers
     * @param {Object} userInfo - User details { email, screenName, id, subscription, ip }
     */
    async notifyNewUser(userInfo) {
        const subject = `🆕 New User Registration - ${userInfo.email}`;

        const content = `
            <div style="background: #2a2a2a; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h2 style="color: #9ca3af; font-size: 14px; margin: 0 0 15px; text-transform: uppercase; letter-spacing: 1px;">
                    User Details
                </h2>
                <table style="width: 100%; border-collapse: collapse;">
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Email</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${userInfo.email}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Screen Name</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${userInfo.screenName || 'Not provided'}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">User ID</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${userInfo.id}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Subscription</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${userInfo.subscription || 'Free'}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">IP Address</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${userInfo.ip || 'Unknown'}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0;">Registration Time</td><td style="color: #fff; padding: 8px 0;">${new Date().toLocaleString()}</td></tr>
                </table>
            </div>
            <div style="text-align: center; margin-top: 20px;">
                <a href="https://justlay.me/admin" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #fff; padding: 12px 30px; border-radius: 6px; text-decoration: none; font-weight: 600;">
                    View Admin Dashboard
                </a>
            </div>
        `;

        const html = this._wrapInTemplate('🎉 New User Registration', content);
        return this._sendAdminEmail(subject, html);
    }

    /**
     * Send notification when a new conversation is created
     * @param {Object} conversationInfo - Conversation details
     */
    async notifyNewConversation(conversationInfo) {
        const subject = `💬 New Conversation - ${conversationInfo.character}`;

        const content = `
            <div style="background: #2a2a2a; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h2 style="color: #9ca3af; font-size: 14px; margin: 0 0 15px; text-transform: uppercase; letter-spacing: 1px;">
                    Conversation Details
                </h2>
                <table style="width: 100%; border-collapse: collapse;">
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">User Email</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${conversationInfo.userEmail}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">User ID</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${conversationInfo.userId}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Character</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${conversationInfo.character}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Conversation ID</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${conversationInfo.id}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0;">Started</td><td style="color: #fff; padding: 8px 0;">${new Date().toLocaleString()}</td></tr>
                </table>
            </div>
            ${conversationInfo.firstMessage ? `
            <div style="background: #2a2a2a; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h2 style="color: #9ca3af; font-size: 14px; margin: 0 0 15px; text-transform: uppercase; letter-spacing: 1px;">
                    First Message
                </h2>
                <p style="color: #fff; margin: 0; line-height: 1.6; font-style: italic;">
                    "${conversationInfo.firstMessage.substring(0, 200)}${conversationInfo.firstMessage.length > 200 ? '...' : ''}"
                </p>
            </div>
            ` : ''}
        `;

        const html = this._wrapInTemplate('💬 New Conversation Started', content);
        return this._sendAdminEmail(subject, html);
    }

    /**
     * Send notification when a new character is created
     * @param {Object} characterInfo - Character details
     */
    async notifyNewCharacter(characterInfo) {
        const subject = `🎭 New Character Created - ${characterInfo.name}`;

        const content = `
            <div style="background: #2a2a2a; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h2 style="color: #9ca3af; font-size: 14px; margin: 0 0 15px; text-transform: uppercase; letter-spacing: 1px;">
                    Character Details
                </h2>
                <table style="width: 100%; border-collapse: collapse;">
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Name</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${characterInfo.name}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Character ID</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${characterInfo.id}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Created By</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${characterInfo.userEmail}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">User ID</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${characterInfo.userId}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Category</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${characterInfo.category || 'Custom'}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0;">Created</td><td style="color: #fff; padding: 8px 0;">${new Date().toLocaleString()}</td></tr>
                </table>
            </div>
            ${characterInfo.description ? `
            <div style="background: #2a2a2a; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h2 style="color: #9ca3af; font-size: 14px; margin: 0 0 15px; text-transform: uppercase; letter-spacing: 1px;">
                    Description
                </h2>
                <p style="color: #fff; margin: 0; line-height: 1.6;">
                    "${characterInfo.description.substring(0, 300)}${characterInfo.description.length > 300 ? '...' : ''}"
                </p>
            </div>
            ` : ''}
            <div style="text-align: center; margin-top: 20px;">
                <a href="https://justlay.me/admin" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #fff; padding: 12px 30px; border-radius: 6px; text-decoration: none; font-weight: 600;">
                    View Admin Dashboard
                </a>
            </div>
        `;

        const html = this._wrapInTemplate('🎭 New Character Created', content);
        return this._sendAdminEmail(subject, html);
    }

    /**
     * Send notification for new premium subscription
     * @param {Object} subscriptionInfo - Subscription details
     */
    async notifyNewPremiumSubscription(subscriptionInfo) {
        const subject = `💎 New Premium Subscription - ${subscriptionInfo.email}`;

        const content = `
            <div style="background: #2a2a2a; padding: 20px; border-radius: 8px; margin-bottom: 20px;">
                <h2 style="color: #9ca3af; font-size: 14px; margin: 0 0 15px; text-transform: uppercase; letter-spacing: 1px;">
                    Subscription Details
                </h2>
                <table style="width: 100%; border-collapse: collapse;">
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Email</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${subscriptionInfo.email}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">User ID</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${subscriptionInfo.userId}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Plan</td><td style="color: #fff; padding: 8px 0; border-bottom: 1px solid #333;">${subscriptionInfo.plan || 'Premium'}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0; border-bottom: 1px solid #333;">Amount</td><td style="color: #10b981; padding: 8px 0; border-bottom: 1px solid #333; font-weight: bold;">$${subscriptionInfo.amount || '9.99'}</td></tr>
                    <tr><td style="color: #9ca3af; padding: 8px 0;">Subscribed At</td><td style="color: #fff; padding: 8px 0;">${new Date().toLocaleString()}</td></tr>
                </table>
            </div>
            <div style="text-align: center; margin-top: 20px;">
                <a href="https://dashboard.stripe.com" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #fff; padding: 12px 30px; border-radius: 6px; text-decoration: none; font-weight: 600;">
                    View in Stripe
                </a>
            </div>
        `;

        const html = this._wrapInTemplate('💎 New Premium Subscription!', content);
        return this._sendAdminEmail(subject, html);
    }

    /**
     * Check if the notification service is operational
     * @returns {boolean}
     */
    isOperational() {
        return emailService.isConfigured;
    }

    /**
     * Get service status for health checks
     */
    getStatus() {
        return {
            operational: this.isOperational(),
            adminEmail: this.adminEmail,
            emailServiceProvider: emailService.config?.provider || 'unknown'
        };
    }
}

// Export singleton instance
module.exports = new AdminNotificationService();
