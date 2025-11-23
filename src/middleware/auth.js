const authService = require('../services/auth');

// All token and rate limiting functionality moved to AuthService

/**
 * JWT Authentication Middleware
 * Verifies JWT tokens and adds user data to request object
 */
const authenticateToken = async (req, res, next) => {
    const token = authService.extractTokenFromHeader(req.headers['authorization']);

    console.log('AUTH Authentication middleware called:', {
        hasToken: !!token,
        tokenLength: token ? token.length : 0,
        path: req.path
    });

    if (!token) {
        console.log('ERROR No token provided');
        const errorResponse = authService.generateErrorResponse('MISSING_TOKEN');
        return res.status(errorResponse.status).json(errorResponse);
    }

    try {
        // Verify token using AuthService
        const decoded = authService.verifyToken(token);
        
        console.log('SUCCESS Token decoded successfully:', {
            userId: decoded.id,
            email: decoded.email,
            iat: decoded.iat
        });
        
        // Validate token payload
        const validation = authService.validateTokenPayload(decoded);
        if (!validation.isValid) {
            console.log('ERROR Invalid token payload:', validation.errors);
            const errorResponse = authService.generateErrorResponse('INVALID_TOKEN');
            return res.status(errorResponse.status).json(errorResponse);
        }

        // Get user data from database
        const user = await authService.getUserFromToken(decoded);
        
        if (!user) {
            console.log('ERROR User not found for token');
            const errorResponse = authService.generateErrorResponse('INVALID_TOKEN');
            return res.status(errorResponse.status).json(errorResponse);
        }

        // Add user data to request
        req.user = user;
        next();
        
    } catch (error) {
        // Log error details for debugging
        const errorId = Math.random().toString(36).substring(7);
        console.error(`Token verification error (ID: ${errorId}):`, {
            name: error.name,
            message: error.message,
            timestamp: new Date().toISOString(),
            userAgent: req.get('User-Agent'),
            ip: req.ip
        });
        
        // Generate standardized error response
        let errorType = 'INVALID_TOKEN';
        if (error.name === 'TokenExpiredError') {
            errorType = 'TOKEN_EXPIRED';
        } else if (error.message && error.message.includes('JWT_SECRET')) {
            errorType = 'AUTH_SERVICE_ERROR';
        } else if (error.message && error.message.includes('timeout')) {
            const errorResponse = authService.generateErrorResponse('AUTH_SERVICE_ERROR', {
                error: 'Service temporarily unavailable',
                code: 'SERVICE_UNAVAILABLE',
                status: 503
            });
            return res.status(errorResponse.status).json(errorResponse);
        }
        
        const errorResponse = authService.generateErrorResponse(errorType, {
            ...(errorType === 'AUTH_SERVICE_ERROR' && { errorId })
        });
        return res.status(errorResponse.status).json(errorResponse);
    }
};

/**
 * Optional authentication middleware - continues if no token provided
 */
const optionalAuth = async (req, res, next) => {
    const token = authService.extractTokenFromHeader(req.headers['authorization']);

    if (!token) {
        req.user = null;
        return next();
    }

    try {
        // Verify token using AuthService
        const decoded = authService.verifyToken(token);
        
        // Validate token payload
        const validation = authService.validateTokenPayload(decoded);
        if (!validation.isValid) {
            req.user = null;
            return next();
        }

        // Get user data from database
        const user = await authService.getUserFromToken(decoded);
        req.user = user; // Will be null if user not found
        
    } catch (error) {
        // Silently ignore token errors in optional auth
        req.user = null;
    }
    
    next();
};

/**
 * Middleware to require email verification
 */
const requireEmailVerification = (req, res, next) => {
    if (!req.user) {
        const errorResponse = authService.generateErrorResponse('INVALID_TOKEN');
        return res.status(errorResponse.status).json(errorResponse);
    }

    if (!req.user.emailVerified) {
        const errorResponse = authService.generateErrorResponse('EMAIL_VERIFICATION_REQUIRED');
        return res.status(errorResponse.status).json(errorResponse);
    }

    next();
};

/**
 * Middleware to require premium subscription
 */
const requirePremium = (req, res, next) => {
    if (!req.user) {
        const errorResponse = authService.generateErrorResponse('INVALID_TOKEN');
        return res.status(errorResponse.status).json(errorResponse);
    }

    if (!req.user.isPremium) {
        const errorResponse = authService.generateErrorResponse('PREMIUM_REQUIRED');
        return res.status(errorResponse.status).json(errorResponse);
    }

    next();
};

/**
 * Simple PIN-based admin authentication middleware
 * Validates admin PIN session from client-side localStorage values
 */
const authenticatePIN = (req, res, next) => {
    const adminAuth = req.headers['x-admin-auth'];
    const authTime = req.headers['x-admin-auth-time'];
    
    console.log('AUTH PIN authentication check:', {
        hasAdminAuth: !!adminAuth,
        hasAuthTime: !!authTime,
        path: req.path
    });

    // Use AuthService to validate PIN
    const validation = authService.validateAdminPIN(adminAuth, authTime);
    
    if (!validation.valid) {
        console.log('ERROR PIN authentication failed:', validation.error);
        return res.status(401).json({ 
            error: validation.error,
            code: validation.error.includes('expired') ? 'SESSION_EXPIRED' : 'ADMIN_AUTH_REQUIRED'
        });
    }

    console.log('SUCCESS PIN authentication successful');
    
    // Add admin user object for compatibility
    req.user = {
        id: 'admin',
        email: 'admin@justlayme.com',
        isAdmin: true
    };
    
    next();
};

/**
 * Middleware to require admin role
 */
const requireAdmin = async (req, res, next) => {
    if (!req.user) {
        const errorResponse = authService.generateErrorResponse('INVALID_TOKEN');
        return res.status(errorResponse.status).json(errorResponse);
    }

    // Check if user already has admin flag (from PIN auth or previous verification)
    if (req.user.isAdmin) {
        return next();
    }

    try {
        // Check if user has admin role in database
        const db = authService.getDatabase();
        const adminCheck = await db.query(
            'SELECT id, is_admin FROM users WHERE id = ? AND is_admin = 1', 
            [req.user.id]
        );
        
        const admins = adminCheck.rows || adminCheck;
        if (!admins || admins.length === 0) {
            const errorResponse = authService.generateErrorResponse('ADMIN_REQUIRED');
            return res.status(errorResponse.status).json(errorResponse);
        }

        // Add admin flag to user object
        req.user.isAdmin = true;
        next();
        
    } catch (error) {
        console.error('Admin check error:', error);
        const errorResponse = authService.generateErrorResponse('AUTH_SERVICE_ERROR', {
            error: 'Authorization check failed',
            code: 'AUTH_CHECK_FAILED'
        });
        return res.status(errorResponse.status).json(errorResponse);
    }
};

/**
 * Logout middleware - blacklists the token
 */
const logout = async (req, res) => {
    const token = authService.extractTokenFromHeader(req.headers['authorization']);
    
    if (token) {
        await authService.blacklistToken(token);
        console.log('SUCCESS Token blacklisted on logout');
    }
    
    // Clear any session data
    if (req.session) {
        req.session.destroy((err) => {
            if (err) {
                console.error('Session destroy error:', err);
            }
        });
    }
    
    res.json({ 
        success: true, 
        message: 'Logged out successfully' 
    });
};

/**
 * Rate limiting middleware for authentication endpoints
 */
const authRateLimiter = (req, res, next) => {
    const clientIp = req.ip || req.connection.remoteAddress || req.socket.remoteAddress || 
                     (req.connection.socket ? req.connection.socket.remoteAddress : null);
    
    const rateLimitCheck = authService.checkRateLimit(clientIp);
    
    if (!rateLimitCheck.allowed) {
        console.warn(`WARNING Rate limit exceeded for IP: ${clientIp}`);
        const errorResponse = authService.generateErrorResponse('RATE_LIMIT_EXCEEDED', {
            message: rateLimitCheck.message,
            retryAfter: rateLimitCheck.lockoutRemaining
        });
        return res.status(errorResponse.status).json(errorResponse);
    }
    
    req.clientIp = clientIp;
    next();
};

module.exports = {
    // Middleware functions
    authenticateToken,
    authenticatePIN,
    optionalAuth,
    requireEmailVerification,
    requirePremium,
    requireAdmin,
    logout,
    authRateLimiter,
    
    // AuthService methods (for backward compatibility)
    validatePassword: authService.validatePassword.bind(authService),
    validateAuthInput: authService.validateAuthInput.bind(authService),
    
    // AuthService reference for direct access
    authService,
    
    // Security config from AuthService
    SECURITY_CONFIG: authService.config
};