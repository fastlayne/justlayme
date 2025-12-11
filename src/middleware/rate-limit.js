/**
 * Rate Limiting Middleware
 * Protects API endpoints from abuse, brute force attacks, and DoS
 *
 * Based on AUDIT_SECURITY.md recommendations (lines 421-457)
 * Date: November 18, 2025
 * Priority: P0 - Critical Security Issue
 */

const rateLimit = require('express-rate-limit');
const RedisStore = require('rate-limit-redis');
const redis = require('redis');

// ANSI colors for logging
const colors = {
    reset: '\x1b[0m',
    yellow: '\x1b[33m',
    red: '\x1b[31m',
    cyan: '\x1b[36m'
};

/**
 * Try to connect to Redis for distributed rate limiting
 * Falls back to memory store if Redis unavailable
 */
let redisClient = null;
let useRedis = false;

if (process.env.REDIS_URL) {
    try {
        redisClient = redis.createClient({
            url: process.env.REDIS_URL,
            socket: {
                connectTimeout: 5000
            }
        });

        redisClient.on('error', (err) => {
            console.warn(`${colors.yellow}⚠ Redis connection error - using memory store for rate limiting${colors.reset}`);
            console.warn(`  ${err.message}`);
        });

        redisClient.on('connect', () => {
            console.log(`${colors.cyan}✓ Rate limiting using Redis store${colors.reset}`);
            useRedis = true;
        });

        redisClient.connect().catch(err => {
            console.warn(`${colors.yellow}⚠ Could not connect to Redis - using memory store${colors.reset}`);
        });
    } catch (error) {
        console.warn(`${colors.yellow}⚠ Redis initialization failed - using memory store${colors.reset}`);
    }
} else {
    console.log(`${colors.cyan}ℹ Rate limiting using memory store (set REDIS_URL for distributed limiting)${colors.reset}`);
}

/**
 * Standard rate limiter handler
 */
const rateLimitHandler = (req, res) => {
    res.status(429).json({
        error: 'Too many requests',
        message: 'You have exceeded the rate limit. Please try again later.',
        retryAfter: res.getHeader('Retry-After'),
        timestamp: new Date().toISOString()
    });
};

/**
 * Skip successful requests for login limiter
 * Only count failed attempts
 */
const skipSuccessfulRequests = (req, res) => {
    return res.statusCode < 400;
};

/**
 * Store configuration - use Redis if available, otherwise memory
 */
const getStore = () => {
    if (useRedis && redisClient) {
        return new RedisStore({
            client: redisClient,
            prefix: 'rl:' // Rate limit prefix
        });
    }
    // Default to memory store
    return undefined; // express-rate-limit will use MemoryStore
};

/**
 * Strict rate limiter for authentication endpoints
 * Prevents brute force password attacks
 * 5 attempts per 15 minutes per IP
 */
const authLimiter = rateLimit({
    windowMs: 15 * 60 * 1000, // 15 minutes
    max: 5, // 5 requests per window
    skipSuccessfulRequests: true, // Only count failed attempts
    handler: (req, res) => {
        console.warn(`${colors.red}⚠ SECURITY: Rate limit exceeded for auth endpoint${colors.reset}`);
        console.warn(`  IP: ${req.ip}`);
        console.warn(`  Path: ${req.path}`);
        console.warn(`  Time: ${new Date().toISOString()}`);

        res.status(429).json({
            error: 'Too many authentication attempts',
            message: 'Account temporarily locked. Please try again in 15 minutes.',
            retryAfter: '15 minutes',
            timestamp: new Date().toISOString()
        });
    },
    standardHeaders: true, // Return rate limit info in headers
    legacyHeaders: false,
    store: getStore()
});

/**
 * Standard API rate limiter
 * 100 requests per minute per IP
 */
const apiLimiter = rateLimit({
    windowMs: 60 * 1000, // 1 minute
    max: 100, // 100 requests per minute
    message: 'Too many API requests from this IP, please try again later',
    handler: rateLimitHandler,
    standardHeaders: true,
    legacyHeaders: false,
    store: getStore()
});

/**
 * Moderate rate limiter for general endpoints
 * 200 requests per 5 minutes per IP
 */
const moderateLimiter = rateLimit({
    windowMs: 5 * 60 * 1000, // 5 minutes
    max: 200, // 200 requests per window
    message: 'Too many requests from this IP, please slow down',
    handler: rateLimitHandler,
    standardHeaders: true,
    legacyHeaders: false,
    store: getStore()
});

/**
 * Strict limiter for expensive operations
 * 10 requests per 10 minutes per IP
 * Use for Black Mirror analysis, voice cloning, etc.
 */
const expensiveLimiter = rateLimit({
    windowMs: 10 * 60 * 1000, // 10 minutes
    max: 10, // 10 requests per window
    message: 'This operation is rate limited. Please try again later.',
    handler: (req, res) => {
        console.warn(`${colors.yellow}⚠ Rate limit: Expensive operation blocked${colors.reset}`);
        console.warn(`  IP: ${req.ip}`);
        console.warn(`  Path: ${req.path}`);
        console.warn(`  User: ${req.user?.id || 'anonymous'}`);

        res.status(429).json({
            error: 'Rate limit exceeded',
            message: 'This operation is computationally expensive. Please wait before trying again.',
            retryAfter: '10 minutes',
            timestamp: new Date().toISOString()
        });
    },
    standardHeaders: true,
    legacyHeaders: false,
    store: getStore()
});

/**
 * Very strict limiter for file uploads
 * 20 uploads per hour per IP
 */
const uploadLimiter = rateLimit({
    windowMs: 60 * 60 * 1000, // 1 hour
    max: 20, // 20 uploads per hour
    message: 'Upload limit exceeded. Please try again later.',
    handler: rateLimitHandler,
    standardHeaders: true,
    legacyHeaders: false,
    store: getStore()
});

/**
 * Lenient limiter for public endpoints
 * 500 requests per 10 minutes per IP
 */
const publicLimiter = rateLimit({
    windowMs: 10 * 60 * 1000, // 10 minutes
    max: 500, // 500 requests per window
    message: 'Too many requests, please try again later',
    handler: rateLimitHandler,
    standardHeaders: true,
    legacyHeaders: false,
    store: getStore()
});

/**
 * Custom key generator for user-based rate limiting
 * Use user ID if authenticated, otherwise IP address
 */
const userOrIPKeyGenerator = (req) => {
    if (req.user && req.user.id) {
        return `user:${req.user.id}`;
    }
    return req.ip;
};

/**
 * User-based premium feature limiter
 * Applies after authentication, limits by user ID
 * Free users: 50 requests per hour
 * Premium users: 500 requests per hour
 */
const premiumFeatureLimiter = (req, res, next) => {
    const isPremium = req.user?.isPremium || req.user?.subscription_status === 'premium';

    const limiter = rateLimit({
        windowMs: 60 * 60 * 1000, // 1 hour
        max: isPremium ? 500 : 50, // Premium users get 10x limit
        keyGenerator: userOrIPKeyGenerator,
        handler: (req, res) => {
            res.status(429).json({
                error: 'Rate limit exceeded',
                message: isPremium
                    ? 'You have reached your premium user rate limit. Please wait before making more requests.'
                    : 'You have reached your free user rate limit. Upgrade to premium for higher limits.',
                upgradeUrl: '/premium',
                retryAfter: '1 hour',
                currentLimit: isPremium ? 500 : 50,
                timestamp: new Date().toISOString()
            });
        },
        standardHeaders: true,
        legacyHeaders: false,
        store: getStore()
    });

    limiter(req, res, next);
};

/**
 * Log rate limit events for monitoring
 */
const logRateLimitEvent = (req, limitType) => {
    console.log(`${colors.cyan}[RATE LIMIT]${colors.reset} ${limitType}`);
    console.log(`  IP: ${req.ip}`);
    console.log(`  Path: ${req.path}`);
    console.log(`  Method: ${req.method}`);
    console.log(`  User: ${req.user?.id || 'anonymous'}`);
    console.log(`  Time: ${new Date().toISOString()}`);
};

module.exports = {
    authLimiter,         // For /api/auth/login, /api/auth/register
    apiLimiter,          // For /api/* general endpoints
    moderateLimiter,     // For moderately expensive operations
    expensiveLimiter,    // For Black Mirror, voice cloning, etc.
    uploadLimiter,       // For file uploads
    publicLimiter,       // For public pages/assets
    premiumFeatureLimiter, // For premium-only features
    logRateLimitEvent
};
