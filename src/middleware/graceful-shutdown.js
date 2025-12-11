// Graceful shutdown middleware for JustLayMe
// Handles clean server shutdowns without dropping connections

const logger = require('../logger');

class GracefulShutdown {
    constructor(server, options = {}) {
        this.server = server;
        this.shuttingDown = false;
        this.connections = new Set();
        this.timeout = options.timeout || 30000; // 30 seconds default
        this.logger = options.logger || logger;
        
        // Track connections
        this.server.on('connection', (socket) => {
            this.connections.add(socket);
            socket.on('close', () => {
                this.connections.delete(socket);
            });
        });
        
        // Setup signal handlers
        this.setupSignalHandlers();
    }
    
    setupSignalHandlers() {
        // Handle SIGTERM (Kubernetes, Docker stop)
        process.on('SIGTERM', () => {
            this.logger.info('Received SIGTERM signal. Starting graceful shutdown...');
            this.gracefulShutdown('SIGTERM');
        });
        
        // Handle SIGINT (Ctrl+C)
        process.on('SIGINT', () => {
            this.logger.info('Received SIGINT signal. Starting graceful shutdown...');
            this.gracefulShutdown('SIGINT');
        });
        
        // Handle SIGUSR2 (PM2 reload)
        process.on('SIGUSR2', () => {
            this.logger.info('Received SIGUSR2 signal. Starting graceful shutdown...');
            this.gracefulShutdown('SIGUSR2');
        });
        
        // Handle uncaught exceptions
        process.on('uncaughtException', (error) => {
            this.logger.error('Uncaught Exception:', null, error);
            this.gracefulShutdown('uncaughtException', 1);
        });
        
        // Handle unhandled promise rejections
        process.on('unhandledRejection', (reason, promise) => {
            this.logger.error('Unhandled Rejection at:', null, promise, 'reason:', reason);
            this.gracefulShutdown('unhandledRejection', 1);
        });
    }
    
    async gracefulShutdown(signal, exitCode = 0) {
        if (this.shuttingDown) {
            this.logger.warn('Shutdown already in progress, ignoring signal:', null, signal);
            return;
        }
        
        this.shuttingDown = true;
        this.logger.info(`Starting graceful shutdown due to ${signal}...`);
        
        // Set a timeout to force exit if shutdown takes too long
        const forceExitTimeout = setTimeout(() => {
            this.logger.error('Graceful shutdown timeout exceeded, forcing exit');
            process.exit(1);
        }, this.timeout);
        
        try {
            // Stop accepting new connections
            this.logger.info('Stopping server from accepting new connections...');
            await new Promise((resolve, reject) => {
                this.server.close((err) => {
                    if (err) {
                        reject(err);
                    } else {
                        resolve();
                    }
                });
            });
            
            // Close existing connections gracefully
            this.logger.info(`Closing ${this.connections.size} existing connections...`);
            const connectionPromises = Array.from(this.connections).map(socket => {
                return new Promise((resolve) => {
                    socket.end(() => resolve());
                    // Force close after 5 seconds
                    setTimeout(() => {
                        socket.destroy();
                        resolve();
                    }, 5000);
                });
            });
            
            await Promise.all(connectionPromises);
            
            // Clean up other resources
            await this.cleanup();
            
            clearTimeout(forceExitTimeout);
            this.logger.info('Graceful shutdown completed successfully');
            process.exit(exitCode);
            
        } catch (error) {
            clearTimeout(forceExitTimeout);
            this.logger.error('Error during graceful shutdown:', null, error);
            process.exit(1);
        }
    }
    
    // Override this method to add custom cleanup logic
    async cleanup() {
        this.logger.info('Performing cleanup tasks...');
        
        // Close database connections
        try {
            // If there's a database connection pool, close it here
            this.logger.info('Closing database connections...');
        } catch (error) {
            this.logger.error('Error closing database connections:', null, error);
        }
        
        // Clear any intervals or timeouts
        // Cancel any pending operations
        // Save any important state
        
        this.logger.info('Cleanup completed');
    }
    
    // Middleware to reject requests during shutdown
    getMiddleware() {
        return (req, res, next) => {
            if (this.shuttingDown) {
                res.status(503).json({
                    error: 'Server is shutting down',
                    message: 'Please try again in a few moments'
                });
                return;
            }
            next();
        };
    }
    
    // Health check method
    isHealthy() {
        return !this.shuttingDown;
    }
}

module.exports = GracefulShutdown;