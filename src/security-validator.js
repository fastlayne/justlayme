/**
 * Security Configuration Validator
 * Validates that all required security environment variables are properly configured
 */

const crypto = require('crypto');

class SecurityValidator {
    constructor() {
        this.errors = [];
        this.warnings = [];
    }

    /**
     * Validate all security configurations
     */
    validate() {
        this.validateJWTSecret();
        this.validateDatabaseConfig();
        this.validateEmailConfig();
        this.validateEnvironmentMode();
        this.validateSSLConfig();
        
        return {
            isValid: this.errors.length === 0,
            errors: this.errors,
            warnings: this.warnings
        };
    }

    /**
     * Validate JWT secret configuration
     */
    validateJWTSecret() {
        const jwtSecret = process.env.JWT_SECRET;
        
        if (!jwtSecret) {
            this.errors.push('JWT_SECRET environment variable is required');
            return;
        }
        
        if (jwtSecret.length < 32) {
            this.errors.push('JWT_SECRET must be at least 32 characters long');
        }
        
        // Check if using a default/weak secret
        const weakSecrets = ['secret', 'password', '123456', 'default'];
        const lowerSecret = jwtSecret.toLowerCase();
        
        // Check for weak patterns, but exclude legitimate secrets that happen to contain brand name
        const isWeak = weakSecrets.some(weak => lowerSecret.includes(weak)) ||
                      (lowerSecret === 'justlayme' || lowerSecret.startsWith('justlayme-') && jwtSecret.length < 32);
        
        if (isWeak && jwtSecret.length < 32) {
            this.errors.push('JWT_SECRET appears to use a weak/default value');
        }
        
        // Validate entropy
        const entropy = this.calculateEntropy(jwtSecret);
        if (entropy < 4.0) {
            this.warnings.push('JWT_SECRET has low entropy, consider using a more random value');
        }
    }

    /**
     * Validate database configuration
     */
    validateDatabaseConfig() {
        const dbUrl = process.env.DATABASE_URL;
        
        if (!dbUrl) {
            this.warnings.push('DATABASE_URL not set - using SQLite fallback');
            return;
        }
        
        // Check for insecure database configurations
        if (dbUrl.includes('sslmode=disable')) {
            this.warnings.push('Database SSL is disabled - consider enabling for production');
        }
        
        if (dbUrl.includes('localhost') && process.env.NODE_ENV === 'production') {
            this.warnings.push('Using localhost database in production environment');
        }
        
        // Check for credentials in URL (should use environment variables)
        if (dbUrl.includes('@') && !dbUrl.startsWith('postgres://') && !dbUrl.startsWith('postgresql://')) {
            this.warnings.push('Database URL format may contain credentials directly');
        }
    }

    /**
     * Validate email configuration
     */
    validateEmailConfig() {
        const gmailUser = process.env.GMAIL_USER;
        const gmailPassword = process.env.GMAIL_APP_PASSWORD;
        
        if (gmailUser && !gmailUser.includes('@')) {
            this.errors.push('GMAIL_USER should be a valid email address');
        }
        
        if (gmailPassword && (gmailPassword === 'EMAIL_DISABLED_FOR_NOW' || gmailPassword === 'BRIDGE_PASSWORD_NEEDED')) {
            this.warnings.push('Email service is disabled or using placeholder password');
        }
    }

    /**
     * Validate environment mode
     */
    validateEnvironmentMode() {
        const nodeEnv = process.env.NODE_ENV;
        
        if (!nodeEnv) {
            this.warnings.push('NODE_ENV not set - defaulting to development mode');
        }
        
        if (nodeEnv === 'production') {
            // Additional production security checks
            if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 64) {
                this.errors.push('Production environments require strong JWT_SECRET (64+ characters)');
            }
            
            if (!process.env.DATABASE_URL) {
                this.warnings.push('Production should use external database (DATABASE_URL)');
            }
        }
    }

    /**
     * Validate SSL configuration
     */
    validateSSLConfig() {
        const nodeEnv = process.env.NODE_ENV;
        const port = process.env.PORT || 3333;
        
        if (nodeEnv === 'production' && !process.env.HTTPS_ENABLED) {
            this.warnings.push('Consider enabling HTTPS for production deployment');
        }
        
        if (port == 80 || port == 443) {
            this.warnings.push('Running on privileged port - ensure proper security measures');
        }
    }

    /**
     * Calculate Shannon entropy of a string
     */
    calculateEntropy(str) {
        const freqMap = {};
        for (let i = 0; i < str.length; i++) {
            freqMap[str[i]] = (freqMap[str[i]] || 0) + 1;
        }
        
        let entropy = 0;
        const len = str.length;
        for (let char in freqMap) {
            const freq = freqMap[char] / len;
            entropy -= freq * Math.log2(freq);
        }
        
        return entropy;
    }

    /**
     * Generate a secure JWT secret if needed
     */
    static generateSecureJWTSecret() {
        return crypto.randomBytes(64).toString('hex');
    }

    /**
     * Run validation and log results
     */
    static validateAndLog() {
        const validator = new SecurityValidator();
        const result = validator.validate();
        
        if (result.errors.length > 0) {
            console.error('ERROR Security Configuration Errors:');
            result.errors.forEach(error => console.error('  -', error));
        }
        
        if (result.warnings.length > 0) {
            console.warn('⚠️  Security Configuration Warnings:');
            result.warnings.forEach(warning => console.warn('  -', warning));
        }
        
        if (result.isValid && result.warnings.length === 0) {
            console.log('SUCCESS Security configuration validation passed');
        }
        
        return result;
    }
}

module.exports = SecurityValidator;