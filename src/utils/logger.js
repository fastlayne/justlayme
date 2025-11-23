const winston = require('winston');
const path = require('path');
const fs = require('fs');

// Ensure logs directory exists
const logsDir = path.join(__dirname, '../../logs');
if (!fs.existsSync(logsDir)) {
    fs.mkdirSync(logsDir, { recursive: true });
}

// Custom log format
const logFormat = winston.format.combine(
    winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
    winston.format.errors({ stack: true }),
    winston.format.json(),
    winston.format.prettyPrint()
);

// Console format for development
const consoleFormat = winston.format.combine(
    winston.format.colorize(),
    winston.format.timestamp({ format: 'HH:mm:ss' }),
    winston.format.printf(({ timestamp, level, message, ...meta }) => {
        let logMessage = `${timestamp} [${level}]: ${message}`;
        
        if (Object.keys(meta).length > 0) {
            logMessage += '\n' + JSON.stringify(meta, null, 2);
        }
        
        return logMessage;
    })
);

// Create logger instance
const logger = winston.createLogger({
    level: process.env.LOG_LEVEL || 'info',
    format: logFormat,
    defaultMeta: { 
        service: 'justlayme',
        version: process.env.npm_package_version || '1.0.0',
        environment: process.env.NODE_ENV || 'development'
    },
    transports: [
        // Error log file
        new winston.transports.File({
            filename: path.join(logsDir, 'error.log'),
            level: 'error',
            maxsize: 5242880, // 5MB
            maxFiles: 5,
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.json()
            )
        }),
        
        // Combined log file
        new winston.transports.File({
            filename: path.join(logsDir, 'combined.log'),
            maxsize: 5242880, // 5MB
            maxFiles: 5,
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.json()
            )
        }),
        
        // Performance log file
        new winston.transports.File({
            filename: path.join(logsDir, 'performance.log'),
            level: 'info',
            maxsize: 5242880, // 5MB
            maxFiles: 3,
            format: winston.format.combine(
                winston.format.timestamp(),
                winston.format.json(),
                winston.format.label({ label: 'PERFORMANCE' })
            )
        })
    ],
    
    // Handle uncaught exceptions and rejections
    exceptionHandlers: [
        new winston.transports.File({ 
            filename: path.join(logsDir, 'exceptions.log'),
            maxsize: 5242880,
            maxFiles: 3
        })
    ],
    
    rejectionHandlers: [
        new winston.transports.File({ 
            filename: path.join(logsDir, 'rejections.log'),
            maxsize: 5242880,
            maxFiles: 3
        })
    ],
    
    exitOnError: false
});

// Add console transport for development
if (process.env.NODE_ENV !== 'production') {
    logger.add(new winston.transports.Console({
        format: consoleFormat,
        level: 'debug'
    }));
} else {
    // In production, only log errors to console
    logger.add(new winston.transports.Console({
        format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
        ),
        level: 'error'
    }));
}

// Custom logging methods
logger.api = (req, res, duration) => {
    logger.info('API Request', {
        method: req.method,
        url: req.url,
        status: res.statusCode,
        duration: `${duration}ms`,
        userAgent: req.get('User-Agent'),
        ip: req.ip,
        userId: req.user?.id || 'anonymous',
        requestId: req.id
    });
};

logger.security = (event, details = {}) => {
    logger.warn('Security Event', {
        event,
        ...details,
        timestamp: new Date().toISOString()
    });
};

logger.performance = (operation, duration, details = {}) => {
    logger.info('Performance Metric', {
        operation,
        duration: `${duration}ms`,
        ...details,
        timestamp: new Date().toISOString()
    });
};

logger.ai = (model, operation, duration, details = {}) => {
    logger.info('AI Operation', {
        model,
        operation,
        duration: `${duration}ms`,
        ...details,
        timestamp: new Date().toISOString()
    });
};

logger.database = (query, duration, details = {}) => {
    logger.debug('Database Query', {
        query: query.substring(0, 100) + (query.length > 100 ? '...' : ''),
        duration: `${duration}ms`,
        ...details,
        timestamp: new Date().toISOString()
    });
};

logger.stripe = (event, details = {}) => {
    logger.info('Stripe Event', {
        event,
        ...details,
        timestamp: new Date().toISOString()
    });
};

// Health check method
logger.health = (component, status, details = {}) => {
    const level = status === 'healthy' ? 'info' : 'error';
    logger[level]('Health Check', {
        component,
        status,
        ...details,
        timestamp: new Date().toISOString()
    });
};

// Error handling utility
logger.handleError = (error, context = {}) => {
    const errorInfo = {
        message: error.message,
        stack: error.stack,
        code: error.code,
        name: error.name,
        ...context,
        timestamp: new Date().toISOString()
    };
    
    if (error.name === 'ValidationError') {
        logger.warn('Validation Error', errorInfo);
    } else if (error.name === 'UnauthorizedError') {
        logger.warn('Unauthorized Access', errorInfo);
    } else if (error.code === 'ECONNREFUSED' || error.code === 'ENOTFOUND') {
        logger.error('Connection Error', errorInfo);
    } else {
        logger.error('Application Error', errorInfo);
    }
};

// Graceful shutdown
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    logger.end();
});

process.on('SIGINT', () => {
    logger.info('SIGINT received, shutting down gracefully');
    logger.end();
});

module.exports = logger;