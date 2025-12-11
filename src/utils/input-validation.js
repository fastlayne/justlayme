/**
 * Comprehensive Input Validation Utilities for JustLayMe
 * Protects against injection attacks, validates data types and formats
 */

class InputValidator {
    /**
     * Validate message content for chat API
     */
    static validateChatMessage(message) {
        const errors = [];
        
        if (!message || typeof message !== 'string') {
            errors.push('Message must be a non-empty string');
            return { valid: false, errors };
        }
        
        if (message.length === 0) {
            errors.push('Message cannot be empty');
        }
        
        if (message.length > 5000) {
            errors.push('Message too long (max 5000 characters)');
        }
        
        // Check for potential script injection attempts
        const dangerousPatterns = [
            /<script/i,
            /javascript:/i,
            /on\w+\s*=/i,
            /data:text\/html/i,
            /vbscript:/i
        ];
        
        for (const pattern of dangerousPatterns) {
            if (pattern.test(message)) {
                errors.push('Message contains potentially dangerous content');
                break;
            }
        }
        
        return { valid: errors.length === 0, errors, sanitized: message.trim() };
    }
    
    /**
     * Validate character name/ID
     */
    static validateCharacter(character) {
        const errors = [];
        
        if (!character || typeof character !== 'string') {
            errors.push('Character must be a non-empty string');
            return { valid: false, errors };
        }
        
        if (character.length === 0 || character.length > 100) {
            errors.push('Character name must be 1-100 characters');
        }
        
        // Allow alphanumeric, spaces, hyphens, underscores
        if (!/^[a-zA-Z0-9\s_-]+$/.test(character)) {
            errors.push('Character name contains invalid characters');
        }
        
        return { valid: errors.length === 0, errors, sanitized: character.trim() };
    }
    
    /**
     * Validate conversation history array
     */
    static validateHistory(history) {
        const errors = [];
        
        if (!history) {
            return { valid: true, errors: [], sanitized: [] };
        }
        
        if (!Array.isArray(history)) {
            errors.push('History must be an array');
            return { valid: false, errors };
        }
        
        if (history.length > 100) {
            errors.push('History too long (max 100 messages)');
        }
        
        const sanitized = [];
        for (let i = 0; i < Math.min(history.length, 100); i++) {
            const msg = history[i];
            if (!msg || typeof msg !== 'object') {
                errors.push(`History item ${i} is invalid`);
                continue;
            }
            
            if (!msg.role || !msg.content) {
                errors.push(`History item ${i} missing role or content`);
                continue;
            }
            
            if (!['user', 'assistant', 'system'].includes(msg.role)) {
                errors.push(`History item ${i} has invalid role`);
                continue;
            }
            
            if (typeof msg.content !== 'string' || msg.content.length > 5000) {
                errors.push(`History item ${i} content is invalid`);
                continue;
            }
            
            sanitized.push({
                role: msg.role,
                content: msg.content.trim()
            });
        }
        
        return { valid: errors.length === 0, errors, sanitized };
    }
    
    /**
     * Validate user ID
     */
    static validateUserId(userId) {
        const errors = [];
        
        if (!userId) {
            errors.push('User ID is required');
            return { valid: false, errors };
        }
        
        // Allow string or number
        if (typeof userId !== 'string' && typeof userId !== 'number') {
            errors.push('User ID must be string or number');
            return { valid: false, errors };
        }
        
        const stringId = String(userId).trim();
        if (stringId.length === 0) {
            errors.push('User ID cannot be empty');
        }
        
        if (stringId.length > 50) {
            errors.push('User ID too long');
        }
        
        // Allow alphanumeric, hyphens, underscores
        if (!/^[a-zA-Z0-9_-]+$/.test(stringId)) {
            errors.push('User ID contains invalid characters');
        }
        
        return { valid: errors.length === 0, errors, sanitized: stringId };
    }
    
    /**
     * Validate email address
     */
    static validateEmail(email) {
        const errors = [];
        
        if (!email || typeof email !== 'string') {
            errors.push('Email must be a non-empty string');
            return { valid: false, errors };
        }
        
        const emailRegex = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
        const trimmedEmail = email.trim().toLowerCase();
        
        if (!emailRegex.test(trimmedEmail)) {
            errors.push('Invalid email format');
        }
        
        if (trimmedEmail.length > 254) {
            errors.push('Email too long');
        }
        
        return { valid: errors.length === 0, errors, sanitized: trimmedEmail };
    }
    
    /**
     * Validate password strength
     */
    static validatePassword(password) {
        const errors = [];
        
        if (!password || typeof password !== 'string') {
            errors.push('Password must be a string');
            return { valid: false, errors };
        }
        
        if (password.length < 8) {
            errors.push('Password must be at least 8 characters long');
        }
        
        if (password.length > 100) {
            errors.push('Password too long (max 100 characters)');
        }
        
        if (!/[a-z]/.test(password)) {
            errors.push('Password must contain at least one lowercase letter');
        }
        
        if (!/[A-Z]/.test(password)) {
            errors.push('Password must contain at least one uppercase letter');
        }
        
        if (!/[0-9]/.test(password)) {
            errors.push('Password must contain at least one number');
        }
        
        // Check for common weak passwords
        const weakPasswords = ['password', '123456', 'qwerty', 'admin', 'password123'];
        if (weakPasswords.includes(password.toLowerCase())) {
            errors.push('Password is too weak');
        }
        
        return { valid: errors.length === 0, errors };
    }
    
    /**
     * Validate JSON string and parse safely
     */
    static validateJSON(jsonString, maxSize = 10000) {
        const errors = [];
        
        if (!jsonString || typeof jsonString !== 'string') {
            errors.push('Invalid JSON string');
            return { valid: false, errors };
        }
        
        if (jsonString.length > maxSize) {
            errors.push(`JSON too large (max ${maxSize} characters)`);
            return { valid: false, errors };
        }
        
        try {
            const parsed = JSON.parse(jsonString);
            return { valid: true, errors: [], sanitized: parsed };
        } catch (e) {
            errors.push('Invalid JSON format');
            return { valid: false, errors };
        }
    }
    
    /**
     * Validate conversation ID
     */
    static validateConversationId(conversationId) {
        const errors = [];
        
        if (!conversationId) {
            return { valid: true, errors: [], sanitized: null }; // Optional field
        }
        
        if (typeof conversationId !== 'string' && typeof conversationId !== 'number') {
            errors.push('Conversation ID must be string or number');
            return { valid: false, errors };
        }
        
        const stringId = String(conversationId).trim();
        if (stringId.length === 0) {
            errors.push('Conversation ID cannot be empty');
        }
        
        if (stringId.length > 50) {
            errors.push('Conversation ID too long');
        }
        
        if (!/^[a-zA-Z0-9_-]+$/.test(stringId)) {
            errors.push('Conversation ID contains invalid characters');
        }
        
        return { valid: errors.length === 0, errors, sanitized: stringId };
    }
    
    /**
     * Comprehensive chat API validation
     */
    static validateChatRequest(body) {
        const errors = [];
        const sanitized = {};
        
        // Validate message
        const messageResult = this.validateChatMessage(body.message);
        if (!messageResult.valid) {
            errors.push(...messageResult.errors);
        } else {
            sanitized.message = messageResult.sanitized;
        }
        
        // Validate character
        const characterResult = this.validateCharacter(body.character);
        if (!characterResult.valid) {
            errors.push(...characterResult.errors);
        } else {
            sanitized.character = characterResult.sanitized;
        }
        
        // Validate history (optional)
        if (body.history) {
            const historyResult = this.validateHistory(body.history);
            if (!historyResult.valid) {
                errors.push(...historyResult.errors);
            } else {
                sanitized.history = historyResult.sanitized;
            }
        }
        
        // Validate conversation ID (optional)
        if (body.conversationId) {
            const convResult = this.validateConversationId(body.conversationId);
            if (!convResult.valid) {
                errors.push(...convResult.errors);
            } else {
                sanitized.conversationId = convResult.sanitized;
            }
        }
        
        // Validate boolean flags
        if (body.isCustomCharacter !== undefined) {
            if (typeof body.isCustomCharacter !== 'boolean') {
                errors.push('isCustomCharacter must be a boolean');
            } else {
                sanitized.isCustomCharacter = body.isCustomCharacter;
            }
        }
        
        return { valid: errors.length === 0, errors, sanitized };
    }
    
    /**
     * Rate limiting validation
     */
    static validateRateLimit(userRequests, maxRequests, windowMs) {
        const now = Date.now();
        const windowStart = now - windowMs;
        
        // Filter requests within the current window
        const recentRequests = userRequests.filter(timestamp => timestamp > windowStart);
        
        return {
            allowed: recentRequests.length < maxRequests,
            remaining: Math.max(0, maxRequests - recentRequests.length),
            resetTime: windowStart + windowMs
        };
    }
}

module.exports = InputValidator;