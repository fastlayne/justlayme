/**
 * HTML Cache Busting Middleware
 * Automatically adds version parameters to CSS/JS links in HTML responses
 */

const fs = require('fs');
const path = require('path');
const cacheBuster = require('../cache-buster');

/**
 * Middleware to inject cache-busting version parameters into HTML
 */
function cacheBustHTML(publicDir) {
    return (req, res, next) => {
        // Only process HTML file requests
        const isHtmlRequest = req.path.endsWith('.html') ||
                             req.path === '/' ||
                             req.path.endsWith('/');

        if (!isHtmlRequest) {
            return next();
        }

        // Determine the HTML file path
        let htmlFilePath;
        if (req.path === '/' || req.path.endsWith('/')) {
            htmlFilePath = path.join(publicDir, 'index.html');
        } else {
            htmlFilePath = path.join(publicDir, req.path);
        }

        // Check if file exists
        if (!fs.existsSync(htmlFilePath)) {
            return next();
        }

        try {
            console.log(`🔍 Processing HTML file: ${htmlFilePath}`);

            // Read the HTML file
            let htmlContent = fs.readFileSync(htmlFilePath, 'utf8');
            console.log(`📄 HTML file read successfully, length: ${htmlContent.length}`);

            let cssCount = 0;
            let jsCount = 0;

            // Add version parameters to CSS links
            htmlContent = htmlContent.replace(
                /(<link[^>]+href=["'])([^"':]+\.css)(\?[^"']*)?["']/gi,
                (match, prefix, cssPath, query) => {
                    // Skip external URLs
                    if (cssPath.startsWith('http')) {
                        return match;
                    }
                    const versionedPath = cacheBuster.addVersion(cssPath, publicDir);
                    cssCount++;
                    console.log(`  🎨 CSS: ${cssPath} → ${versionedPath}`);
                    return `${prefix}${versionedPath}"`;
                }
            );

            // Add version parameters to JS script src
            htmlContent = htmlContent.replace(
                /(<script[^>]+src=["'])([^"':]+\.js)(\?[^"']*)?["']/gi,
                (match, prefix, jsPath, query) => {
                    // Skip external URLs
                    if (jsPath.startsWith('http')) {
                        return match;
                    }
                    const versionedPath = cacheBuster.addVersion(jsPath, publicDir);
                    jsCount++;
                    console.log(`  ⚡ JS: ${jsPath} → ${versionedPath}`);
                    return `${prefix}${versionedPath}"`;
                }
            );

            // Set headers
            res.setHeader('Content-Type', 'text/html; charset=utf-8');
            res.setHeader('Cache-Control', 'no-cache, no-store, must-revalidate');
            res.setHeader('Pragma', 'no-cache');
            res.setHeader('Expires', '0');

            // Send the processed HTML
            res.send(htmlContent);

            console.log(`✅ Cache busting applied to ${req.path}: ${cssCount} CSS, ${jsCount} JS files versioned`);
        } catch (error) {
            console.error(`❌ Cache bust HTML middleware error for ${req.path}:`, error);
            console.error(error.stack);
            next();
        }
    };
}

module.exports = cacheBustHTML;
