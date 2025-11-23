/**
 * 📧 Clean Email Service Architecture for JustLayMe
 * No bandaids, no spaghetti code - just clean, maintainable architecture
 *
 * @module EmailService
 * @description Handles all email operations with proper separation of concerns
 */

// Load environment variables if not already loaded
if (!process.env.EMAIL_USER) {
    require('dotenv').config();
}

const nodemailer = require('nodemailer');
const crypto = require('crypto');

/**
 * Email Service Configuration Interface
 * @typedef {Object} EmailConfig
 * @property {string} provider - Email provider type (gmail, smtp, disabled)
 * @property {string} from - From email address
 * @property {string} adminEmail - Admin notification email
 * @property {Object} smtp - SMTP configuration
 */

/**
 * Clean Email Service Class
 * Single responsibility: Handle all email operations
 */
class EmailService {
    constructor() {
        this.config = this._loadConfiguration();
        this.transporter = null;
        this.isConfigured = false;

        // Initialize transporter if configured
        if (this.config.provider !== 'disabled') {
            this._initializeTransporter();
        }
    }

    /**
     * Load email configuration from environment
     * Clean separation of configuration logic
     */
    _loadConfiguration() {
        const config = {
            provider: 'disabled',
            from: process.env.EMAIL_FROM || 'JustLayMe <notifications@justlay.me>',
            adminEmail: process.env.ADMIN_EMAIL || null,
            smtp: {
                host: process.env.SMTP_HOST || 'smtp.gmail.com',
                port: parseInt(process.env.SMTP_PORT) || 587,
                secure: process.env.SMTP_SECURE === 'true',
                user: process.env.EMAIL_USER,
                pass: process.env.EMAIL_APP_PASSWORD
            }
        };

        // Determine provider based on configuration
        if (config.smtp.user && config.smtp.pass &&
            !config.smtp.pass.includes('YOUR_APP_PASSWORD')) {

            if (config.smtp.user.includes('@gmail.com')) {
                config.provider = 'gmail';
            } else if (config.smtp.host.includes('brevo.com')) {
                config.provider = 'brevo';
            } else {
                config.provider = 'smtp';
            }
        }

        return config;
    }

    /**
     * Initialize email transporter
     * Clean initialization with proper error handling
     */
    _initializeTransporter() {
        try {
            // Debug: Check if nodemailer is available
            if (typeof nodemailer === 'undefined') {
                throw new Error('nodemailer is not defined in scope');
            }
            if (this.config.provider === 'gmail') {
                // Gmail-specific configuration
                this.transporter = nodemailer.createTransport({
                    service: 'gmail',
                    auth: {
                        user: this.config.smtp.user,
                        pass: this.config.smtp.pass
                    }
                });
                console.log('✅ Email Service: Gmail configured successfully');
            } else if (this.config.provider === 'brevo') {
                // Brevo-specific configuration (optimal for transactional emails)
                this.transporter = nodemailer.createTransport({
                    host: this.config.smtp.host,
                    port: this.config.smtp.port,
                    secure: false, // Brevo uses STARTTLS
                    auth: {
                        user: this.config.smtp.user,
                        pass: this.config.smtp.pass
                    },
                    tls: {
                        ciphers: 'SSLv3' // Brevo compatibility
                    }
                });
                console.log('✅ Email Service: Brevo configured successfully');
            } else if (this.config.provider === 'smtp') {
                // Generic SMTP configuration
                this.transporter = nodemailer.createTransport({
                    host: this.config.smtp.host,
                    port: this.config.smtp.port,
                    secure: this.config.smtp.secure,
                    auth: {
                        user: this.config.smtp.user,
                        pass: this.config.smtp.pass
                    }
                });
                console.log(`✅ Email Service: SMTP configured (${this.config.smtp.host})`);
            }

            this.isConfigured = true;
        } catch (error) {
            console.error('❌ Email Service: Initialization failed', error.message);
            this.isConfigured = false;
        }
    }

    /**
     * Test email connection
     * @returns {Promise<{success: boolean, message: string}>}
     */
    async testConnection() {
        if (!this.isConfigured || !this.transporter) {
            return {
                success: false,
                message: 'Email service not configured'
            };
        }

        try {
            await this.transporter.verify();
            return {
                success: true,
                message: 'Email connection successful'
            };
        } catch (error) {
            return {
                success: false,
                message: error.message
            };
        }
    }

    /**
     * Send verification email
     * Clean method with single responsibility
     */
    async sendVerificationEmail(email, token) {
        const verificationUrl = `${process.env.APP_URL || 'https://justlay.me'}/verify-email?token=${token}`;

        const html = `
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; text-align: center; }
                    .content { background: #f7f7f7; padding: 30px; border-radius: 0 0 10px 10px; }
                    .button { display: inline-block; padding: 12px 30px; background: #667eea; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                    .footer { text-align: center; color: #666; font-size: 12px; margin-top: 20px; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🔥 Welcome to JustLayMe</h1>
                        <p>The Uncensored AI Experience</p>
                    </div>
                    <div class="content">
                        <h2>Verify Your Email</h2>
                        <p>Click the button below to verify your email and unlock all features:</p>
                        <center>
                            <a href="${verificationUrl}" class="button">Verify Email</a>
                        </center>
                        <p style="color: #666; font-size: 14px;">Or copy this link: ${verificationUrl}</p>
                        <p style="margin-top: 30px;">This link expires in 24 hours.</p>
                    </div>
                    <div class="footer">
                        <p>© 2024 JustLayMe - Uncensored AI Conversations</p>
                    </div>
                </div>
            </body>
            </html>
        `;

        return this._sendEmail(
            email,
            '🔥 Verify Your JustLayMe Account',
            html,
            `Verify your email: ${verificationUrl}`
        );
    }

    /**
     * Send password reset email
     * Clean method for password recovery
     */
    async sendPasswordResetEmail(email, token) {
        const resetUrl = `${process.env.APP_URL || 'https://justlay.me'}/reset-password?token=${token}`;

        const html = `
            <!DOCTYPE html>
            <html>
            <head>
                <style>
                    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; }
                    .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                    .header { background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%); color: white; padding: 30px; border-radius: 10px 10px 0 0; text-align: center; }
                    .content { background: #f7f7f7; padding: 30px; border-radius: 0 0 10px 10px; }
                    .button { display: inline-block; padding: 12px 30px; background: #f5576c; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                    .warning { background: #fff3cd; border-left: 4px solid #ffc107; padding: 10px; margin: 20px 0; }
                </style>
            </head>
            <body>
                <div class="container">
                    <div class="header">
                        <h1>🔐 Password Reset Request</h1>
                        <p>JustLayMe Account Recovery</p>
                    </div>
                    <div class="content">
                        <h2>Reset Your Password</h2>
                        <p>Someone requested a password reset for your account. If this was you, click the button below:</p>
                        <center>
                            <a href="${resetUrl}" class="button">Reset Password</a>
                        </center>
                        <div class="warning">
                            <strong>⚠️ Security Notice:</strong><br>
                            If you didn't request this, you can safely ignore this email.
                            Your password won't be changed.
                        </div>
                        <p style="color: #666; font-size: 14px;">This link expires in 1 hour for security.</p>
                    </div>
                </div>
            </body>
            </html>
        `;

        return this._sendEmail(
            email,
            '🔐 JustLayMe Password Reset',
            html,
            `Reset your password: ${resetUrl}`
        );
    }

    /**
     * Core email sending method
     * Clean, reusable, with proper error handling
     */
    async _sendEmail(to, subject, html, text) {
        // Check if service is configured
        if (!this.isConfigured || !this.transporter) {
            console.warn(`📧 Email not sent (service disabled): ${subject} to ${to}`);
            return {
                success: false,
                error: 'Email service not configured',
                fallbackUrl: text.match(/https?:\/\/[^\s]+/)?.[0]
            };
        }

        try {
            const mailOptions = {
                from: `"JustLayMe" <${this.config.from}>`,
                to: to,
                subject: subject,
                html: html,
                text: text
            };

            const info = await this.transporter.sendMail(mailOptions);
            console.log(`✅ Email sent: ${subject} to ${to} (${info.messageId})`);

            return {
                success: true,
                messageId: info.messageId
            };
        } catch (error) {
            console.error(`❌ Email failed: ${subject} to ${to}`, error.message);

            return {
                success: false,
                error: error.message,
                fallbackUrl: text.match(/https?:\/\/[^\s]+/)?.[0]
            };
        }
    }

    /**
     * Generate secure verification token
     * @returns {string} Hex token
     */
    static generateToken() {
        return crypto.randomBytes(32).toString('hex');
    }

    /**
     * Check if email is professional (not free provider)
     * @param {string} email
     * @returns {boolean}
     */
    static isProfessionalEmail(email) {
        const freeProviders = [
            'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com',
            'aol.com', 'icloud.com', 'protonmail.com', 'mail.ru'
        ];

        const domain = email.split('@')[1]?.toLowerCase();
        return domain && !freeProviders.includes(domain);
    }
}

// Export singleton instance
module.exports = new EmailService();