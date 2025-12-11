/**
 * Grey Mirror Job Queue Service
 * Async job processing for large conversation analysis
 *
 * ARCHITECTURE:
 * 1. Jobs are stored in SQLite database for persistence
 * 2. Background worker polls for pending jobs every 5 seconds
 * 3. SSE (Server-Sent Events) provides real-time progress updates
 * 4. Files are uploaded to /tmp, parsed server-side, then deleted
 * 5. Results are stored in database as JSON
 *
 * HANDLES:
 * - 100K+ message files (no Cloudflare timeout)
 * - Real-time progress updates via SSE
 * - Graceful error handling and retry logic
 * - Automatic cleanup of old jobs and temp files
 */

const DatabaseAdapter = require('../database')
const { parseConversationData } = require('./message-parser')
const fs = require('fs').promises
const path = require('path')
const { v4: uuidv4 } = require('uuid')
const axios = require('axios')

// SSE subscriber management
const sseClients = new Map() // jobId -> Set of response objects

class GreyMirrorJobQueue {
  constructor() {
    this.db = DatabaseAdapter.getInstance()
    this.isProcessing = false
    this.workerInterval = null
  }

  /**
   * Start the background worker
   * Polls for pending jobs every 5 seconds
   */
  startWorker() {
    if (this.workerInterval) {
      console.log('⚠️ Worker already running')
      return
    }

    console.log('🚀 Starting Grey Mirror job queue worker...')

    // Process immediately on start
    this.processNextJob()

    // Then poll every 5 seconds
    this.workerInterval = setInterval(() => {
      this.processNextJob()
    }, 5000)
  }

  /**
   * Stop the background worker
   */
  stopWorker() {
    if (this.workerInterval) {
      clearInterval(this.workerInterval)
      this.workerInterval = null
      console.log('🛑 Grey Mirror job queue worker stopped')
    }
  }

  /**
   * Create a new analysis job
   * @param {Object} params - Job parameters
   * @param {number} params.userId - User ID
   * @param {string} params.fileName - Uploaded file name
   * @param {number} params.fileSize - File size in bytes
   * @param {string} params.filePath - Path to uploaded file
   * @param {Object} params.personalization - Personalization settings
   * @returns {Promise<Object>} Created job with jobId
   */
  async createJob({ userId, fileName, fileSize, filePath, personalization }) {
    const jobId = uuidv4()

    const query = `
      INSERT INTO grey_mirror_jobs
      (job_id, user_id, file_name, file_size, file_path, personalization, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 'pending', datetime('now'))
      RETURNING *
    `

    const result = await this.db.query(query, [
      jobId,
      userId,
      fileName,
      fileSize,
      filePath,
      JSON.stringify(personalization)
    ])

    const job = result.rows[0]
    console.log(`📋 Created job ${jobId} for user ${userId}: ${fileName} (${fileSize} bytes)`)

    return job
  }

  /**
   * Get job status
   * @param {string} jobId - Job ID
   * @returns {Promise<Object>} Job data
   */
  async getJob(jobId) {
    const query = 'SELECT * FROM grey_mirror_jobs WHERE job_id = ?'
    const result = await this.db.query(query, [jobId])

    if (result.rows.length === 0) {
      throw new Error(`Job ${jobId} not found`)
    }

    const job = result.rows[0]

    // Parse JSON fields
    if (job.personalization) {
      job.personalization = JSON.parse(job.personalization)
    }
    if (job.result_data) {
      job.result_data = JSON.parse(job.result_data)
    }

    return job
  }

  /**
   * Update job status and progress
   * @param {string} jobId - Job ID
   * @param {Object} updates - Fields to update
   */
  async updateJob(jobId, updates) {
    const allowedFields = [
      'status', 'started_at', 'completed_at', 'progress_percentage',
      'progress_message', 'error_message', 'result_data', 'message_count'
    ]

    const updateFields = []
    const updateValues = []

    for (const [key, value] of Object.entries(updates)) {
      if (allowedFields.includes(key)) {
        updateFields.push(`${key} = ?`)
        // Stringify JSON fields
        if (key === 'result_data') {
          updateValues.push(value ? JSON.stringify(value) : null)
        } else {
          updateValues.push(value)
        }
      }
    }

    if (updateFields.length === 0) {
      return
    }

    updateValues.push(jobId)
    const query = `UPDATE grey_mirror_jobs SET ${updateFields.join(', ')} WHERE job_id = ?`

    await this.db.query(query, updateValues)

    // Notify SSE clients of progress update
    this.notifyClients(jobId, {
      progress: updates.progress_percentage || 0,
      status: updates.status || 'processing',
      message: updates.progress_message || ''
    })
  }

  /**
   * Process the next pending job
   * This is the main worker loop
   */
  async processNextJob() {
    // Prevent concurrent processing
    if (this.isProcessing) {
      return
    }

    this.isProcessing = true

    try {
      // Get next pending job
      const query = `
        SELECT * FROM grey_mirror_jobs
        WHERE status = 'pending'
        ORDER BY created_at ASC
        LIMIT 1
      `
      const result = await this.db.query(query)

      if (result.rows.length === 0) {
        // No pending jobs
        this.isProcessing = false
        return
      }

      const job = result.rows[0]
      console.log(`🔄 Processing job ${job.job_id}: ${job.file_name}`)

      // Process the job
      await this.processJob(job)

    } catch (error) {
      console.error('❌ Error in worker loop:', error)
    } finally {
      this.isProcessing = false
    }
  }

  /**
   * Process a single job
   * @param {Object} job - Job data from database
   */
  async processJob(job) {
    const jobId = job.job_id

    try {
      // Mark as processing
      await this.updateJob(jobId, {
        status: 'processing',
        started_at: new Date().toISOString(),
        progress_percentage: 5,
        progress_message: 'Reading uploaded file...'
      })

      // Read file from disk
      const fileContent = await fs.readFile(job.file_path, 'utf8')
      console.log(`📂 Read file ${job.file_name}: ${fileContent.length} characters`)

      await this.updateJob(jobId, {
        progress_percentage: 10,
        progress_message: 'Parsing messages...'
      })

      // Parse messages using server-side parser
      const personalization = job.personalization ? JSON.parse(job.personalization) : {}

      // CRITICAL: Pass personalization to parser for correct message attribution
      console.log(`📋 Using personalization: user="${personalization.userName}", contact="${personalization.contactName}"`)
      const messages = parseConversationData(fileContent, 'file', personalization)

      if (!messages || messages.length === 0) {
        throw new Error('No messages could be parsed from the file')
      }

      console.log(`✅ Parsed ${messages.length} messages`)

      await this.updateJob(jobId, {
        message_count: messages.length,
        progress_percentage: 20,
        progress_message: `Sending ${messages.length.toLocaleString()} messages to ML service...`
      })

      // Call Python ML service
      console.log(`🧠 Calling ML service for ${messages.length} messages...`)
      const mlResponse = await axios.post('http://localhost:5001/analyze', {
        messages,
        personalization: {
          userName: personalization.userName || 'You',
          contactName: personalization.contactName || 'Them',
          insightsGoal: personalization.insightsGoal || ''
        }
      }, {
        headers: { 'Content-Type': 'application/json' },
        timeout: 300000, // 5 minute timeout for ML analysis
        validateStatus: (status) => status < 500 // Don't throw on 4xx errors
      })

      if (mlResponse.status !== 200) {
        throw new Error(`ML analysis failed: ${mlResponse.data || mlResponse.statusText}`)
      }

      await this.updateJob(jobId, {
        progress_percentage: 90,
        progress_message: 'Finalizing results...'
      })

      const results = mlResponse.data
      console.log(`✅ ML analysis complete for job ${jobId}`)

      // Store results and mark as completed
      await this.updateJob(jobId, {
        status: 'completed',
        completed_at: new Date().toISOString(),
        progress_percentage: 100,
        progress_message: 'Analysis complete!',
        result_data: results
      })

      // Clean up temporary file
      try {
        await fs.unlink(job.file_path)
        console.log(`🗑️ Cleaned up temp file: ${job.file_path}`)
      } catch (cleanupError) {
        console.warn(`⚠️ Failed to cleanup temp file:`, cleanupError)
      }

    } catch (error) {
      console.error(`❌ Job ${jobId} failed:`, error)

      await this.updateJob(jobId, {
        status: 'failed',
        completed_at: new Date().toISOString(),
        error_message: error.message
      })

      // Clean up temporary file on error
      try {
        await fs.unlink(job.file_path)
      } catch (cleanupError) {
        // Ignore cleanup errors
      }
    }
  }

  /**
   * Add SSE client for job updates
   * @param {string} jobId - Job ID
   * @param {Response} res - Express response object
   */
  addSSEClient(jobId, res) {
    if (!sseClients.has(jobId)) {
      sseClients.set(jobId, new Set())
    }
    sseClients.get(jobId).add(res)

    console.log(`📡 SSE client connected for job ${jobId}`)

    // Remove client when connection closes
    res.on('close', () => {
      const clients = sseClients.get(jobId)
      if (clients) {
        clients.delete(res)
        if (clients.size === 0) {
          sseClients.delete(jobId)
        }
      }
      console.log(`📡 SSE client disconnected for job ${jobId}`)
    })
  }

  /**
   * Notify all SSE clients watching a job
   * @param {string} jobId - Job ID
   * @param {Object} data - Progress data to send
   */
  notifyClients(jobId, data) {
    const clients = sseClients.get(jobId)
    if (!clients || clients.size === 0) {
      return
    }

    const sseData = `data: ${JSON.stringify(data)}\n\n`

    for (const res of clients) {
      try {
        res.write(sseData)
      } catch (error) {
        console.warn(`Failed to send SSE update to client:`, error)
        clients.delete(res)
      }
    }
  }

  /**
   * Clean up old completed/failed jobs (older than 7 days)
   */
  async cleanupOldJobs() {
    const query = `
      DELETE FROM grey_mirror_jobs
      WHERE (status = 'completed' OR status = 'failed')
      AND created_at < datetime('now', '-7 days')
    `

    const result = await this.db.query(query)

    if (result.rowCount > 0) {
      console.log(`🗑️ Cleaned up ${result.rowCount} old jobs`)
    }
  }
}

// Singleton instance
let jobQueueInstance = null

function getJobQueue() {
  if (!jobQueueInstance) {
    jobQueueInstance = new GreyMirrorJobQueue()
    jobQueueInstance.startWorker()

    // Schedule cleanup every 24 hours
    setInterval(() => {
      jobQueueInstance.cleanupOldJobs()
    }, 24 * 60 * 60 * 1000)
  }
  return jobQueueInstance
}

module.exports = { getJobQueue }
