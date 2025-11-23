const path = require('path');
const fs = require('fs');
const logger = require('../utils/logger');

/**
 * Environment Configuration Manager
 * Loads the appropriate .env file based on NODE_ENV
 */
class EnvironmentConfig {
    constructor() {
        this.env = process.env.NODE_ENV || 'development';
        this.config = {};
        this.loadEnvironmentFile();
        this.validateConfiguration();
    }
    
    /**
     * Load environment-specific .env file
     */
    loadEnvironmentFile() {
        const envFiles = [
            `.env.${this.env}`,
            `.env.${this.env}.local`,
            '.env.local',
            '.env'
        ];
        
        // Try to load environment files in order of precedence
        for (const envFile of envFiles) {
            const envPath = path.join(process.cwd(), envFile);
            if (fs.existsSync(envPath)) {
                try {
                    require('dotenv').config({ path: envPath });
                    logger.info(`Loaded environment from ${envFile}`);
                    break;
                } catch (error) {
                    logger.error(`Failed to load ${envFile}:`, error);
                }
            }
        }
        
        // Set configuration with defaults
        this.config = {
            // Server
            nodeEnv: this.env,
            port: parseInt(process.env.PORT) || 3333,
            logLevel: process.env.LOG_LEVEL || (this.isDevelopment() ? 'debug' : 'info'),
            
            // Database
            databasePath: process.env.DATABASE_PATH || './database/justlayme.db',
            
            // JWT
            jwtSecret: process.env.JWT_SECRET || this.generateDevSecret(),
            
            // Stripe
            stripe: {
                publishableKey: process.env.STRIPE_PUBLISHABLE_KEY,
                secretKey: process.env.STRIPE_SECRET_KEY,
                priceMonthly: process.env.STRIPE_PRICE_MONTHLY,
                priceYearly: process.env.STRIPE_PRICE_YEARLY,
                webhookSecret: process.env.STRIPE_WEBHOOK_SECRET
            },
            
            // Email
            email: {
                enabled: process.env.EMAIL_ENABLED === 'true',
                host: process.env.EMAIL_HOST,
                port: parseInt(process.env.EMAIL_PORT) || 587,
                user: process.env.EMAIL_USER,
                pass: process.env.EMAIL_PASS,
                adminEmail: process.env.ADMIN_EMAIL
            },
            
            // AI
            ollama: {
                host: process.env.OLLAMA_HOST || 'http://localhost:11434',
                remoteHost: process.env.REMOTE_OLLAMA_HOST,
                timeout: parseInt(process.env.OLLAMA_TIMEOUT) || 120000
            },
            
            // Cache
            cache: {
                ttl: parseInt(process.env.CACHE_TTL) || 60000,
                userCacheTTL: parseInt(process.env.USER_CACHE_TTL) || 60000,
                maxSize: parseInt(process.env.MAX_CACHE_SIZE) || 1000
            },
            
            // Security
            security: {
                rateLimitWindow: parseInt(process.env.RATE_LIMIT_WINDOW) || 60000,
                rateLimitMax: parseInt(process.env.RATE_LIMIT_MAX_REQUESTS) || 100,
                corsOrigin: process.env.CORS_ORIGIN || '*'
            },
            
            // Features
            features: {
                memoryEngine: process.env.ENABLE_MEMORY_ENGINE !== 'false',
                voiceSamples: process.env.ENABLE_VOICE_SAMPLES !== 'false',
                groupConversations: process.env.ENABLE_GROUP_CONVERSATIONS !== 'false',
                analytics: process.env.ENABLE_ANALYTICS === 'true'
            },
            
            // SSL
            ssl: {
                certPath: process.env.SSL_CERT_PATH,
                keyPath: process.env.SSL_KEY_PATH
            },
            
            // Monitoring
            monitoring: {
                sentryDsn: process.env.SENTRY_DSN,
                analyticsKey: process.env.ANALYTICS_KEY
            }
        };
    }
    
    /**
     * Validate required configuration
     */
    validateConfiguration() {
        const required = [];
        const warnings = [];
        
        // Check required fields based on environment
        if (this.isProduction()) {
            // Production requires real keys
            if (!this.config.jwtSecret || this.config.jwtSecret.includes('dev_')) {
                required.push('JWT_SECRET (secure production key required)');
            }
            
            if (!this.config.stripe.secretKey || this.config.stripe.secretKey.includes('test')) {
                warnings.push('STRIPE_SECRET_KEY (using test key in production)');
            }
            
            if (!this.config.email.enabled) {
                warnings.push('EMAIL_ENABLED (email notifications disabled)');
            }
        }
        
        // Always required
        if (!this.config.databasePath) {
            required.push('DATABASE_PATH');
        }
        
        // Log validation results
        if (required.length > 0) {
            logger.error('Missing required configuration:', required);
            if (this.isProduction()) {
                throw new Error(`Missing required configuration: ${required.join(', ')}`);
            }
        }
        
        if (warnings.length > 0) {
            logger.warn('Configuration warnings:', warnings);
        }
        
        logger.info(`Configuration validated for ${this.env} environment`);
    }
    
    /**
     * Generate a development JWT secret
     */
    generateDevSecret() {
        if (this.isDevelopment()) {
            const devSecret = 'dev_secret_' + Math.random().toString(36).substring(2, 15);
            logger.warn(`Generated development JWT secret. DO NOT use in production!`);
            return devSecret;
        }
        throw new Error('JWT_SECRET must be set in production');
    }
    
    /**
     * Check if development environment
     */
    isDevelopment() {
        return this.env === 'development' || this.env === 'dev';
    }
    
    /**
     * Check if production environment
     */
    isProduction() {
        return this.env === 'production' || this.env === 'prod';
    }
    
    /**
     * Check if test environment
     */
    isTest() {
        return this.env === 'test';
    }
    
    /**
     * Get configuration value
     */
    get(key) {
        const keys = key.split('.');
        let value = this.config;
        
        for (const k of keys) {
            value = value[k];
            if (value === undefined) {
                return undefined;
            }
        }
        
        return value;
    }
    
    /**
     * Get all configuration
     */
    getAll() {
        // Return a copy to prevent modification
        return JSON.parse(JSON.stringify(this.config));
    }
    
    /**
     * Get safe configuration (without secrets)
     */
    getSafe() {
        const safe = JSON.parse(JSON.stringify(this.config));
        
        // Remove sensitive data
        delete safe.jwtSecret;
        delete safe.stripe.secretKey;
        delete safe.stripe.webhookSecret;
        delete safe.email.pass;
        delete safe.monitoring.sentryDsn;
        
        return safe;
    }
}

// Create singleton instance
const config = new EnvironmentConfig();

module.exports = config;