// Simple logging utility for JustLayMe
// Optimizes performance by conditionally enabling logs based on environment

const isDevelopment = process.env.NODE_ENV !== 'production';
const logLevel = process.env.LOG_LEVEL || (isDevelopment ? 'debug' : 'error');

const levels = {
    error: 0,
    warn: 1,
    info: 2,
    debug: 3
};

const logger = {
    error: (message, requestId, ...args) => {
        if (levels[logLevel] >= levels.error) {
            const reqIdStr = requestId ? `[${requestId}] ` : '';
            console.error(`ERROR [ERROR] ${reqIdStr}${message}`, ...args);
        }
    },
    
    warn: (message, requestId, ...args) => {
        if (levels[logLevel] >= levels.warn) {
            const reqIdStr = requestId ? `[${requestId}] ` : '';
            console.warn(`⚠️ [WARN] ${reqIdStr}${message}`, ...args);
        }
    },
    
    info: (message, requestId, ...args) => {
        if (levels[logLevel] >= levels.info) {
            const reqIdStr = requestId ? `[${requestId}] ` : '';
            console.log(`ℹ️ [INFO] ${reqIdStr}${message}`, ...args);
        }
    },
    
    debug: (message, requestId, ...args) => {
        if (levels[logLevel] >= levels.debug) {
            const reqIdStr = requestId ? `[${requestId}] ` : '';
            console.log(`🔍 [DEBUG] ${reqIdStr}${message}`, ...args);
        }
    },
    
    // Specialized loggers for different components
    model: (message, requestId, ...args) => {
        if (levels[logLevel] >= levels.info) {
            const reqIdStr = requestId ? `[${requestId}] ` : '';
            console.log(`🤖 [MODEL] ${reqIdStr}${message}`, ...args);
        }
    },
    
    server: (message, requestId, ...args) => {
        if (levels[logLevel] >= levels.info) {
            const reqIdStr = requestId ? `[${requestId}] ` : '';
            console.log(`📡 [SERVER] ${reqIdStr}${message}`, ...args);
        }
    },
    
    strict: (message, requestId, ...args) => {
        if (levels[logLevel] >= levels.debug) {
            const reqIdStr = requestId ? `[${requestId}] ` : '';
            console.log(`🔒 [STRICT] ${reqIdStr}${message}`, ...args);
        }
    }
};

module.exports = logger;