// Input validation middleware for JustLayMe
// Validates and sanitizes all API endpoint inputs

const logger = require('../logger');
const inputSanitizer = require('../utils/input-sanitizer');

/**
 * Input validation schemas for different endpoints
 */
const validationSchemas = {
    // Chat endpoint validation
    chat: {
        required: ['message', 'character'],
        fields: {
            message: {
                type: 'string',
                minLength: 1,
                maxLength: 10000,
                sanitize: true
            },
            character: {
                type: 'string',
                minLength: 1,
                maxLength: 100
                // Removed allowed restriction to support custom character IDs
            },
            history: {
                type: 'array',
                optional: true,
                maxItems: 100
            },
            conversationId: {
                type: ['string', 'number'],
                optional: true,
                validate: (value) => {
                    if (typeof value === 'number') {
                        // For numbers: must be positive safe integer
                        return Number.isSafeInteger(value) && value > 0;
                    }
                    // For strings: alphanumeric with hyphens/underscores, max 50 chars
                    return /^[a-zA-Z0-9_-]+$/.test(value) && value.length <= 50;
                }
            },
            isCustomCharacter: {
                type: 'boolean',
                optional: true
            },
            userId: {
                type: ['string', 'number'],
                optional: true,
                validate: (value) => {
                    if (typeof value === 'number') {
                        // For numbers: must be positive safe integer
                        return Number.isSafeInteger(value) && value > 0;
                    }
                    // For strings: alphanumeric with hyphens/underscores, max 50 chars
                    return /^[a-zA-Z0-9_-]+$/.test(value) && value.length <= 50;
                }
            }
        }
    },

    // Custom character creation validation
    customCharacter: {
        required: ['name', 'config'],
        fields: {
            name: {
                type: 'string',
                minLength: 1,
                maxLength: 100,
                sanitize: true
            },
            config: {
                type: 'object',
                required: ['systemPrompt'],
                fields: {
                    systemPrompt: {
                        type: 'string',
                        minLength: 1,
                        maxLength: 5000,
                        sanitize: true
                    },
                    personality: {
                        type: 'string',
                        optional: true,
                        maxLength: 1000,
                        sanitize: true
                    }
                }
            },
            userId: {
                type: 'string',
                pattern: /^[0-9]+$/,
                required: true
            }
        }
    },

    // Email validation
    email: {
        type: 'string',
        pattern: /^[^\s@]+@[^\s@]+\.[^\s@]+$/,
        maxLength: 254
    },

    // User ID validation
    userId: {
        type: 'string',
        pattern: /^[0-9]+$/
    },

    // Voice cloning - synthesize speech validation
    voiceSynthesize: {
        required: ['sampleId', 'text'],
        fields: {
            sampleId: {
                type: 'string',
                minLength: 1,
                maxLength: 100,
                pattern: /^[a-zA-Z0-9_-]+$/,
                required: true
            },
            text: {
                type: 'string',
                minLength: 1,
                maxLength: 5000,
                sanitize: true,
                required: true
            },
            language: {
                type: 'string',
                optional: true,
                allowed: ['en', 'es', 'fr', 'de', 'it', 'pt', 'pl', 'tr', 'ru', 'nl', 'cs', 'ar', 'zh-cn', 'ja', 'ko']
            }
        }
    }
};

// Sanitization now handled by centralized inputSanitizer utility
// See /src/utils/input-sanitizer.js for the comprehensive implementation

/**
 * Validate individual field based on schema
 */
function validateField(fieldName, value, schema, requestId) {
    const errors = [];
    
    // Check if required field is present
    if (schema.required && (value === undefined || value === null || value === '')) {
        errors.push(`${fieldName} is required`);
        return errors;
    }
    
    // Skip validation if field is optional and not provided
    if (!schema.required && (value === undefined || value === null)) {
        return errors;
    }
    
    // Type validation
    if (schema.type) {
        const actualType = Array.isArray(value) ? 'array' : typeof value;
        const allowedTypes = Array.isArray(schema.type) ? schema.type : [schema.type];
        if (!allowedTypes.includes(actualType)) {
            errors.push(`${fieldName} must be of type ${allowedTypes.join(' or ')}, got ${actualType}`);
            return errors;
        }
    }
    
    // String validations
    const allowedTypes = Array.isArray(schema.type) ? schema.type : [schema.type];
    if (allowedTypes.includes('string') && typeof value === 'string') {
        if (schema.minLength && value.length < schema.minLength) {
            errors.push(`${fieldName} must be at least ${schema.minLength} characters long`);
        }
        if (schema.maxLength && value.length > schema.maxLength) {
            errors.push(`${fieldName} must be no more than ${schema.maxLength} characters long`);
        }
        if (schema.pattern && !schema.pattern.test(value)) {
            errors.push(`${fieldName} has invalid format`);
        }
        if (schema.allowed && !schema.allowed.includes(value)) {
            errors.push(`${fieldName} must be one of: ${schema.allowed.join(', ')}`);
        }
    }
    
    // Array validations
    if (allowedTypes.includes('array') && Array.isArray(value)) {
        if (schema.maxItems && value.length > schema.maxItems) {
            errors.push(`${fieldName} must have no more than ${schema.maxItems} items`);
        }
    }

    // Custom validation function
    if (schema.validate && typeof schema.validate === 'function') {
        const isValid = schema.validate(value);
        if (!isValid) {
            errors.push(`${fieldName} has invalid value`);
        }
    }

    return errors;
}

/**
 * Validate and sanitize request body based on schema
 */
function validateBody(body, schema, requestId) {
    const errors = [];
    const sanitizedBody = {};
    
    // Check required fields
    if (schema.required) {
        for (const requiredField of schema.required) {
            if (!body.hasOwnProperty(requiredField) || body[requiredField] === undefined || body[requiredField] === null) {
                errors.push(`Missing required field: ${requiredField}`);
            }
        }
    }
    
    // Validate each field
    if (schema.fields) {
        for (const [fieldName, fieldSchema] of Object.entries(schema.fields)) {
            const value = body[fieldName];
            const fieldErrors = validateField(fieldName, value, fieldSchema, requestId);
            errors.push(...fieldErrors);
            
            // Sanitize string fields if no errors
            if (fieldErrors.length === 0 && value !== undefined) {
                if (fieldSchema.sanitize && typeof value === 'string') {
                    sanitizedBody[fieldName] = inputSanitizer.sanitizeString(value, 'general');
                } else if (fieldSchema.type === 'object' && typeof value === 'object') {
                    // Recursively validate nested objects
                    const nestedResult = validateBody(value, fieldSchema, requestId);
                    if (nestedResult.errors.length > 0) {
                        errors.push(...nestedResult.errors.map(err => `${fieldName}.${err}`));
                    } else {
                        sanitizedBody[fieldName] = nestedResult.sanitizedBody;
                    }
                } else {
                    sanitizedBody[fieldName] = value;
                }
            }
        }
    }
    
    // Copy any additional fields that aren't in the schema (for flexibility)
    for (const [key, value] of Object.entries(body)) {
        if (!schema.fields || !schema.fields[key]) {
            sanitizedBody[key] = value;
        }
    }
    
    return { errors, sanitizedBody };
}

/**
 * Create validation middleware for specific schema
 */
function createValidationMiddleware(schemaName) {
    return (req, res, next) => {
        const schema = validationSchemas[schemaName];
        if (!schema) {
            logger.error(`Invalid validation schema: ${schemaName}`, req.requestId);
            return res.status(500).json({
                error: 'Internal validation error',
                requestId: req.requestId
            });
        }
        
        logger.debug(`Validating request body for ${schemaName}`, req.requestId);
        
        const result = validateBody(req.body, schema, req.requestId);
        
        if (result.errors.length > 0) {
            logger.warn(`Validation failed for ${schemaName}:`, req.requestId, result.errors);
            return res.status(400).json({
                error: 'Validation failed',
                details: result.errors,
                requestId: req.requestId
            });
        }
        
        // Replace request body with sanitized version
        req.body = result.sanitizedBody;
        req.validatedBody = result.sanitizedBody; // Keep original for reference
        
        logger.debug(`Validation passed for ${schemaName}`, req.requestId);
        next();
    };
}

/**
 * Generic input validation middleware
 */
const inputValidation = {
    chat: createValidationMiddleware('chat'),
    customCharacter: createValidationMiddleware('customCharacter'),
    voiceSynthesize: createValidationMiddleware('voiceSynthesize'),

    // Validate email parameter
    email: (req, res, next) => {
        const email = req.params.email || req.body.email;
        if (email) {
            const errors = validateField('email', email, validationSchemas.email, req.requestId);
            if (errors.length > 0) {
                return res.status(400).json({
                    error: 'Invalid email format',
                    details: errors,
                    requestId: req.requestId
                });
            }
        }
        next();
    },

    // Validate user ID parameter
    userId: (req, res, next) => {
        const userId = req.params.userId || req.body.userId;
        if (userId) {
            const errors = validateField('userId', userId, validationSchemas.userId, req.requestId);
            if (errors.length > 0) {
                return res.status(400).json({
                    error: 'Invalid user ID format',
                    details: errors,
                    requestId: req.requestId
                });
            }
        }
        next();
    }
};

module.exports = inputValidation;