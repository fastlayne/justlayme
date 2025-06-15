// Email Verification Implementation for JustLayMe
// This file contains the implementation plan for professional email verification

const nodemailer = require('nodemailer');
const crypto = require('crypto');
const jwt = require('jsonwebtoken');

// Email Service Configuration
class EmailService {
    constructor() {
        // Option 1: Using Gmail SMTP (simple for development)
        this.transporter = nodemailer.createTransport({
            service: 'gmail',
            auth: {
                user: process.env.EMAIL_USER,
                pass: process.env.EMAIL_APP_PASSWORD // App-specific password
            }
        });

        // Option 2: Using SendGrid (recommended for production)
        // const sgMail = require('@sendgrid/mail');
        // sgMail.setApiKey(process.env.SENDGRID_API_KEY);
        // this.sgMail = sgMail;

        // Option 3: Using custom SMTP
        // this.transporter = nodemailer.createTransport({
        //     host: process.env.SMTP_HOST,
        //     port: process.env.SMTP_PORT,
        //     secure: true,
        //     auth: {
        //         user: process.env.SMTP_USER,
        //         pass: process.env.SMTP_PASS
        //     }
        // });
    }

    async sendVerificationEmail(email, verificationToken) {
        const verificationUrl = `${process.env.FRONTEND_URL}/verify-email?token=${verificationToken}`;
        
        const mailOptions = {
            from: '"JustLayMe" <noreply@justlay.me>',
            to: email,
            subject: 'Verify Your Professional Email - JustLayMe',
            html: `
                <!DOCTYPE html>
                <html>
                <head>
                    <style>
                        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
                        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
                        .header { background: linear-gradient(135deg, #6B46FF 0%, #B846FF 100%); color: white; padding: 30px; text-align: center; border-radius: 10px 10px 0 0; }
                        .content { background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px; }
                        .button { display: inline-block; padding: 15px 30px; background: #6B46FF; color: white; text-decoration: none; border-radius: 5px; margin: 20px 0; }
                        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 14px; }
                        .benefits { background: #fff; padding: 20px; border-radius: 8px; margin: 20px 0; }
                        .benefit-item { padding: 10px 0; border-bottom: 1px solid #eee; }
                        .benefit-item:last-child { border-bottom: none; }
                    </style>
                </head>
                <body>
                    <div class="container">
                        <div class="header">
                            <h1>Welcome to JustLayMe Premium</h1>
                            <p>Verify your professional email to unlock exclusive features</p>
                        </div>
                        <div class="content">
                            <h2>Hello Professional!</h2>
                            <p>Thank you for signing up with your professional email. Please verify your email address to access premium features.</p>
                            
                            <div style="text-align: center;">
                                <a href="${verificationUrl}" class="button">Verify Email Address</a>
                            </div>
                            
                            <p>Or copy and paste this link into your browser:</p>
                            <p style="word-break: break-all; background: #f0f0f0; padding: 10px; border-radius: 5px;">${verificationUrl}</p>
                            
                            <div class="benefits">
                                <h3>Your Premium Benefits Include:</h3>
                                <div class="benefit-item">✨ Unlimited conversations with all AI companions</div>
                                <div class="benefit-item">💾 Full conversation history with search</div>
                                <div class="benefit-item">🎨 Custom character creation and training</div>
                                <div class="benefit-item">📊 Advanced conversation analytics</div>
                                <div class="benefit-item">🚀 Priority access to new features</div>
                                <div class="benefit-item">⚡ Faster response times</div>
                            </div>
                            
                            <p><strong>This link will expire in 24 hours for security reasons.</strong></p>
                        </div>
                        <div class="footer">
                            <p>If you didn't create an account with JustLayMe, please ignore this email.</p>
                            <p>&copy; 2025 JustLayMe. All rights reserved.</p>
                        </div>
                    </div>
                </body>
                </html>
            `
        };

        try {
            await this.transporter.sendMail(mailOptions);
            return { success: true };
        } catch (error) {
            console.error('Email send error:', error);
            return { success: false, error: error.message };
        }
    }

    async sendWelcomeEmail(email, isProfessional) {
        const mailOptions = {
            from: '"JustLayMe" <noreply@justlay.me>',
            to: email,
            subject: isProfessional ? 'Welcome to JustLayMe Premium!' : 'Welcome to JustLayMe!',
            html: `
                <h1>Welcome to JustLayMe!</h1>
                <p>Your email has been verified successfully.</p>
                ${isProfessional ? `
                    <h2>Your Premium Features are Now Active!</h2>
                    <p>As a professional user, you now have access to:</p>
                    <ul>
                        <li>Unlimited AI conversations</li>
                        <li>Full conversation history</li>
                        <li>Custom character creation</li>
                        <li>Export conversations</li>
                        <li>Priority support</li>
                    </ul>
                ` : `
                    <p>Start chatting with our AI companions!</p>
                `}
                <p>Visit <a href="https://justlay.me">JustLayMe</a> to get started.</p>
            `
        };

        await this.transporter.sendMail(mailOptions);
    }
}

// Email Verification Functions
class EmailVerification {
    static generateVerificationToken() {
        return crypto.randomBytes(32).toString('hex');
    }

    static isProfessionalEmail(email) {
        // Common free email domains to exclude
        const freeEmailDomains = [
            'gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 
            'aol.com', 'icloud.com', 'mail.com', 'protonmail.com',
            'yandex.com', '163.com', 'qq.com', 'mail.ru'
        ];

        const domain = email.split('@')[1].toLowerCase();
        
        // Check if it's not a free email domain
        const isNotFreeEmail = !freeEmailDomains.includes(domain);
        
        // Additional checks for professional emails
        const hasCompanyDomain = !domain.includes('mail') && !domain.includes('email');
        const hasTLD = domain.includes('.com') || domain.includes('.org') || 
                       domain.includes('.edu') || domain.includes('.gov') ||
                       domain.includes('.io') || domain.includes('.co');

        return isNotFreeEmail && hasCompanyDomain && hasTLD;
    }

    static extractCompanyDomain(email) {
        return email.split('@')[1].toLowerCase();
    }
}

// API Endpoints to add to character-api.js
const emailVerificationEndpoints = {
    // Modified registration endpoint
    '/api/register': async (req, res, pg, emailService) => {
        const { email, password } = req.body;
        
        try {
            const hashedPassword = await bcrypt.hash(password, 10);
            const verificationToken = EmailVerification.generateVerificationToken();
            const isProfessional = EmailVerification.isProfessionalEmail(email);
            const companyDomain = isProfessional ? EmailVerification.extractCompanyDomain(email) : null;
            
            const result = await pg.query(`
                INSERT INTO users (
                    email, 
                    password_hash, 
                    email_verification_token,
                    email_verification_expires,
                    professional_email,
                    company_domain,
                    subscription_status
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7)
                RETURNING id, email, subscription_status, professional_email
            `, [
                email, 
                hashedPassword, 
                verificationToken,
                new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
                isProfessional,
                companyDomain,
                isProfessional ? 'premium_pending' : 'free'
            ]);
            
            const user = result.rows[0];
            
            // Send verification email
            await emailService.sendVerificationEmail(email, verificationToken);
            
            // Log the verification attempt
            await pg.query(`
                INSERT INTO email_verification_logs (user_id, email, action, ip_address, user_agent)
                VALUES ($1, $2, $3, $4, $5)
            `, [user.id, email, 'sent', req.ip, req.headers['user-agent']]);
            
            const token = jwt.sign({ id: user.id, email: user.email }, JWT_SECRET);
            
            res.json({ 
                token, 
                user,
                message: 'Registration successful! Please check your email to verify your account.',
                requiresVerification: true,
                isProfessionalEmail: isProfessional
            });
        } catch (error) {
            if (error.code === '23505') {
                res.status(400).json({ error: 'Email already exists' });
            } else {
                res.status(500).json({ error: 'Registration failed' });
            }
        }
    },

    // Email verification endpoint
    '/api/verify-email': async (req, res, pg, emailService) => {
        const { token } = req.body;
        
        try {
            // Find user with valid token
            const result = await pg.query(`
                SELECT id, email, professional_email 
                FROM users 
                WHERE email_verification_token = $1 
                AND email_verification_expires > NOW()
                AND email_verified = FALSE
            `, [token]);
            
            if (result.rows.length === 0) {
                return res.status(400).json({ error: 'Invalid or expired verification token' });
            }
            
            const user = result.rows[0];
            
            // Update user as verified
            await pg.query(`
                UPDATE users 
                SET email_verified = TRUE,
                    email_verification_token = NULL,
                    email_verification_expires = NULL,
                    subscription_status = CASE 
                        WHEN professional_email = TRUE THEN 'premium'
                        ELSE subscription_status
                    END,
                    subscription_end = CASE
                        WHEN professional_email = TRUE THEN NOW() + INTERVAL '1 year'
                        ELSE subscription_end
                    END
                WHERE id = $1
            `, [user.id]);
            
            // Log verification
            await pg.query(`
                INSERT INTO email_verification_logs (user_id, email, action, ip_address, user_agent)
                VALUES ($1, $2, $3, $4, $5)
            `, [user.id, user.email, 'verified', req.ip, req.headers['user-agent']]);
            
            // Send welcome email
            await emailService.sendWelcomeEmail(user.email, user.professional_email);
            
            const newToken = jwt.sign({ id: user.id, email: user.email, verified: true }, JWT_SECRET);
            
            res.json({
                success: true,
                message: 'Email verified successfully!',
                token: newToken,
                isPremium: user.professional_email,
                user: {
                    id: user.id,
                    email: user.email,
                    subscription_status: user.professional_email ? 'premium' : 'free'
                }
            });
        } catch (error) {
            console.error('Verification error:', error);
            res.status(500).json({ error: 'Verification failed' });
        }
    },

    // Resend verification email
    '/api/resend-verification': async (req, res, pg, emailService) => {
        const { email } = req.body;
        
        try {
            // Check if user exists and needs verification
            const result = await pg.query(`
                SELECT id, email_verified, email_verification_token 
                FROM users 
                WHERE email = $1
            `, [email]);
            
            if (result.rows.length === 0) {
                return res.status(404).json({ error: 'Email not found' });
            }
            
            const user = result.rows[0];
            
            if (user.email_verified) {
                return res.status(400).json({ error: 'Email already verified' });
            }
            
            // Generate new token
            const newToken = EmailVerification.generateVerificationToken();
            
            await pg.query(`
                UPDATE users 
                SET email_verification_token = $1,
                    email_verification_expires = $2
                WHERE id = $3
            `, [newToken, new Date(Date.now() + 24 * 60 * 60 * 1000), user.id]);
            
            // Send email
            await emailService.sendVerificationEmail(email, newToken);
            
            res.json({ message: 'Verification email sent successfully' });
        } catch (error) {
            res.status(500).json({ error: 'Failed to resend verification email' });
        }
    }
};

// Middleware to check email verification
function requireEmailVerification(req, res, next) {
    // This middleware should be added to protected routes
    pg.query(`
        SELECT email_verified FROM users WHERE id = $1
    `, [req.user.id]).then(result => {
        if (result.rows.length > 0 && !result.rows[0].email_verified) {
            return res.status(403).json({ 
                error: 'Email verification required',
                requiresVerification: true 
            });
        }
        next();
    }).catch(err => {
        res.status(500).json({ error: 'Verification check failed' });
    });
}

module.exports = {
    EmailService,
    EmailVerification,
    emailVerificationEndpoints,
    requireEmailVerification
};