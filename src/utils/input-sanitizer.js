/**
 * Input Sanitization Utility
 * Comprehensive input validation and sanitization for security
 */

const crypto = require('crypto');

class InputSanitizer {
    constructor() {
        // Common patterns to detect and sanitize
        this.patterns = {
            // SQL injection patterns
            sqlInjection: /('|(\')|;|--|\/\*|\*\/|\bUNION\b|\bSELECT\b|\bINSERT\b|\bUPDATE\b|\bDELETE\b|\bDROP\b|\bCREATE\b|\bALTER\b)/gi,
            
            // XSS patterns
            xss: /<script[^>]*>.*?<\/script>/gi,
            htmlTags: /<[^>]*>/g,
            javascript: /javascript:/gi,
            onEvents: /on\w+\s*=/gi,
            
            // Command injection patterns
            commandInjection: /[;&|`$(){}[\]\\]/g,
            
            // Path traversal patterns
            pathTraversal: /\.\./g,
            
            // Email pattern (for validation)
            email: /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/,
            
            // Safe characters for different contexts
            alphanumeric: /^[a-zA-Z0-9]+$/,
            alphanumericWithSpaces: /^[a-zA-Z0-9\s]+$/,
            username: /^[a-zA-Z0-9_-]+$/,
            filename: /^[a-zA-Z0-9._-]+$/
        };
    }

    /**
     * Sanitizes a string by removing/escaping potentially dangerous characters
     * @param {string} input - Input string to sanitize
     * @param {string} context - Context for sanitization (html, sql, shell, etc.)
     * @returns {string} Sanitized string
     */
    sanitizeString(input, context = 'general') {
        if (!input || typeof input !== 'string') {
            return '';
        }

        // Limit length to prevent buffer overflow attacks
        if (input.length > 10000) {
            input = input.substring(0, 10000);
        }

        switch (context) {
            case 'html':
                return this.sanitizeForHTML(input);
            case 'sql':
                return this.sanitizeForSQL(input);
            case 'shell':
                return this.sanitizeForShell(input);
            case 'filename':
                return this.sanitizeFilename(input);
            case 'url':
                return this.sanitizeForURL(input);
            case 'email':
                return this.sanitizeEmail(input);
            case 'username':
                return this.sanitizeUsername(input);
            case 'general':
            default:
                return this.generalSanitize(input);
        }
    }

    /**
     * Sanitizes input for HTML context
     */
    sanitizeForHTML(input) {
        return input
            .replace(/&/g, '&amp;')
            .replace(/</g, '&lt;')
            .replace(/>/g, '&gt;')
            .replace(/"/g, '&quot;')
            .replace(/'/g, '&#x27;')
            .replace(/\//g, '&#x2F;')
            .replace(this.patterns.javascript, '')
            .replace(this.patterns.onEvents, '');
    }

    /**
     * Sanitizes input for SQL context (though parameterized queries are preferred)
     */
    sanitizeForSQL(input) {
        return input
            .replace(/'/g, "''")  // Escape single quotes
            .replace(/\\/g, '\\\\') // Escape backslashes
            .replace(/\x00/g, '\\0') // Escape null bytes
            .replace(/\n/g, '\\n') // Escape newlines
            .replace(/\r/g, '\\r') // Escape carriage returns
            .replace(/\x1a/g, '\\Z'); // Escape ctrl+Z
    }

    /**
     * Sanitizes input for shell commands
     */
    sanitizeForShell(input) {
        // Very restrictive - only allow safe characters
        return input.replace(/[^a-zA-Z0-9._-]/g, '');
    }

    /**
     * Sanitizes filename
     */
    sanitizeFilename(input) {
        return input
            .replace(/[<>:"/\\|?*\x00-\x1f]/g, '') // Remove invalid characters
            .replace(/^\.+/, '') // Remove leading dots
            .replace(/\.+$/, '') // Remove trailing dots
            .replace(/\s+/g, '_') // Replace spaces with underscores
            .substring(0, 255); // Limit length
    }

    /**
     * Sanitizes input for URL context
     */
    sanitizeForURL(input) {
        try {
            return encodeURIComponent(input);
        } catch (e) {
            return '';
        }
    }

    /**
     * Sanitizes and validates email
     */
    sanitizeEmail(input) {
        const sanitized = input.trim().toLowerCase();
        if (this.patterns.email.test(sanitized) && sanitized.length <= 254) {
            return sanitized;
        }
        return '';
    }

    /**
     * Sanitizes username
     */
    sanitizeUsername(input) {
        const sanitized = input.trim();
        if (this.patterns.username.test(sanitized) && 
            sanitized.length >= 3 && 
            sanitized.length <= 32) {
            return sanitized;
        }
        return '';
    }

    /**
     * General sanitization
     */
    generalSanitize(input) {
        return input
            .replace(this.patterns.xss, '')
            .replace(this.patterns.sqlInjection, '')
            .replace(this.patterns.commandInjection, '')
            .replace(/\x00/g, '') // Remove null bytes
            .trim();
    }

    /**
     * Validates input against specified criteria
     * @param {any} input - Input to validate
     * @param {object} rules - Validation rules
     * @returns {object} Validation result
     */
    validate(input, rules = {}) {
        const result = {
            isValid: true,
            errors: [],
            sanitized: input
        };

        // Check if input is required
        if (rules.required && (!input || (typeof input === 'string' && input.trim() === ''))) {
            result.isValid = false;
            result.errors.push('This field is required');
            return result;
        }

        // Skip further validation if input is empty and not required
        if (!input && !rules.required) {
            return result;
        }

        // Type validation
        if (rules.type) {
            switch (rules.type) {
                case 'string':
                    if (typeof input !== 'string') {
                        result.isValid = false;
                        result.errors.push('Must be a string');
                        return result;
                    }
                    break;
                case 'number':
                    if (typeof input !== 'number' || isNaN(input)) {
                        result.isValid = false;
                        result.errors.push('Must be a valid number');
                        return result;
                    }
                    break;
                case 'email':
                    if (!this.patterns.email.test(input)) {
                        result.isValid = false;
                        result.errors.push('Must be a valid email address');
                        return result;
                    }
                    break;
            }
        }

        // Length validation
        if (rules.minLength && input.length < rules.minLength) {
            result.isValid = false;
            result.errors.push(`Must be at least ${rules.minLength} characters long`);
        }

        if (rules.maxLength && input.length > rules.maxLength) {
            result.isValid = false;
            result.errors.push(`Must be no more than ${rules.maxLength} characters long`);
        }

        // Pattern validation
        if (rules.pattern && !rules.pattern.test(input)) {
            result.isValid = false;
            result.errors.push('Invalid format');
        }

        // Sanitize if valid
        if (result.isValid && typeof input === 'string') {
            result.sanitized = this.sanitizeString(input, rules.context || 'general');
        }

        return result;
    }

    /**
     * Sanitizes an entire object recursively
     * @param {object} obj - Object to sanitize
     * @param {object} rules - Field-specific rules
     * @returns {object} Sanitized object
     */
    sanitizeObject(obj, rules = {}) {
        if (!obj || typeof obj !== 'object') {
            return obj;
        }

        const sanitized = {};
        
        for (const [key, value] of Object.entries(obj)) {
            // Skip prototype pollution attempts
            if (['__proto__', 'constructor', 'prototype'].includes(key)) {
                continue;
            }

            // Sanitize key
            const sanitizedKey = this.sanitizeString(key, 'general');
            if (!sanitizedKey || sanitizedKey.length > 100) {
                continue; // Skip invalid keys
            }

            // Apply field-specific rules
            const fieldRules = rules[key] || {};
            
            if (typeof value === 'string') {
                const validation = this.validate(value, fieldRules);
                if (validation.isValid) {
                    sanitized[sanitizedKey] = validation.sanitized;
                }
            } else if (typeof value === 'number') {
                sanitized[sanitizedKey] = value;
            } else if (typeof value === 'boolean') {
                sanitized[sanitizedKey] = value;
            } else if (Array.isArray(value)) {
                sanitized[sanitizedKey] = value.map(item => 
                    typeof item === 'string' ? 
                    this.sanitizeString(item, fieldRules.context) : 
                    item
                ).slice(0, 100); // Limit array size
            } else if (value && typeof value === 'object') {
                sanitized[sanitizedKey] = this.sanitizeObject(value, fieldRules.nested || {});
            }
        }

        return sanitized;
    }

    /**
     * Rate limiting key generator
     * @param {string} identifier - IP, user ID, etc.
     * @returns {string} Rate limiting key
     */
    generateRateLimitKey(identifier) {
        // Hash the identifier to prevent information leakage
        return crypto.createHash('sha256').update(identifier).digest('hex').substring(0, 16);
    }
}

module.exports = new InputSanitizer();