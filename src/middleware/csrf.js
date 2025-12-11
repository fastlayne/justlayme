const crypto = require('crypto');

/**
 * CSRF Protection Middleware
 * Generates and validates CSRF tokens for state-changing operations
 */
class CSRFProtection {
    constructor() {
        // In production, CSRF_SECRET must be explicitly set - do not use random fallback
        if (process.env.NODE_ENV === 'production' && !process.env.CSRF_SECRET) {
            throw new Error('CSRF_SECRET environment variable must be set in production');
        }
        this.secret = process.env.CSRF_SECRET || crypto.randomBytes(32).toString('hex');
    }

    /**
     * Generates a CSRF token
     * @param {string} sessionId - Session identifier
     * @returns {string} CSRF token
     */
    generateToken(sessionId) {
        const timestamp = Date.now().toString();
        const data = `${sessionId}:${timestamp}`;
        const hash = crypto.createHmac('sha256', this.secret).update(data).digest('hex');
        
        // Format: timestamp.hash
        return `${timestamp}.${hash}`;
    }

    /**
     * Validates a CSRF token
     * @param {string} token - CSRF token to validate
     * @param {string} sessionId - Session identifier
     * @param {number} maxAge - Maximum token age in milliseconds (default: 1 hour)
     * @returns {boolean} Whether token is valid
     */
    validateToken(token, sessionId, maxAge = 3600000) {
        try {
            if (!token || !sessionId) {
                return false;
            }

            const parts = token.split('.');
            if (parts.length !== 2) {
                return false;
            }

            const [timestampStr, providedHash] = parts;
            const timestamp = parseInt(timestampStr, 10);

            // Check if token is expired
            if (Date.now() - timestamp > maxAge) {
                return false;
            }

            // Validate hash
            const data = `${sessionId}:${timestamp}`;
            const expectedHash = crypto.createHmac('sha256', this.secret).update(data).digest('hex');

            // Use timing-safe comparison
            return crypto.timingSafeEqual(
                Buffer.from(providedHash, 'hex'),
                Buffer.from(expectedHash, 'hex')
            );
        } catch (error) {
            console.error('CSRF token validation error:', error);
            return false;
        }
    }

    /**
     * Express middleware to generate CSRF tokens
     */
    generateMiddleware() {
        return (req, res, next) => {
            // Generate session ID if not exists
            if (!req.sessionID) {
                req.sessionID = crypto.randomBytes(16).toString('hex');
            }

            // Generate CSRF token
            const csrfToken = this.generateToken(req.sessionID);
            
            // Add token to response
            res.locals.csrfToken = csrfToken;
            
            // Add helper method to request
            req.generateCSRFToken = () => csrfToken;

            next();
        };
    }

    /**
     * Express middleware to validate CSRF tokens
     */
    validateMiddleware() {
        return (req, res, next) => {
            // Skip validation for GET, HEAD, OPTIONS requests
            if (['GET', 'HEAD', 'OPTIONS'].includes(req.method)) {
                return next();
            }

            // Skip validation for certain endpoints (webhooks, etc.)
            const skipPaths = ['/api/webhooks/stripe'];
            if (skipPaths.some(path => req.path.startsWith(path))) {
                return next();
            }

            // Get session ID
            const sessionId = req.sessionID || req.user?.id;
            if (!sessionId) {
                return res.status(403).json({
                    error: 'Invalid session',
                    code: 'INVALID_SESSION'
                });
            }

            // Get CSRF token from header or body
            const csrfToken = req.get('X-CSRF-Token') || 
                             req.body?.csrfToken || 
                             req.body?._csrf;

            if (!csrfToken) {
                return res.status(403).json({
                    error: 'CSRF token required',
                    code: 'CSRF_TOKEN_REQUIRED'
                });
            }

            // Validate token
            if (!this.validateToken(csrfToken, sessionId)) {
                return res.status(403).json({
                    error: 'Invalid CSRF token',
                    code: 'INVALID_CSRF_TOKEN'
                });
            }

            next();
        };
    }

    /**
     * Get CSRF token endpoint
     */
    getTokenEndpoint() {
        return (req, res) => {
            // Generate session ID if not exists
            if (!req.sessionID && !req.user?.id) {
                req.sessionID = crypto.randomBytes(16).toString('hex');
            }

            const sessionId = req.sessionID || req.user?.id;
            const csrfToken = this.generateToken(sessionId);

            res.json({
                csrfToken: csrfToken,
                sessionId: sessionId
            });
        };
    }
}

const csrfProtection = new CSRFProtection();

module.exports = {
    generateToken: csrfProtection.generateMiddleware(),
    validateToken: csrfProtection.validateMiddleware(),
    getTokenEndpoint: csrfProtection.getTokenEndpoint(),
    CSRFProtection: csrfProtection
};