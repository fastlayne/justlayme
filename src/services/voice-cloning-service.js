/**
 * Voice Cloning Service
 * Integrates with XTTS-v2 server for voice cloning and synthesis
 * Handles file management, database tracking, and API proxying
 */

const axios = require('axios');
const fs = require('fs').promises;
const path = require('path');
const crypto = require('crypto');
const { promisify } = require('util');
const logger = require('../logger');

class VoiceCloningService {
    constructor(options = {}) {
        this.xttsUrl = options.xttsUrl || 'http://localhost:5558';
        this.voiceSamplesDir = options.voiceSamplesDir || path.join(__dirname, '../../voice-samples');
        this.db = options.database;

        // File size limits
        this.MAX_FILE_SIZE = 10 * 1024 * 1024; // 10MB
        this.MIN_DURATION = 3; // seconds
        this.MAX_DURATION = 30; // seconds

        // Allowed MIME types
        this.ALLOWED_MIME_TYPES = [
            'audio/wav',
            'audio/wave',
            'audio/x-wav',
            'audio/mpeg',
            'audio/mp3',
            'audio/ogg',
            'audio/webm',
            'audio/flac'
        ];

        // Supported languages from XTTS-v2
        this.SUPPORTED_LANGUAGES = [
            'en', 'es', 'fr', 'de', 'it', 'pt', 'pl',
            'tr', 'ru', 'nl', 'cs', 'ar', 'zh-cn', 'ja', 'ko'
        ];

        // Cache for XTTS health status
        this.healthCheckCache = {
            lastCheck: 0,
            status: null,
            cacheDuration: 30000 // 30 seconds
        };

        logger.info('Voice Cloning Service initialized', {
            xttsUrl: this.xttsUrl,
            voiceSamplesDir: this.voiceSamplesDir
        });
    }

    /**
     * Initialize database schema
     */
    async initialize() {
        try {
            // Run migration
            const migrationPath = path.join(__dirname, '../../database/migrations/003_voice_samples.sql');
            const migrationSQL = await fs.readFile(migrationPath, 'utf8');

            // Split by semicolon and execute each statement
            const statements = migrationSQL
                .split(';')
                .map(s => s.trim())
                .filter(s => s.length > 0 && !s.startsWith('--'));

            for (const statement of statements) {
                try {
                    await this.db.query(statement);
                } catch (error) {
                    // Ignore "already exists" errors
                    if (!error.message.includes('already exists')) {
                        throw error;
                    }
                }
            }

            logger.info('Voice samples database schema initialized');
            return { success: true };
        } catch (error) {
            logger.error('Failed to initialize voice samples schema:', error);
            throw new Error(`Database initialization failed: ${error.message}`);
        }
    }

    /**
     * Check XTTS server health with caching
     */
    async checkXTTSHealth() {
        const now = Date.now();

        // Return cached result if still valid
        if (this.healthCheckCache.lastCheck &&
            (now - this.healthCheckCache.lastCheck) < this.healthCheckCache.cacheDuration) {
            return this.healthCheckCache.status;
        }

        try {
            const response = await axios.get(`${this.xttsUrl}/api/health`, {
                timeout: 5000
            });

            const status = {
                available: response.data.status === 'healthy',
                modelLoaded: response.data.model_loaded,
                gpu: response.data.gpu,
                vramUsedGb: response.data.vram_used_gb,
                timestamp: now
            };

            this.healthCheckCache = {
                lastCheck: now,
                status: status,
                cacheDuration: 30000
            };

            return status;
        } catch (error) {
            logger.error('XTTS health check failed:', error.message);

            const status = {
                available: false,
                error: error.message,
                timestamp: now
            };

            this.healthCheckCache = {
                lastCheck: now,
                status: status,
                cacheDuration: 5000 // Shorter cache for failures
            };

            return status;
        }
    }

    /**
     * Validate voice sample file
     */
    validateVoiceSample(file) {
        const errors = [];

        // Check file exists
        if (!file) {
            errors.push('No file provided');
            return { valid: false, errors };
        }

        // Check file size
        if (file.size > this.MAX_FILE_SIZE) {
            errors.push(`File size exceeds maximum of ${this.MAX_FILE_SIZE / 1024 / 1024}MB`);
        }

        if (file.size < 1000) {
            errors.push('File size too small (minimum 1KB)');
        }

        // Check MIME type
        if (!this.ALLOWED_MIME_TYPES.includes(file.mimetype)) {
            errors.push(`Invalid file type. Allowed: ${this.ALLOWED_MIME_TYPES.join(', ')}`);
        }

        // Check file extension
        const ext = path.extname(file.originalname).toLowerCase();
        const allowedExts = ['.wav', '.mp3', '.ogg', '.webm', '.flac'];
        if (!allowedExts.includes(ext)) {
            errors.push(`Invalid file extension. Allowed: ${allowedExts.join(', ')}`);
        }

        return {
            valid: errors.length === 0,
            errors
        };
    }

    /**
     * Save voice sample file to disk
     */
    async saveVoiceSample(userId, file, sampleName) {
        try {
            // Create user directory if it doesn't exist
            const userDir = path.join(this.voiceSamplesDir, userId);
            await fs.mkdir(userDir, { recursive: true, mode: 0o755 });

            // Generate unique filename
            const timestamp = Date.now();
            const randomId = crypto.randomBytes(8).toString('hex');
            const ext = path.extname(file.originalname);
            const fileName = `${timestamp}_${randomId}${ext}`;
            const filePath = path.join(userDir, fileName);

            // Move uploaded file to destination
            await fs.rename(file.path, filePath);

            // Set file permissions
            await fs.chmod(filePath, 0o644);

            // Get file stats
            const stats = await fs.stat(filePath);

            // Generate unique ID
            const sampleId = crypto.randomBytes(16).toString('hex');

            // Get audio duration (basic check, could be enhanced)
            const duration = await this.getAudioDuration(filePath);

            // Validate duration
            if (duration && (duration < this.MIN_DURATION || duration > this.MAX_DURATION)) {
                await fs.unlink(filePath);
                throw new Error(`Audio duration must be between ${this.MIN_DURATION} and ${this.MAX_DURATION} seconds`);
            }

            // Save to database
            const now = Date.now();
            await this.db.query(
                `INSERT INTO voice_samples
                (id, user_id, sample_name, file_path, file_size, duration_seconds, mime_type, created_at, updated_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
                [sampleId, userId, sampleName, filePath, stats.size, duration, file.mimetype, now, now]
            );

            logger.info('Voice sample saved', {
                userId,
                sampleId,
                fileName,
                size: stats.size,
                duration
            });

            return {
                id: sampleId,
                sampleName,
                fileName,
                filePath,
                fileSize: stats.size,
                duration,
                mimeType: file.mimetype,
                createdAt: now
            };
        } catch (error) {
            logger.error('Failed to save voice sample:', error);

            // Clean up file if it exists
            try {
                if (file.path) {
                    await fs.unlink(file.path);
                }
            } catch (cleanupError) {
                logger.error('Failed to cleanup file:', cleanupError);
            }

            throw error;
        }
    }

    /**
     * Get audio duration using file size estimation
     * For production, consider using ffprobe or similar
     */
    async getAudioDuration(filePath) {
        try {
            const stats = await fs.stat(filePath);
            const ext = path.extname(filePath).toLowerCase();

            // Rough estimation based on file type
            // WAV: ~10MB per minute at 44.1kHz 16-bit stereo
            // MP3: ~1MB per minute at 128kbps
            let estimatedDuration;
            if (ext === '.wav') {
                estimatedDuration = (stats.size / 1024 / 1024) * 6; // seconds
            } else if (ext === '.mp3') {
                estimatedDuration = (stats.size / 1024 / 1024) * 60; // seconds
            } else {
                estimatedDuration = 10; // default estimate
            }

            return Math.round(estimatedDuration * 10) / 10;
        } catch (error) {
            logger.warn('Could not estimate audio duration:', error.message);
            return null;
        }
    }

    /**
     * Get user's voice samples
     */
    async getUserVoiceSamples(userId) {
        try {
            const result = await this.db.query(
                `SELECT id, sample_name, file_path, file_size, duration_seconds,
                        mime_type, language, quality_score, is_active, created_at, updated_at
                FROM voice_samples
                WHERE user_id = ? AND is_active = 1
                ORDER BY created_at DESC`,
                [userId]
            );

            const samples = result.rows || result;

            return samples.map(sample => ({
                id: sample.id,
                sampleName: sample.sample_name,
                fileName: path.basename(sample.file_path),
                fileSize: sample.file_size,
                duration: sample.duration_seconds,
                mimeType: sample.mime_type,
                language: sample.language,
                qualityScore: sample.quality_score,
                createdAt: sample.created_at,
                updatedAt: sample.updated_at
            }));
        } catch (error) {
            logger.error('Failed to get user voice samples:', error);
            throw new Error('Failed to retrieve voice samples');
        }
    }

    /**
     * Delete voice sample
     */
    async deleteVoiceSample(userId, sampleId) {
        try {
            // Get sample info
            const result = await this.db.query(
                'SELECT file_path FROM voice_samples WHERE id = ? AND user_id = ?',
                [sampleId, userId]
            );

            const samples = result.rows || result;
            if (samples.length === 0) {
                throw new Error('Voice sample not found');
            }

            const filePath = samples[0].file_path;

            // Delete from database (soft delete)
            await this.db.query(
                'UPDATE voice_samples SET is_active = 0, updated_at = ? WHERE id = ?',
                [Date.now(), sampleId]
            );

            // Delete file from disk
            try {
                await fs.unlink(filePath);
                logger.info('Voice sample file deleted', { userId, sampleId, filePath });
            } catch (fileError) {
                logger.warn('Could not delete voice sample file:', fileError.message);
            }

            return { success: true, deleted: sampleId };
        } catch (error) {
            logger.error('Failed to delete voice sample:', error);
            throw error;
        }
    }

    /**
     * Synthesize speech with cloned voice
     */
    async synthesizeSpeech(userId, sampleId, text, language = 'en') {
        try {
            // Validate language
            if (!this.SUPPORTED_LANGUAGES.includes(language)) {
                throw new Error(`Unsupported language: ${language}`);
            }

            // Get voice sample path
            const result = await this.db.query(
                'SELECT file_path FROM voice_samples WHERE id = ? AND user_id = ? AND is_active = 1',
                [sampleId, userId]
            );

            const samples = result.rows || result;
            if (samples.length === 0) {
                throw new Error('Voice sample not found');
            }

            const speakerWavPath = samples[0].file_path;

            // Create synthesis job
            const jobId = crypto.randomBytes(16).toString('hex');
            const now = Date.now();

            await this.db.query(
                `INSERT INTO voice_synthesis_jobs
                (id, user_id, voice_sample_id, text, language, status, created_at)
                VALUES (?, ?, ?, ?, ?, 'processing', ?)`,
                [jobId, userId, sampleId, text, language, now]
            );

            // Call XTTS server
            const startTime = Date.now();

            try {
                const response = await axios.post(`${this.xttsUrl}/api/clone-voice`, {
                    text,
                    speaker_wav: speakerWavPath,
                    language
                }, {
                    responseType: 'arraybuffer',
                    timeout: 120000, // 2 minutes
                    maxContentLength: 50 * 1024 * 1024 // 50MB
                });

                const processingTime = Date.now() - startTime;

                // Save output file
                const outputDir = path.join(this.voiceSamplesDir, userId, 'outputs');
                await fs.mkdir(outputDir, { recursive: true, mode: 0o755 });

                const outputFileName = `${jobId}_output.wav`;
                const outputPath = path.join(outputDir, outputFileName);

                await fs.writeFile(outputPath, response.data);
                await fs.chmod(outputPath, 0o644);

                // Update job status
                await this.db.query(
                    `UPDATE voice_synthesis_jobs
                    SET status = 'completed', output_file_path = ?, processing_time_ms = ?, completed_at = ?
                    WHERE id = ?`,
                    [outputPath, processingTime, Date.now(), jobId]
                );

                // Update usage statistics
                await this.updateUsageStats(sampleId, userId, text.length);

                logger.info('Speech synthesized successfully', {
                    userId,
                    sampleId,
                    jobId,
                    processingTime,
                    textLength: text.length
                });

                return {
                    jobId,
                    outputPath,
                    processingTime,
                    fileName: outputFileName,
                    success: true
                };
            } catch (xttsError) {
                const processingTime = Date.now() - startTime;

                // Update job with error
                await this.db.query(
                    `UPDATE voice_synthesis_jobs
                    SET status = 'failed', error_message = ?, processing_time_ms = ?, completed_at = ?
                    WHERE id = ?`,
                    [xttsError.message, processingTime, Date.now(), jobId]
                );

                throw new Error(`XTTS synthesis failed: ${xttsError.message}`);
            }
        } catch (error) {
            logger.error('Speech synthesis failed:', error);
            throw error;
        }
    }

    /**
     * Update usage statistics for voice sample
     */
    async updateUsageStats(sampleId, userId, charactersCount) {
        try {
            const now = Date.now();

            // Check if stats record exists
            const existing = await this.db.query(
                'SELECT id FROM voice_sample_usage WHERE voice_sample_id = ?',
                [sampleId]
            );

            if (existing.rows && existing.rows.length > 0) {
                // Update existing
                await this.db.query(
                    `UPDATE voice_sample_usage
                    SET synthesis_count = synthesis_count + 1,
                        last_used_at = ?,
                        total_characters_synthesized = total_characters_synthesized + ?,
                        updated_at = ?
                    WHERE voice_sample_id = ?`,
                    [now, charactersCount, now, sampleId]
                );
            } else {
                // Create new
                const statsId = crypto.randomBytes(16).toString('hex');
                await this.db.query(
                    `INSERT INTO voice_sample_usage
                    (id, voice_sample_id, user_id, synthesis_count, last_used_at, total_characters_synthesized, created_at, updated_at)
                    VALUES (?, ?, ?, 1, ?, ?, ?, ?)`,
                    [statsId, sampleId, userId, now, charactersCount, now, now]
                );
            }
        } catch (error) {
            logger.warn('Failed to update usage stats:', error);
            // Non-critical error, don't throw
        }
    }

    /**
     * Get available languages
     */
    getAvailableLanguages() {
        return this.SUPPORTED_LANGUAGES;
    }

    /**
     * Clean up old synthesis outputs
     */
    async cleanupOldOutputs(retentionDays = 7) {
        try {
            const cutoffTime = Date.now() - (retentionDays * 24 * 60 * 60 * 1000);

            // Get old completed jobs
            const result = await this.db.query(
                `SELECT output_file_path FROM voice_synthesis_jobs
                WHERE status = 'completed' AND completed_at < ? AND output_file_path IS NOT NULL`,
                [cutoffTime]
            );

            const jobs = result.rows || result;
            let deletedCount = 0;

            for (const job of jobs) {
                try {
                    await fs.unlink(job.output_file_path);
                    deletedCount++;
                } catch (error) {
                    logger.warn('Could not delete old output file:', error.message);
                }
            }

            // Delete old job records
            await this.db.query(
                'DELETE FROM voice_synthesis_jobs WHERE completed_at < ?',
                [cutoffTime]
            );

            logger.info(`Cleaned up ${deletedCount} old voice synthesis outputs`);
            return { deletedCount };
        } catch (error) {
            logger.error('Cleanup failed:', error);
            throw error;
        }
    }
}

module.exports = VoiceCloningService;
