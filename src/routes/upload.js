/**
 * Upload API Routes
 * Handles file uploads for chat attachments and avatars
 */

const express = require('express');
const router = express.Router();
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// File Upload Configuration for Chat Attachments and Avatars
const chatUpload = multer({
    dest: '/tmp/chat-uploads',
    limits: {
        fileSize: 5 * 1024 * 1024, // 5MB limit
        files: 1
    },
    fileFilter: (req, file, cb) => {
        // Only allow image files
        const allowedMimeTypes = [
            'image/jpeg',
            'image/jpg',
            'image/png',
            'image/gif',
            'image/webp'
        ];

        if (!allowedMimeTypes.includes(file.mimetype)) {
            const error = new Error('Invalid file type. Only images (JPG, PNG, GIF, WebP) are allowed.');
            error.code = 'INVALID_FILE_TYPE';
            return cb(error, false);
        }

        const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
        const fileExtension = path.extname(file.originalname).toLowerCase();
        if (!allowedExtensions.includes(fileExtension)) {
            const error = new Error('Invalid file extension.');
            error.code = 'INVALID_FILE_EXTENSION';
            return cb(error, false);
        }

        // Sanitize filename
        file.originalname = file.originalname.replace(/[^\w\-_.]/g, '').substring(0, 100);
        if (!file.originalname || file.originalname.length < 3) {
            file.originalname = `attachment_${Date.now()}${fileExtension}`;
        }

        cb(null, true);
    }
});

/**
 * POST /api/upload
 * Upload chat attachment (image)
 */
router.post('/', chatUpload.single('file'), async (req, res) => {
    try {
        // Require authentication - reject anonymous uploads
        if (!req.user || !req.user.id) {
            return res.status(401).json({ error: 'Authentication required' });
        }

        if (!req.file) {
            return res.status(400).json({ error: 'No file uploaded' });
        }

        const userId = req.user.id;
        const conversationId = req.body.conversationId;

        // Create permanent upload directory for user
        const userUploadDir = path.join(__dirname, '../../uploads/chat', String(userId));
        if (!fs.existsSync(userUploadDir)) {
            fs.mkdirSync(userUploadDir, { recursive: true, mode: 0o755 });
        }

        // Generate unique filename
        const fileExtension = path.extname(req.file.originalname);
        const uniqueFilename = `${Date.now()}_${Math.random().toString(36).substring(7)}${fileExtension}`;
        const permanentPath = path.join(userUploadDir, uniqueFilename);

        // Move file from temp to permanent location
        fs.renameSync(req.file.path, permanentPath);

        // Generate public URL
        const fileUrl = `/uploads/chat/${userId}/${uniqueFilename}`;

        console.log(`File uploaded successfully: ${fileUrl} for user ${userId}`);

        res.json({
            success: true,
            fileUrl,
            filename: req.file.originalname,
            size: req.file.size,
            mimeType: req.file.mimetype
        });

    } catch (error) {
        console.error('Chat file upload error:', error);

        // Clean up temp file if exists
        if (req.file && req.file.path && fs.existsSync(req.file.path)) {
            try {
                fs.unlinkSync(req.file.path);
            } catch (cleanupError) {
                console.error('Error cleaning up temp file:', cleanupError);
            }
        }

        res.status(500).json({
            error: 'File upload failed',
            message: error.message
        });
    }
});

/**
 * POST /api/upload/avatar
 * Upload character avatar
 */
router.post('/avatar', chatUpload.single('avatar'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ error: 'No avatar file uploaded' });
        }

        const userId = req.user?.id || 'anonymous';

        // Create avatar directory
        const avatarDir = path.join(__dirname, '../../uploads/avatars', String(userId));
        if (!fs.existsSync(avatarDir)) {
            fs.mkdirSync(avatarDir, { recursive: true, mode: 0o755 });
        }

        // Generate unique filename
        const fileExtension = path.extname(req.file.originalname);
        const uniqueFilename = `avatar_${Date.now()}${fileExtension}`;
        const permanentPath = path.join(avatarDir, uniqueFilename);

        // Move file from temp to permanent location
        fs.renameSync(req.file.path, permanentPath);

        // Generate public URL
        const avatarUrl = `/uploads/avatars/${userId}/${uniqueFilename}`;

        console.log(`Avatar uploaded successfully: ${avatarUrl} for user ${userId}`);

        res.json({
            success: true,
            avatarUrl,
            filename: req.file.originalname,
            size: req.file.size
        });

    } catch (error) {
        console.error('Avatar upload error:', error);

        // Clean up temp file if exists
        if (req.file && req.file.path && fs.existsSync(req.file.path)) {
            try {
                fs.unlinkSync(req.file.path);
            } catch (cleanupError) {
                console.error('Error cleaning up temp file:', cleanupError);
            }
        }

        res.status(500).json({
            error: 'Avatar upload failed',
            message: error.message
        });
    }
});

module.exports = router;
