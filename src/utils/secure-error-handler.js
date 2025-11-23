/**
 * Secure Error Handler - Prevents information disclosure through error messages
 * Sanitizes errors before sending them to clients while maintaining proper logging
 */

class SecureErrorHandler {
    constructor() {
        // Error codes that are safe to expose to clients
        this.safeErrorCodes = new Set([
            'VALIDATION_ERROR',
            'AUTHENTICATION_ERROR',
            'AUTHORIZATION_ERROR',
            'NOT_FOUND',
            'RATE_LIMITED',
            'BAD_REQUEST',
            'PAYMENT_REQUIRED',
            'PAYMENT_FAILED',
            'SUBSCRIPTION_REQUIRED'
        ]);

        // Generic error messages for different scenarios
        this.genericMessages = {
            400: 'Invalid request',
            401: 'Authentication required',
            403: 'Access denied',
            404: 'Resource not found',
            429: 'Rate limit exceeded',
            500: 'Internal server error',
            502: 'Service temporarily unavailable',
            503: 'Service unavailable'
        };
    }

    /**
     * Sanitizes an error for client consumption
     * @param {Error|string} error - The error to sanitize
     * @param {number} statusCode - HTTP status code
     * @param {string} context - Context for logging
     * @returns {object} Sanitized error response
     */
    sanitizeError(error, statusCode = 500, context = '') {
        const timestamp = new Date().toISOString();
        const errorId = this.generateErrorId();

        // Log the full error details for debugging (server-side only)
        this.logFullError(error, statusCode, context, errorId);

        // Prepare sanitized response for client
        const response = {
            success: false,
            error: this.genericMessages[statusCode] || 'An error occurred',
            errorId: errorId,
            timestamp: timestamp
        };

        // Only include specific error details if they're safe
        if (error && typeof error === 'object') {
            // Check if it's a safe error type
            if (error.code && this.safeErrorCodes.has(error.code)) {
                response.details = this.sanitizeMessage(error.message);
            }

            // Handle specific error types
            if (error.name === 'ValidationError') {
                response.error = 'Validation failed';
                response.details = this.sanitizeValidationErrors(error);
            } else if (error.name === 'CastError') {
                response.error = 'Invalid data format';
            }
        }

        return response;
    }

    /**
     * Sanitizes error message to remove sensitive information
     * @param {string} message - Error message to sanitize
     * @returns {string} Sanitized message
     */
    sanitizeMessage(message) {
        if (!message || typeof message !== 'string') {
            return 'An error occurred';
        }

        // Remove file paths, stack traces, and other sensitive info
        return message
            .replace(/\/[a-zA-Z0-9\/\._-]+/g, '[path]') // Remove file paths
            .replace(/at [a-zA-Z0-9\/\._-]+:[0-9]+:[0-9]+/g, '[location]') // Remove stack locations
            .replace(/Error: /g, '') // Remove error prefixes
            .replace(/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/g, '[ip]') // Remove IP addresses
            .replace(/\b[a-f0-9]{32}\b/g, '[id]') // Remove hash-like strings
            .replace(/password|token|secret|key|auth/gi, '[credential]') // Remove credential references
            .substring(0, 200); // Limit length
    }

    /**
     * Sanitizes validation errors
     * @param {Error} error - Validation error
     * @returns {object} Sanitized validation details
     */
    sanitizeValidationErrors(error) {
        if (!error.errors) return null;

        const sanitized = {};
        for (const [field, details] of Object.entries(error.errors)) {
            if (typeof field === 'string' && field.length < 100) {
                sanitized[field] = this.sanitizeMessage(details.message || details);
            }
        }
        return sanitized;
    }

    /**
     * Logs full error details for server-side debugging
     * @param {Error|string} error - The original error
     * @param {number} statusCode - HTTP status code
     * @param {string} context - Context information
     * @param {string} errorId - Unique error identifier
     */
    logFullError(error, statusCode, context, errorId) {
        const logEntry = {
            errorId: errorId,
            timestamp: new Date().toISOString(),
            statusCode: statusCode,
            context: context,
            message: error?.message || error,
            stack: error?.stack,
            name: error?.name,
            code: error?.code
        };

        if (statusCode >= 500) {
            console.error(`🔥 SERVER ERROR [${errorId}]:`, logEntry);
        } else if (statusCode >= 400) {
            console.warn(`⚠️  CLIENT ERROR [${errorId}]:`, logEntry);
        }
    }

    /**
     * Generates a unique error ID for correlation
     * @returns {string} Unique error identifier
     */
    generateErrorId() {
        return `err_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    }

    /**
     * Express middleware for handling errors securely
     * @param {Error} err - Error object
     * @param {Request} req - Express request
     * @param {Response} res - Express response
     * @param {Function} next - Next middleware
     */
    middleware(err, req, res, next) {
        const context = `${req.method} ${req.path}`;
        const statusCode = err.statusCode || err.status || 500;
        
        const sanitizedError = this.sanitizeError(err, statusCode, context);
        
        res.status(statusCode).json(sanitizedError);
    }

    /**
     * Wraps async route handlers to catch and handle errors securely
     * @param {Function} handler - Async route handler
     * @returns {Function} Wrapped handler
     */
    asyncHandler(handler) {
        return (req, res, next) => {
            Promise.resolve(handler(req, res, next)).catch(next);
        };
    }
}

module.exports = new SecureErrorHandler();