/**
 * Cache Buster Utility
 * Generates version parameters for static assets to prevent caching issues
 * especially with Cloudflare CDN caching
 */

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');

class CacheBuster {
    constructor() {
        this.versionCache = new Map();
        this.enabled = process.env.CACHE_BUSTING !== 'false';
    }

    /**
     * Get file hash for cache busting
     * @param {string} filePath - Path to the file
     * @returns {string} - Hash string for versioning
     */
    getFileHash(filePath) {
        try {
            if (!this.enabled) return 'dev';

            // Check cache first
            if (this.versionCache.has(filePath)) {
                return this.versionCache.get(filePath);
            }

            // Generate hash from file content
            const fileContent = fs.readFileSync(filePath);
            const hash = crypto.createHash('md5')
                .update(fileContent)
                .digest('hex')
                .substring(0, 8);

            // Cache it
            this.versionCache.set(filePath, hash);
            return hash;
        } catch (error) {
            console.warn(`Cache buster: Could not hash file ${filePath}:`, error.message);
            return Date.now().toString();
        }
    }

    /**
     * Add version parameter to asset URL
     * @param {string} assetPath - Relative asset path (e.g., 'styles.css')
     * @param {string} publicDir - Public directory path
     * @returns {string} - Asset path with version parameter
     */
    addVersion(assetPath, publicDir) {
        if (!this.enabled) return assetPath;

        try {
            const fullPath = path.join(publicDir, assetPath);
            const hash = this.getFileHash(fullPath);
            const separator = assetPath.includes('?') ? '&' : '?';
            return `${assetPath}${separator}v=${hash}`;
        } catch (error) {
            console.warn(`Cache buster: Could not version asset ${assetPath}:`, error.message);
            return assetPath;
        }
    }

    /**
     * Clear version cache (useful for development)
     */
    clearCache() {
        this.versionCache.clear();
    }
}

// Singleton instance
const cacheBuster = new CacheBuster();

module.exports = cacheBuster;
