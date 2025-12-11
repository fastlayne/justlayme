const jwt = require('jsonwebtoken');
const crypto = require('crypto');
const Database = require('../database');
const resourceLifecycleManager = require('../resource-lifecycle-manager');

/**
 * Centralized Authentication Service
 * Consolidates all JWT operations, token management, and auth logic
 */
class AuthService {
    constructor() {
        this.db = null;
        this.tokenBlacklist = new Set();
        this.loginAttempts = new Map();
        this.cleanupIntervalId = null; // ARCHITECTURAL FIX: Store interval ID for cleanup

        // Security configuration
        this.config = {
            MAX_LOGIN_ATTEMPTS: 5,
            LOCKOUT_DURATION: 15 * 60 * 1000, // 15 minutes
            TOKEN_EXPIRY: '24h',
            PASSWORD_MIN_LENGTH: 8,
            FAILED_ATTEMPT_WINDOW: 15 * 60 * 1000, // 15 minutes
            SESSION_DURATION: 24 * 60 * 60 * 1000 // 24 hours for admin sessions
        };

        // Initialize
        this._initializeDatabase();
        this._loadBlacklistedTokens();
        this._startCleanupInterval();
    }

    /**
     * Get database instance (shared)
     */
    _getDb() {
        if (!this.db) {
            this.db = Database.getInstance();
        }
        return this.db;
    }

    /**
     * Get database instance (public method for external access)
     */
    getDatabase() {
        return this._getDb();
    }

    /**
     * Initialize database and load blacklisted tokens
     */
    async _initializeDatabase() {
        try {
            await this._loadBlacklistedTokens();
        } catch (error) {
            console.error('Failed to initialize AuthService database:', error);
        }
    }

    /**
     * Load blacklisted tokens from database
     */
    async _loadBlacklistedTokens() {
        try {
            const db = this._getDb();
            const result = await db.query(
                'SELECT token_hash FROM blacklisted_tokens WHERE expires_at > ?',
                [new Date().toISOString()]
            );
            const tokens = result.rows || result;
            tokens.forEach(row => this.tokenBlacklist.add(row.token_hash));
            console.log(`🔒 Loaded ${tokens.length} blacklisted tokens`);
        } catch (error) {
            console.error('Failed to load blacklisted tokens:', error);
        }
    }

    /**
     * Start cleanup interval for expired tokens
     * ARCHITECTURAL FIX: Use ResourceLifecycleManager for automatic cleanup
     */
    _startCleanupInterval() {
        this.cleanupIntervalId = resourceLifecycleManager.registerInterval(
            'auth-service-token-cleanup',
            () => this._cleanupExpiredTokens(),
            60 * 60 * 1000 // Every hour
        );
    }

    /**
     * Shutdown and cleanup resources
     * ARCHITECTURAL FIX: Proper resource cleanup on server shutdown
     */
    shutdown() {
        if (this.cleanupIntervalId) {
            resourceLifecycleManager.clearInterval('auth-service-token-cleanup');
            this.cleanupIntervalId = null;
        }
        console.log('✅ AuthService shutdown complete');
    }

    /**
     * Clean up expired tokens from database
     */
    async _cleanupExpiredTokens() {
        try {
            const db = this._getDb();
            await db.query(
                'DELETE FROM blacklisted_tokens WHERE expires_at <= ?',
                [new Date().toISOString()]
            );
        } catch (error) {
            console.error('Token cleanup error:', error);
        }
    }

    /**
     * Generate JWT token with standardized payload and options
     */
    generateToken(payload, options = {}) {
        if (!process.env.JWT_SECRET) {
            throw new Error('JWT_SECRET environment variable is required');
        }

        // Standardized JWT options
        const jwtOptions = {
            expiresIn: options.expiresIn || this.config.TOKEN_EXPIRY,
            algorithm: 'HS256',
            issuer: 'justlayme',
            ...options
        };

        // Add standard claims
        const standardPayload = {
            ...payload,
            iat: Math.floor(Date.now() / 1000),
            ...(options.subject && { sub: options.subject })
        };

        return jwt.sign(standardPayload, process.env.JWT_SECRET, jwtOptions);
    }

    /**
     * Verify JWT token with standardized validation
     */
    verifyToken(token, options = {}) {
        if (!process.env.JWT_SECRET) {
            throw new Error('JWT_SECRET environment variable is required');
        }

        if (!token) {
            throw new Error('Token is required');
        }

        // Check if token is blacklisted
        if (this.isTokenBlacklisted(token)) {
            throw new Error('Token is blacklisted');
        }

        // Standardized verification options
        const jwtOptions = {
            algorithms: ['HS256'],
            maxAge: this.config.TOKEN_EXPIRY,
            clockTolerance: 30,
            complete: false,
            issuer: 'justlayme',
            ...options
        };

        return jwt.verify(token, process.env.JWT_SECRET, jwtOptions);
    }

    /**
     * Extract token from authorization header
     */
    extractTokenFromHeader(authHeader) {
        if (!authHeader) {
            return null;
        }
        
        const parts = authHeader.split(' ');
        if (parts.length !== 2 || parts[0] !== 'Bearer') {
            return null;
        }
        
        return parts[1];
    }

    /**
     * Validate token payload structure
     */
    validateTokenPayload(decoded) {
        const errors = [];

        if (!decoded || typeof decoded !== 'object') {
            errors.push('Invalid token format');
        }

        if (!decoded.id || (!['string', 'number'].includes(typeof decoded.id))) {
            errors.push('Invalid user ID in token');
        }

        if (!decoded.email || typeof decoded.email !== 'string') {
            errors.push('Invalid email in token');
        }

        // Validate email format
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        if (decoded.email && !emailRegex.test(decoded.email)) {
            errors.push('Invalid email format in token');
        }

        return {
            isValid: errors.length === 0,
            errors
        };
    }

    /**
     * Blacklist a token
     */
    async blacklistToken(token) {
        if (!token) return;

        const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
        this.tokenBlacklist.add(tokenHash);
        
        try {
            const db = this._getDb();
            // Cross-database compatible UPSERT for blacklisted tokens
            try {
                await db.query(
                    'INSERT INTO blacklisted_tokens (token_hash, created_at, expires_at) VALUES (?, ?, ?)',
                    [tokenHash, new Date().toISOString(), new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString()]
                );
            } catch (insertError) {
                if (insertError.message && insertError.message.includes('UNIQUE constraint failed')) {
                    await db.query(
                        'UPDATE blacklisted_tokens SET expires_at = ? WHERE token_hash = ?',
                        [new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(), tokenHash]
                    );
                } else {
                    throw insertError;
                }
            }
            console.log('SUCCESS Token blacklisted successfully');
        } catch (error) {
            console.error('Failed to blacklist token in database:', error);
        }
    }

    /**
     * Check if token is blacklisted
     */
    isTokenBlacklisted(token) {
        if (!token) return false;
        const tokenHash = crypto.createHash('sha256').update(token).digest('hex');
        return this.tokenBlacklist.has(tokenHash);
    }

    /**
     * Rate limiting for login attempts
     */
    checkRateLimit(ip) {
        const now = Date.now();
        const attempts = this.loginAttempts.get(ip) || { 
            count: 0, 
            firstAttempt: now, 
            lockedUntil: null 
        };
        
        // Check if account is locked
        if (attempts.lockedUntil && now < attempts.lockedUntil) {
            return {
                allowed: false,
                lockoutRemaining: Math.ceil((attempts.lockedUntil - now) / 1000),
                message: `Too many failed attempts. Try again in ${Math.ceil((attempts.lockedUntil - now) / 60000)} minutes.`
            };
        }
        
        // Reset attempts if enough time has passed
        if (now - attempts.firstAttempt > this.config.FAILED_ATTEMPT_WINDOW) {
            attempts.count = 0;
            attempts.firstAttempt = now;
            attempts.lockedUntil = null;
        }
        
        return { allowed: true, attempts: attempts.count };
    }

    /**
     * Record failed login attempt
     */
    recordFailedAttempt(ip) {
        const now = Date.now();
        const attempts = this.loginAttempts.get(ip) || { 
            count: 0, 
            firstAttempt: now, 
            lockedUntil: null 
        };
        
        attempts.count++;
        attempts.lastAttempt = now;
        
        if (attempts.count >= this.config.MAX_LOGIN_ATTEMPTS) {
            attempts.lockedUntil = now + this.config.LOCKOUT_DURATION;
        }
        
        this.loginAttempts.set(ip, attempts);
        
        console.warn(`WARNING Failed login attempt ${attempts.count}/${this.config.MAX_LOGIN_ATTEMPTS} from IP: ${ip}`);
        
        return attempts;
    }

    /**
     * Record successful login
     */
    recordSuccessfulLogin(ip) {
        this.loginAttempts.delete(ip);
    }

    /**
     * Validate password strength
     */
    validatePassword(password) {
        const errors = [];
        
        if (!password || password.length < this.config.PASSWORD_MIN_LENGTH) {
            errors.push(`Password must be at least ${this.config.PASSWORD_MIN_LENGTH} characters long`);
        }
        
        if (!/[A-Z]/.test(password)) {
            errors.push('Password must contain at least one uppercase letter');
        }
        
        if (!/[a-z]/.test(password)) {
            errors.push('Password must contain at least one lowercase letter');
        }
        
        if (!/[0-9]/.test(password)) {
            errors.push('Password must contain at least one number');
        }
        
        if (!/[!@#$%^&*(),.?":{}|<>]/.test(password)) {
            errors.push('Password must contain at least one special character');
        }
        
        // Check for common weak passwords (top 100+ most common passwords)
        const commonPasswords = [
            'password', 'password123', 'password1', 'password12', 'password!',
            '123456', '12345678', '123456789', '1234567890', '123123', '12345',
            'qwerty', 'qwerty123', 'qwertyuiop', 'abc123', 'abc123456',
            'admin', 'administrator', 'welcome', 'welcome123', 'login',
            'letmein', 'monkey', 'dragon', 'sunshine', 'master',
            'iloveyou', 'princess', 'football', 'charlie', 'shadow',
            'michael', 'jennifer', 'jordan', 'michelle', 'daniel',
            'baseball', 'superman', 'access', 'trustno1', 'batman',
            'thomas', 'robert', 'andrew', 'hockey', 'pepper',
            'mustang', 'snoopy', 'buster', 'dallas', 'tigers',
            'rangers', 'ginger', 'hammer', 'silver', 'copper',
            'mercury', 'purple', 'steelers', 'golden', 'yellow',
            'starwars', 'startrek', 'matrix', 'windows', 'computer',
            'internet', 'service', 'killer', 'flower', 'power',
            'orange', 'nothing', 'freedom', 'whatever', 'secret',
            'summer', 'winter', 'spring', 'autumn', 'friday',
            'monday', 'test', 'testing', 'sample', 'demo',
            'guest', 'default', 'changeme', 'temp', 'temporary'
        ];
        
        if (commonPasswords.includes(password.toLowerCase())) {
            errors.push('Password is too common and easily guessed. Please choose a more unique password.');
        }
        
        return {
            isValid: errors.length === 0,
            errors
        };
    }

    /**
     * Validate authentication input
     */
    validateAuthInput(email, password, isRegistration = false) {
        const errors = [];
        
        // Email validation
        if (!email || typeof email !== 'string') {
            errors.push('Email is required');
        } else {
            const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
            if (!emailRegex.test(email.trim())) {
                errors.push('Please enter a valid email address');
            }
            if (email.length > 254) {
                errors.push('Email address is too long');
            }
        }
        
        // Password validation for registration
        if (isRegistration) {
            const passwordValidation = this.validatePassword(password);
            if (!passwordValidation.isValid) {
                errors.push(...passwordValidation.errors);
            }
        } else if (!password || typeof password !== 'string') {
            errors.push('Password is required');
        }
        
        return {
            isValid: errors.length === 0,
            errors
        };
    }

    /**
     * Get user from database by token payload
     */
    async getUserFromToken(decoded) {
        try {
            const db = this._getDb();
            const userLookupPromise = db.query(
                'SELECT id, email, email_verified, subscription_status, is_admin FROM users WHERE id = ? AND email = ?', 
                [decoded.id, decoded.email]
            );
            
            // Add timeout to database lookup
            const timeoutPromise = new Promise((_, reject) => {
                setTimeout(() => reject(new Error('Database lookup timeout')), 5000);
            });
            
            const userResult = await Promise.race([userLookupPromise, timeoutPromise]);
            const users = userResult.rows || userResult;
            
            if (!users || users.length === 0) {
                return null;
            }

            const user = users[0];
            
            return {
                id: String(user.id),
                email: String(user.email).toLowerCase().trim(),
                emailVerified: user.email_verified === 1 || user.email_verified === true,
                subscriptionStatus: user.subscription_status || 'free',
                isPremium: ['premium', 'premium_monthly', 'premium_yearly', 'lifetime'].includes(user.subscription_status),
                isAdmin: user.is_admin === 1 || user.is_admin === true
            };
        } catch (error) {
            console.error('Database error during user lookup:', error);
            return null;
        }
    }

    /**
     * Validate admin PIN session
     */
    validateAdminPIN(adminAuth, authTime) {
        if (!adminAuth || adminAuth !== 'true') {
            return { valid: false, error: 'Admin authentication required' };
        }

        if (!authTime) {
            return { valid: false, error: 'Authentication timestamp required' };
        }

        try {
            const authTimestamp = parseInt(authTime);
            const now = Date.now();
            const sessionAge = now - authTimestamp;
            
            if (sessionAge > this.config.SESSION_DURATION) {
                return { valid: false, error: 'Admin session expired' };
            }

            return { valid: true };
        } catch (error) {
            return { valid: false, error: 'Invalid authentication data' };
        }
    }

    /**
     * Generate standardized error responses
     */
    generateErrorResponse(type, details = {}) {
        const errorTypes = {
            MISSING_TOKEN: {
                status: 401,
                error: 'Access token required',
                code: 'MISSING_TOKEN'
            },
            INVALID_TOKEN: {
                status: 401,
                error: 'Authentication required',
                code: 'AUTH_REQUIRED'
            },
            TOKEN_EXPIRED: {
                status: 401,
                error: 'Authentication required',
                code: 'AUTH_REQUIRED'
            },
            AUTH_SERVICE_ERROR: {
                status: 500,
                error: 'Authentication service unavailable',
                code: 'AUTH_SERVICE_ERROR'
            },
            RATE_LIMIT_EXCEEDED: {
                status: 429,
                error: 'Too many login attempts',
                code: 'RATE_LIMIT_EXCEEDED'
            },
            EMAIL_VERIFICATION_REQUIRED: {
                status: 403,
                error: 'Email verification required',
                code: 'EMAIL_VERIFICATION_REQUIRED'
            },
            PREMIUM_REQUIRED: {
                status: 403,
                error: 'Premium subscription required',
                code: 'PREMIUM_REQUIRED'
            },
            ADMIN_REQUIRED: {
                status: 403,
                error: 'Admin access required',
                code: 'ADMIN_REQUIRED'
            }
        };

        const baseResponse = errorTypes[type] || {
            status: 500,
            error: 'Internal server error',
            code: 'INTERNAL_ERROR'
        };

        return {
            ...baseResponse,
            ...details
        };
    }
}

// Create singleton instance
const authService = new AuthService();

module.exports = authService;