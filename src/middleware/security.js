const rateLimit = require('express-rate-limit');
const helmet = require('helmet');
const cors = require('cors');
const inputSanitizer = require('../utils/input-sanitizer');
const cookieParser = require('cookie-parser');
const { doubleCsrf } = require('csrf-csrf');
const { body, validationResult } = require('express-validator');
const jwt = require('jsonwebtoken');

// Create different rate limiters for different endpoints
const createRateLimiter = (windowMs, max, message) => {
    return rateLimit({
        windowMs,
        max,
        message,
        standardHeaders: true,
        legacyHeaders: false,
        handler: (req, res) => {
            res.status(429).json({
                error: message,
                retryAfter: Math.ceil(windowMs / 1000)
            });
        }
    });
};

// General API rate limiter
const apiLimiter = createRateLimiter(
    15 * 60 * 1000, // 15 minutes
    100, // limit each IP to 100 requests per windowMs
    'Too many requests, please try again later.'
);

// Strict rate limiter for AI endpoints
const aiLimiter = createRateLimiter(
    15 * 60 * 1000, // 15 minutes
    10, // limit each IP to 10 AI requests per windowMs
    'AI request limit exceeded. Please upgrade to premium for higher limits.'
);

// Auth endpoints rate limiter
const authLimiter = createRateLimiter(
    15 * 60 * 1000, // 15 minutes
    5, // limit each IP to 5 auth attempts per windowMs
    'Too many authentication attempts, please try again later.'
);

// Payment endpoints rate limiter
const paymentLimiter = createRateLimiter(
    60 * 60 * 1000, // 1 hour
    10, // limit each IP to 10 payment requests per hour
    'Payment request limit exceeded.'
);

// Configure CORS
const corsOptions = {
    origin: function (origin, callback) {
        const allowedOrigins = [
            'https://justlay.me',
            'https://www.justlay.me',
            'http://localhost:3333',
            'http://localhost:3000'
        ];
        
        // Only allow requests with no origin in development mode for testing tools
        if (!origin && process.env.NODE_ENV !== 'production') {
            return callback(null, true);
        } else if (!origin) {
            return callback(new Error('Origin required in production'), false);
        }
        
        if (allowedOrigins.indexOf(origin) !== -1) {
            callback(null, true);
        } else {
            callback(new Error('Not allowed by CORS'));
        }
    },
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization', 'X-CSRF-Token'],
    exposedHeaders: ['X-Total-Count', 'X-Page-Count'],
    maxAge: 86400 // 24 hours
};

// Configure Helmet for security headers
const helmetConfig = helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com"],
            scriptSrc: ["'self'", "'unsafe-inline'", "https://js.stripe.com"],
            scriptSrcAttr: ["'unsafe-inline'"],
            imgSrc: ["'self'", "data:", "https:"],
            connectSrc: ["'self'", "https://api.stripe.com", "wss://justlay.me"],
            fontSrc: ["'self'", "https://fonts.gstatic.com"],
            frameSrc: ["https://js.stripe.com", "https://hooks.stripe.com"],
            objectSrc: ["'none'"],
            upgradeInsecureRequests: process.env.NODE_ENV === 'production' ? [] : null
        }
    },
    crossOriginEmbedderPolicy: false, // Allow embedding for certain features
    hsts: {
        maxAge: 31536000,
        includeSubDomains: true,
        preload: true
    }
});

// Enhanced input sanitization middleware
const sanitizeInput = (req, res, next) => {
    // Define validation rules for common fields
    const validationRules = {
        email: { type: 'email', required: false, maxLength: 254 },
        password: { type: 'string', minLength: 8, maxLength: 128 },
        message: { type: 'string', maxLength: 10000, context: 'general' },
        userId: { type: 'string', pattern: /^[a-zA-Z0-9-_]+$/, maxLength: 36 },
        conversationId: { type: 'string', pattern: /^[a-zA-Z0-9-_]+$/, maxLength: 36 },
        characterId: { type: 'string', pattern: /^[a-zA-Z0-9-_]+$/, maxLength: 36 },
        model: { type: 'string', pattern: /^[a-zA-Z0-9:._-]+$/, maxLength: 100 },
        title: { type: 'string', maxLength: 200, context: 'general' },
        name: { type: 'string', maxLength: 100, context: 'general' },
        backstory: { type: 'string', maxLength: 5000, context: 'general' }
    };
    
    try {
        // Sanitize body
        if (req.body && typeof req.body === 'object') {
            req.body = inputSanitizer.sanitizeObject(req.body, validationRules);
        }
        
        // Sanitize query parameters
        if (req.query && typeof req.query === 'object') {
            req.query = inputSanitizer.sanitizeObject(req.query, validationRules);
        }
        
        // Sanitize URL parameters
        if (req.params && typeof req.params === 'object') {
            req.params = inputSanitizer.sanitizeObject(req.params, validationRules);
        }
        
        // Additional validation for sensitive fields
        if (req.body && req.body.email) {
            const emailValidation = inputSanitizer.validate(req.body.email, { type: 'email' });
            if (!emailValidation.isValid) {
                return res.status(400).json({ 
                    error: 'Invalid email format',
                    details: emailValidation.errors
                });
            }
            req.body.email = emailValidation.sanitized;
        }
        
        next();
    } catch (error) {
        console.error('Input sanitization error:', error);
        return res.status(400).json({ error: 'Invalid input data' });
    }
};

// Request ID middleware for tracking
const requestId = (req, res, next) => {
    req.id = require('crypto').randomBytes(16).toString('hex');
    res.setHeader('X-Request-Id', req.id);
    next();
};

/**
 * SECURITY HARDENING ADDITIONS
 * ==================================
 * 1. Cookie-based JWT Authentication (XSS protection)
 * 2. CSRF Protection
 * 3. Express-Validator Input Validation
 */

// Get JWT_SECRET from environment
const JWT_SECRET = process.env.JWT_SECRET;

if (!JWT_SECRET) {
    console.error('CRITICAL SECURITY ERROR: JWT_SECRET is not configured');
    throw new Error('JWT_SECRET is required for security middleware');
}

/**
 * Cookie configuration for JWT tokens
 * - httpOnly: Prevents JavaScript access (XSS protection)
 * - secure: HTTPS only in production
 * - sameSite: CSRF protection
 *   - 'lax' allows cookies on top-level navigation (page refresh, direct URL access)
 *   - Still blocks cross-site requests (CSRF protection maintained)
 *   - Fixes logout-on-refresh issue while maintaining security
 * - maxAge: 30 days (matches JWT expiration)
 */
const COOKIE_OPTIONS = {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'lax', // Changed from 'strict' to allow cookies on page refresh
    maxAge: 30 * 24 * 60 * 60 * 1000, // 30 days
    path: '/'
};

/**
 * CSRF Protection Configuration
 * Uses csrf-csrf (modern replacement for deprecated csurf)
 */
const {
    generateToken,
    validateRequest,
    doubleCsrfProtection
} = doubleCsrf({
    getSecret: () => JWT_SECRET,
    cookieName: '__Host-csrf',
    cookieOptions: {
        ...COOKIE_OPTIONS,
        sameSite: 'strict'
    },
    size: 64,
    ignoredMethods: ['GET', 'HEAD', 'OPTIONS'],
    getTokenFromRequest: (req) => {
        return req.headers['x-csrf-token'] || req.body._csrf;
    }
});

/**
 * Cookie Parser Middleware
 */
const cookieParserMiddleware = cookieParser();

/**
 * Input Validation Rules using express-validator
 */
const validateEmail = body('email')
    .trim()
    .isEmail().withMessage('Invalid email format')
    .normalizeEmail()
    .isLength({ max: 255 }).withMessage('Email too long');

const validatePassword = body('password')
    .isLength({ min: 8 }).withMessage('Password must be at least 8 characters')
    .matches(/[a-z]/).withMessage('Password must contain at least one lowercase letter')
    .matches(/[A-Z]/).withMessage('Password must contain at least one uppercase letter')
    .matches(/[0-9]/).withMessage('Password must contain at least one number')
    .matches(/[@$!%*?&#]/).withMessage('Password must contain at least one special character');

const validateUsername = body('username')
    .optional()
    .trim()
    .isLength({ min: 3, max: 30 }).withMessage('Username must be 3-30 characters')
    .matches(/^[a-zA-Z0-9_-]+$/).withMessage('Username can only contain letters, numbers, dashes, and underscores');

const validateMessageContent = body('message')
    .trim()
    .isLength({ min: 1, max: 10000 }).withMessage('Message must be 1-10,000 characters')
    .custom((value) => {
        if (/<script|javascript:|onerror=|onclick=/i.test(value)) {
            throw new Error('Message contains prohibited content');
        }
        return true;
    });

/**
 * Validation Error Handler
 */
function handleValidationErrors(req, res, next) {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
        return res.status(400).json({
            error: 'Validation failed',
            details: errors.array().map(err => ({
                field: err.path,
                message: err.msg
            }))
        });
    }
    next();
}

/**
 * Cookie-Based JWT Authentication Middleware
 * Reads JWT from httpOnly cookie instead of Authorization header
 */
function authenticateWithCookie(req, res, next) {
    try {
        const token = req.cookies.authToken;

        if (!token) {
            return res.status(401).json({
                error: 'Authentication required',
                message: 'Please log in to access this resource',
                code: 'NO_TOKEN'
            });
        }

        const decoded = jwt.verify(token, JWT_SECRET);
        req.user = {
            id: decoded.id,
            email: decoded.email,
            verified: decoded.verified || false,
            provider: decoded.provider || 'email'
        };

        next();
    } catch (error) {
        if (error.name === 'JsonWebTokenError') {
            return res.status(401).json({
                error: 'Invalid token',
                code: 'INVALID_TOKEN'
            });
        }

        if (error.name === 'TokenExpiredError') {
            return res.status(401).json({
                error: 'Token expired',
                code: 'TOKEN_EXPIRED'
            });
        }

        return res.status(500).json({
            error: 'Authentication failed',
            code: 'AUTH_ERROR'
        });
    }
}

/**
 * REMOVED: Dual Authentication Support
 * Consolidated to single cookie-based authentication for security and consistency
 * All authentication now uses httpOnly cookies exclusively
 * This prevents XSS attacks and eliminates session conflicts
 */

/**
 * Set JWT Token in httpOnly Cookie
 */
function setAuthCookie(res, token) {
    res.cookie('authToken', token, COOKIE_OPTIONS);
}

/**
 * Clear JWT Token Cookie
 */
function clearAuthCookie(res) {
    res.clearCookie('authToken', {
        path: '/',
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'strict'
    });
}

// Security middleware collection
const securityMiddleware = {
    helmet: helmetConfig,
    cors: cors(corsOptions),
    apiLimiter,
    aiLimiter,
    authLimiter,
    paymentLimiter,
    sanitizeInput,
    requestId,
    // Cookie-based authentication (SINGLE AUTH METHOD)
    cookieParser: cookieParserMiddleware,
    authenticateWithCookie,
    setAuthCookie,
    clearAuthCookie,
    // CSRF Protection
    csrfProtection: doubleCsrfProtection,
    generateCsrfToken: generateToken,
    validateCsrfToken: validateRequest,
    // Input Validation
    validateEmail,
    validatePassword,
    validateUsername,
    validateMessageContent,
    handleValidationErrors,
    // Cookie options
    COOKIE_OPTIONS
};

module.exports = securityMiddleware;