// Request ID middleware for JustLayMe
// Generates unique request IDs for better debugging and request tracing

const crypto = require('crypto');

/**
 * Middleware to generate and attach unique request IDs
 * Adds request ID to headers and makes it available for logging
 */
function requestIdMiddleware(req, res, next) {
    // Generate unique request ID using crypto.randomUUID()
    const requestId = crypto.randomUUID();
    
    // Add request ID to request object for use in route handlers
    req.requestId = requestId;
    
    // Add request ID to response headers for client-side debugging
    res.setHeader('X-Request-ID', requestId);
    
    // Add request ID to response locals for template rendering if needed
    res.locals.requestId = requestId;
    
    // Log incoming request with request ID
    const timestamp = new Date().toISOString();
    console.log(`📨 [REQUEST] [${requestId}] ${timestamp} ${req.method} ${req.originalUrl} - IP: ${req.ip || req.connection.remoteAddress}`);
    
    // Track request start time for performance monitoring
    req.startTime = Date.now();
    
    // Hook into response finish event to log request completion
    const originalSend = res.send;
    res.send = function(body) {
        const duration = Date.now() - req.startTime;
        const statusCode = res.statusCode;
        const statusEmoji = statusCode >= 500 ? '❌' : statusCode >= 400 ? '⚠️' : '✅';
        
        console.log(`📤 [RESPONSE] [${requestId}] ${req.method} ${req.originalUrl} - ${statusEmoji} ${statusCode} - ${duration}ms`);
        
        return originalSend.call(this, body);
    };
    
    next();
}

module.exports = requestIdMiddleware;