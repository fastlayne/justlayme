/**
 * Configuration Validator
 *
 * ARCHITECTURAL SOLUTION: Proper validation of critical configuration
 * This module validates all critical environment variables at startup
 * and prevents the application from running with placeholder values.
 *
 * NO-BANDAID POLICY: This is a proper architectural fix that:
 * - Validates configuration at the earliest possible point
 * - Provides clear, actionable error messages
 * - Prevents runtime failures from missing configuration
 * - Supports both required and optional configurations
 */

const fs = require('fs');
const path = require('path');

class ConfigValidator {
    constructor() {
        this.errors = [];
        this.warnings = [];
        this.validatedConfig = {};
    }

    /**
     * Validate all critical configuration
     * @returns {Object} Validation result with errors, warnings, and validated config
     */
    validate() {
        this.errors = [];
        this.warnings = [];
        
        // Database Configuration
        this.validateDatabase();
        
        // Stripe Configuration (Critical for payments)
        this.validateStripe();
        
        // Email Configuration
        this.validateEmail();
        
        // Security Configuration
        this.validateSecurity();
        
        // Server Configuration
        this.validateServer();
        
        // AI Configuration
        this.validateAI();
        
        return {
            valid: this.errors.length === 0,
            errors: this.errors,
            warnings: this.warnings,
            config: this.validatedConfig
        };
    }

    /**
     * Validate database configuration
     */
    validateDatabase() {
        const dbUrl = process.env.DATABASE_URL;
        if (!dbUrl) {
            this.errors.push('DATABASE_URL is not configured');
        } else {
            this.validatedConfig.DATABASE_URL = dbUrl;
            
            // Validate SQLite database file exists if using SQLite
            if (dbUrl.startsWith('sqlite:')) {
                const dbPath = dbUrl.replace('sqlite:', '');
                const absolutePath = path.isAbsolute(dbPath)
                    ? dbPath
                    : path.join(process.cwd(), dbPath);

                const dbDir = path.dirname(absolutePath);
                if (!fs.existsSync(dbDir)) {
                    this.errors.push(`Database directory does not exist: ${dbDir}`);
                } else {
                    // Verify directory is writable
                    try {
                        fs.accessSync(dbDir, fs.constants.W_OK);
                    } catch (error) {
                        this.errors.push(`Database directory is not writable: ${dbDir}`);
                    }
                }
            }
        }
        
        // Pool size (optional but recommended)
        const poolSize = process.env.DATABASE_POOL_SIZE;
        if (!poolSize) {
            this.warnings.push('DATABASE_POOL_SIZE not set, defaulting to 10');
            this.validatedConfig.DATABASE_POOL_SIZE = 10;
        } else {
            const size = parseInt(poolSize, 10);
            if (isNaN(size) || size < 1 || size > 100) {
                this.errors.push('DATABASE_POOL_SIZE must be between 1 and 100');
            } else {
                this.validatedConfig.DATABASE_POOL_SIZE = size;
            }
        }
    }

    /**
     * Validate Stripe configuration
     * CRITICAL: Detects placeholder keys and prevents startup
     */
    validateStripe() {
        const secretKey = process.env.STRIPE_SECRET_KEY;
        const publishableKey = process.env.STRIPE_PUBLISHABLE_KEY;
        const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET;
        const priceId = process.env.STRIPE_PREMIUM_PRICE_ID;
        
        // Check for missing keys
        if (!secretKey) {
            this.errors.push('STRIPE_SECRET_KEY is not configured');
        } else if (this.isPlaceholder(secretKey)) {
            this.errors.push('STRIPE_SECRET_KEY contains placeholder value. Please set actual Stripe secret key.');
        } else if (!secretKey.startsWith('sk_')) {
            this.errors.push('STRIPE_SECRET_KEY appears invalid (should start with sk_live_ or sk_test_)');
        } else {
            this.validatedConfig.STRIPE_SECRET_KEY = secretKey;
        }
        
        if (!publishableKey) {
            this.errors.push('STRIPE_PUBLISHABLE_KEY is not configured');
        } else if (this.isPlaceholder(publishableKey)) {
            this.errors.push('STRIPE_PUBLISHABLE_KEY contains placeholder value. Please set actual Stripe publishable key.');
        } else if (!publishableKey.startsWith('pk_')) {
            this.errors.push('STRIPE_PUBLISHABLE_KEY appears invalid (should start with pk_live_ or pk_test_)');
        } else {
            this.validatedConfig.STRIPE_PUBLISHABLE_KEY = publishableKey;
        }
        
        if (!webhookSecret) {
            this.warnings.push('STRIPE_WEBHOOK_SECRET not configured - webhook validation disabled');
        } else if (this.isPlaceholder(webhookSecret)) {
            this.errors.push('STRIPE_WEBHOOK_SECRET contains placeholder value. Please set actual webhook secret.');
        } else if (!webhookSecret.startsWith('whsec_')) {
            this.errors.push('STRIPE_WEBHOOK_SECRET appears invalid (should start with whsec_)');
        } else {
            this.validatedConfig.STRIPE_WEBHOOK_SECRET = webhookSecret;
        }
        
        if (!priceId) {
            this.warnings.push('STRIPE_PREMIUM_PRICE_ID not configured - premium features disabled');
        } else if (this.isPlaceholder(priceId)) {
            this.errors.push('STRIPE_PREMIUM_PRICE_ID contains placeholder value. Please set actual price ID.');
        } else if (!priceId.startsWith('price_')) {
            this.errors.push('STRIPE_PREMIUM_PRICE_ID appears invalid (should start with price_)');
        } else {
            this.validatedConfig.STRIPE_PREMIUM_PRICE_ID = priceId;
        }
    }

    /**
     * Validate email configuration
     */
    validateEmail() {
        const emailUser = process.env.EMAIL_USER;
        const emailPassword = process.env.EMAIL_PASSWORD || process.env.EMAIL_APP_PASSWORD;
        const smtpHost = process.env.SMTP_HOST;
        const smtpPort = process.env.SMTP_PORT;
        
        if (!emailUser) {
            this.warnings.push('EMAIL_USER not configured - email features disabled');
        } else {
            this.validatedConfig.EMAIL_USER = emailUser;
            
            if (!emailPassword) {
                this.warnings.push('EMAIL_PASSWORD/EMAIL_APP_PASSWORD not configured - email sending disabled');
            } else if (this.isPlaceholder(emailPassword)) {
                this.warnings.push('EMAIL_PASSWORD contains placeholder value - email sending disabled');
            } else {
                this.validatedConfig.EMAIL_PASSWORD = emailPassword;
            }
            
            if (!smtpHost) {
                this.validatedConfig.SMTP_HOST = '127.0.0.1'; // Default
            } else {
                this.validatedConfig.SMTP_HOST = smtpHost;
            }
            
            if (!smtpPort) {
                this.validatedConfig.SMTP_PORT = 1025; // Default
            } else {
                this.validatedConfig.SMTP_PORT = parseInt(smtpPort, 10);
            }
        }
    }

    /**
     * Validate security configuration
     */
    validateSecurity() {
        const jwtSecret = process.env.JWT_SECRET;
        const sessionSecret = process.env.SESSION_SECRET;
        const cookieSecret = process.env.COOKIE_SECRET;
        const adminPin = process.env.ADMIN_PIN;
        
        if (!jwtSecret || jwtSecret.length < 32) {
            this.errors.push('JWT_SECRET must be at least 32 characters long');
        } else {
            this.validatedConfig.JWT_SECRET = jwtSecret;
        }
        
        if (!sessionSecret || sessionSecret.length < 32) {
            this.errors.push('SESSION_SECRET must be at least 32 characters long');
        } else {
            this.validatedConfig.SESSION_SECRET = sessionSecret;
        }
        
        if (!cookieSecret || cookieSecret.length < 32) {
            this.warnings.push('COOKIE_SECRET should be at least 32 characters long');
        } else {
            this.validatedConfig.COOKIE_SECRET = cookieSecret;
        }
        
        if (!adminPin || adminPin.length < 4) {
            this.warnings.push('ADMIN_PIN should be at least 4 characters long');
        } else {
            this.validatedConfig.ADMIN_PIN = adminPin;
        }
    }

    /**
     * Validate server configuration
     */
    validateServer() {
        const nodeEnv = process.env.NODE_ENV;
        const port = process.env.PORT;
        
        if (!nodeEnv) {
            this.warnings.push('NODE_ENV not set, defaulting to development');
            this.validatedConfig.NODE_ENV = 'development';
        } else if (!['development', 'production', 'test'].includes(nodeEnv)) {
            this.warnings.push(`Unusual NODE_ENV value: ${nodeEnv}`);
            this.validatedConfig.NODE_ENV = nodeEnv;
        } else {
            this.validatedConfig.NODE_ENV = nodeEnv;
        }
        
        if (!port) {
            this.validatedConfig.PORT = 3333; // Default
        } else {
            const portNum = parseInt(port, 10);
            if (isNaN(portNum) || portNum < 1 || portNum > 65535) {
                this.errors.push('PORT must be between 1 and 65535');
            } else {
                this.validatedConfig.PORT = portNum;
            }
        }
    }

    /**
     * Validate AI configuration
     */
    validateAI() {
        const ollamaHost = process.env.OLLAMA_HOST;
        const backupHost = process.env.BACKUP_OLLAMA_HOST;
        
        if (!ollamaHost) {
            this.warnings.push('OLLAMA_HOST not configured, defaulting to localhost:11434');
            this.validatedConfig.OLLAMA_HOST = 'localhost:11434';
        } else {
            this.validatedConfig.OLLAMA_HOST = ollamaHost;
        }
        
        if (backupHost) {
            this.validatedConfig.BACKUP_OLLAMA_HOST = backupHost;
        }
    }

    /**
     * Check if a value is a placeholder
     * @param {string} value - Value to check
     * @returns {boolean} True if value appears to be a placeholder
     */
    isPlaceholder(value) {
        if (!value) return false;
        
        const placeholderPatterns = [
            'REPLACE',
            'PLACEHOLDER',
            'YOUR_',
            'EXAMPLE',
            'CHANGE_ME',
            'TODO',
            'XXX',
            'FIXME',
            '<',
            '>'
        ];
        
        const upperValue = value.toUpperCase();
        return placeholderPatterns.some(pattern => upperValue.includes(pattern));
    }

    /**
     * Format validation results for logging
     * @param {Object} result - Validation result
     * @returns {string} Formatted output
     */
    formatResults(result) {
        let output = '='.repeat(60) + '\n';
        output += 'CONFIGURATION VALIDATION REPORT\n';
        output += '='.repeat(60) + '\n\n';
        
        if (result.errors.length > 0) {
            output += '❌ CRITICAL ERRORS (must be fixed):\n';
            output += '-'.repeat(40) + '\n';
            result.errors.forEach((error, i) => {
                output += `  ${i + 1}. ${error}\n`;
            });
            output += '\n';
        }
        
        if (result.warnings.length > 0) {
            output += '⚠️  WARNINGS (should be reviewed):\n';
            output += '-'.repeat(40) + '\n';
            result.warnings.forEach((warning, i) => {
                output += `  ${i + 1}. ${warning}\n`;
            });
            output += '\n';
        }
        
        if (result.valid) {
            output += '✅ Configuration is valid and ready for production!\n';
        } else {
            output += '❌ Configuration validation FAILED!\n';
            output += '   Please fix the errors above before starting the application.\n';
            output += '\n';
            output += '   For Stripe setup, see: STRIPE_SETUP.md\n';
            output += '   For email setup, see: EMAIL_SETUP_QUICK.md\n';
        }
        
        output += '='.repeat(60) + '\n';
        return output;
    }
}

// Export singleton instance
module.exports = new ConfigValidator();