/**
 * Voice Cloning API Routes
 * Provides HTTP endpoints for XTTS-v2 voice cloning integration
 */

const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs').promises;
const logger = require('../logger');

/**
 * Configure multer for voice sample uploads
 */
function configureMulter(uploadDir) {
    // Create temporary upload directory
    const tempDir = path.join(uploadDir, 'temp');

    return multer({
        dest: tempDir,
        limits: {
            fileSize: 10 * 1024 * 1024, // 10MB
            files: 1
        },
        fileFilter: (req, file, cb) => {
            // Allowed MIME types
            const allowedMimes = [
                'audio/wav',
                'audio/wave',
                'audio/x-wav',
                'audio/mpeg',
                'audio/mp3',
                'audio/ogg',
                'audio/webm',
                'audio/flac'
            ];

            // Check MIME type
            if (!allowedMimes.includes(file.mimetype)) {
                return cb(new Error('Invalid file type. Only audio files (WAV, MP3, OGG, WEBM, FLAC) are allowed'));
            }

            // Check file extension
            const ext = path.extname(file.originalname).toLowerCase();
            const allowedExts = ['.wav', '.mp3', '.ogg', '.webm', '.flac'];

            if (!allowedExts.includes(ext)) {
                return cb(new Error('Invalid file extension. Only .wav, .mp3, .ogg, .webm, .flac are allowed'));
            }

            cb(null, true);
        }
    });
}

/**
 * Setup voice cloning API routes
 */
function setupVoiceCloningAPI(app, voiceService, authenticateToken, inputValidation) {
    const router = express.Router();

    // Configure multer
    const upload = configureMulter(voiceService.voiceSamplesDir);

    /**
     * POST /api/voice-clone
     * Upload and save a voice sample for cloning
     *
     * Authentication: Required (JWT token)
     * Body: multipart/form-data with 'voiceSample' file and 'sampleName' text field
     *
     * Response:
     * {
     *   success: true,
     *   sample: {
     *     id: string,
     *     sampleName: string,
     *     fileName: string,
     *     fileSize: number,
     *     duration: number,
     *     createdAt: number
     *   }
     * }
     */
    router.post('/voice-clone', authenticateToken, upload.single('voiceSample'), async (req, res) => {
        const requestId = req.requestId || 'unknown';

        try {
            logger.info('Voice clone request received', {
                requestId,
                userId: req.user.id,
                hasFile: !!req.file
            });

            // Validate authentication
            if (!req.user || !req.user.id) {
                return res.status(401).json({
                    success: false,
                    error: 'Authentication required',
                    code: 'AUTH_REQUIRED'
                });
            }

            // Validate file upload
            if (!req.file) {
                return res.status(400).json({
                    success: false,
                    error: 'No voice sample file provided',
                    code: 'MISSING_FILE'
                });
            }

            // Validate sample name
            const sampleName = req.body.sampleName || 'Untitled Voice';
            if (sampleName.length > 100) {
                return res.status(400).json({
                    success: false,
                    error: 'Sample name too long (max 100 characters)',
                    code: 'INVALID_NAME'
                });
            }

            // Validate file with service
            const validation = voiceService.validateVoiceSample(req.file);
            if (!validation.valid) {
                // Clean up uploaded file
                try {
                    await fs.unlink(req.file.path);
                } catch (error) {
                    logger.warn('Failed to cleanup invalid file:', error);
                }

                return res.status(400).json({
                    success: false,
                    error: 'Invalid voice sample file',
                    details: validation.errors,
                    code: 'INVALID_FILE'
                });
            }

            // Save voice sample
            const sample = await voiceService.saveVoiceSample(
                req.user.id,
                req.file,
                sampleName
            );

            logger.info('Voice sample saved successfully', {
                requestId,
                userId: req.user.id,
                sampleId: sample.id,
                sampleName: sample.sampleName
            });

            res.status(201).json({
                success: true,
                sample: {
                    id: sample.id,
                    sampleName: sample.sampleName,
                    fileName: sample.fileName,
                    fileSize: sample.fileSize,
                    duration: sample.duration,
                    mimeType: sample.mimeType,
                    createdAt: sample.createdAt
                }
            });

        } catch (error) {
            logger.error('Voice clone upload failed:', {
                requestId,
                error: error.message,
                stack: error.stack
            });

            // Clean up file on error
            if (req.file && req.file.path) {
                try {
                    await fs.unlink(req.file.path);
                } catch (cleanupError) {
                    logger.warn('Failed to cleanup file after error:', cleanupError);
                }
            }

            res.status(500).json({
                success: false,
                error: 'Failed to process voice sample',
                message: error.message,
                code: 'PROCESSING_ERROR'
            });
        }
    });

    /**
     * POST /api/voice-synthesize
     * Generate speech using a cloned voice
     *
     * Authentication: Required (JWT token)
     * Body (JSON):
     * {
     *   sampleId: string,
     *   text: string,
     *   language?: string (default: 'en')
     * }
     *
     * Response: Audio file (audio/wav)
     */
    router.post('/voice-synthesize', authenticateToken, inputValidation.voiceSynthesize, async (req, res) => {
        const requestId = req.requestId || 'unknown';

        try {
            const { sampleId, text, language = 'en' } = req.body;

            logger.info('Voice synthesize request received', {
                requestId,
                userId: req.user.id,
                sampleId,
                textLength: text.length,
                language
            });

            // Validate authentication
            if (!req.user || !req.user.id) {
                return res.status(401).json({
                    success: false,
                    error: 'Authentication required',
                    code: 'AUTH_REQUIRED'
                });
            }

            // Check XTTS server health
            const health = await voiceService.checkXTTSHealth();
            if (!health.available) {
                logger.error('XTTS server unavailable', {
                    requestId,
                    error: health.error
                });

                return res.status(503).json({
                    success: false,
                    error: 'Voice synthesis service temporarily unavailable',
                    code: 'SERVICE_UNAVAILABLE'
                });
            }

            // Synthesize speech
            const result = await voiceService.synthesizeSpeech(
                req.user.id,
                sampleId,
                text,
                language
            );

            logger.info('Speech synthesized successfully', {
                requestId,
                userId: req.user.id,
                sampleId,
                jobId: result.jobId,
                processingTime: result.processingTime
            });

            // Stream the audio file
            res.setHeader('Content-Type', 'audio/wav');
            res.setHeader('Content-Disposition', `attachment; filename="${result.fileName}"`);
            res.setHeader('X-Processing-Time', result.processingTime);
            res.setHeader('X-Job-Id', result.jobId);

            const audioData = await fs.readFile(result.outputPath);
            res.send(audioData);

        } catch (error) {
            logger.error('Voice synthesize failed:', {
                requestId,
                error: error.message,
                stack: error.stack
            });

            // Check for specific error types
            if (error.message.includes('not found')) {
                return res.status(404).json({
                    success: false,
                    error: 'Voice sample not found',
                    code: 'SAMPLE_NOT_FOUND'
                });
            }

            if (error.message.includes('XTTS')) {
                return res.status(503).json({
                    success: false,
                    error: 'Voice synthesis failed',
                    message: error.message,
                    code: 'SYNTHESIS_FAILED'
                });
            }

            res.status(500).json({
                success: false,
                error: 'Failed to synthesize speech',
                message: error.message,
                code: 'PROCESSING_ERROR'
            });
        }
    });

    /**
     * GET /api/voice-samples/:userId
     * Get list of voice samples for a user
     *
     * Authentication: Required (JWT token)
     * User can only access their own samples
     *
     * Response:
     * {
     *   success: true,
     *   samples: Array<VoiceSample>
     * }
     */
    router.get('/voice-samples/:userId', authenticateToken, async (req, res) => {
        const requestId = req.requestId || 'unknown';

        try {
            const requestedUserId = req.params.userId;

            logger.info('Voice samples list request received', {
                requestId,
                requestedUserId,
                authenticatedUserId: req.user.id
            });

            // Validate authentication
            if (!req.user || !req.user.id) {
                return res.status(401).json({
                    success: false,
                    error: 'Authentication required',
                    code: 'AUTH_REQUIRED'
                });
            }

            // Authorization check - users can only access their own samples
            if (req.user.id !== requestedUserId) {
                logger.warn('Unauthorized voice samples access attempt', {
                    requestId,
                    authenticatedUserId: req.user.id,
                    requestedUserId
                });

                return res.status(403).json({
                    success: false,
                    error: 'You can only access your own voice samples',
                    code: 'FORBIDDEN'
                });
            }

            // Get user's voice samples
            const samples = await voiceService.getUserVoiceSamples(requestedUserId);

            logger.info('Voice samples retrieved', {
                requestId,
                userId: requestedUserId,
                count: samples.length
            });

            res.json({
                success: true,
                samples
            });

        } catch (error) {
            logger.error('Failed to get voice samples:', {
                requestId,
                error: error.message,
                stack: error.stack
            });

            res.status(500).json({
                success: false,
                error: 'Failed to retrieve voice samples',
                message: error.message,
                code: 'RETRIEVAL_ERROR'
            });
        }
    });

    /**
     * DELETE /api/voice-samples/:userId/:sampleId
     * Delete a voice sample
     *
     * Authentication: Required (JWT token)
     * User can only delete their own samples
     *
     * Response:
     * {
     *   success: true,
     *   deleted: string (sampleId)
     * }
     */
    router.delete('/voice-samples/:userId/:sampleId', authenticateToken, async (req, res) => {
        const requestId = req.requestId || 'unknown';

        try {
            const { userId, sampleId } = req.params;

            logger.info('Voice sample delete request received', {
                requestId,
                requestedUserId: userId,
                sampleId,
                authenticatedUserId: req.user.id
            });

            // Validate authentication
            if (!req.user || !req.user.id) {
                return res.status(401).json({
                    success: false,
                    error: 'Authentication required',
                    code: 'AUTH_REQUIRED'
                });
            }

            // Authorization check - users can only delete their own samples
            if (req.user.id !== userId) {
                logger.warn('Unauthorized voice sample delete attempt', {
                    requestId,
                    authenticatedUserId: req.user.id,
                    requestedUserId: userId,
                    sampleId
                });

                return res.status(403).json({
                    success: false,
                    error: 'You can only delete your own voice samples',
                    code: 'FORBIDDEN'
                });
            }

            // Delete voice sample
            const result = await voiceService.deleteVoiceSample(userId, sampleId);

            logger.info('Voice sample deleted successfully', {
                requestId,
                userId,
                sampleId
            });

            res.json({
                success: true,
                deleted: result.deleted
            });

        } catch (error) {
            logger.error('Failed to delete voice sample:', {
                requestId,
                error: error.message,
                stack: error.stack
            });

            if (error.message.includes('not found')) {
                return res.status(404).json({
                    success: false,
                    error: 'Voice sample not found',
                    code: 'SAMPLE_NOT_FOUND'
                });
            }

            res.status(500).json({
                success: false,
                error: 'Failed to delete voice sample',
                message: error.message,
                code: 'DELETE_ERROR'
            });
        }
    });

    /**
     * GET /api/voice-health
     * Check XTTS server health status
     *
     * Authentication: Optional
     *
     * Response:
     * {
     *   success: true,
     *   health: {
     *     available: boolean,
     *     modelLoaded: boolean,
     *     gpu: string,
     *     vramUsedGb: number
     *   }
     * }
     */
    router.get('/voice-health', async (req, res) => {
        const requestId = req.requestId || 'unknown';

        try {
            logger.info('Voice health check request received', { requestId });

            const health = await voiceService.checkXTTSHealth();

            res.json({
                success: true,
                health
            });

        } catch (error) {
            logger.error('Voice health check failed:', {
                requestId,
                error: error.message
            });

            res.status(500).json({
                success: false,
                error: 'Health check failed',
                code: 'HEALTH_CHECK_ERROR'
            });
        }
    });

    /**
     * GET /api/voice-languages
     * Get list of supported languages
     *
     * Authentication: Not required
     *
     * Response:
     * {
     *   success: true,
     *   languages: string[]
     * }
     */
    router.get('/voice-languages', (req, res) => {
        res.json({
            success: true,
            languages: voiceService.getAvailableLanguages()
        });
    });

    // Mount router
    app.use('/api', router);

    logger.info('Voice Cloning API routes registered');

    return router;
}

module.exports = setupVoiceCloningAPI;
