import apiClient from './client'
import { parseConversationData } from './ml/messageParser'

/**
 * RelationshipX API Service
 * Handles relationship analysis operations with frontend message parsing
 *
 * ARCHITECTURE:
 * 1. Parse messages on frontend (fast, no timeout)
 * 2. Send parsed messages to Node.js backend
 * 3. Node.js forwards to Python ML service
 * 4. Python runs 22 analyzers and returns results
 */

export const relationshipAPI = {
  /**
   * Upload file for async analysis (supports 100K+ messages)
   * Use this for large files to avoid Cloudflare timeout
   * @param {File} file - File object
   * @param {object} personalization - User/contact names and insights goal
   * @returns {Promise<{jobId: string, estimatedTime: string}>}
   */
  uploadAsync: async (file, personalization = {}) => {
    try {
      if (!(file instanceof File)) {
        throw new Error('uploadAsync requires a File object')
      }

      console.log(`📤 Async upload: ${file.name} (${file.size} bytes)`)

      const formData = new FormData()
      formData.append('file', file)
      formData.append('userName', personalization.userName || 'You')
      formData.append('contactName', personalization.contactName || 'Them')
      formData.append('insightsGoal', personalization.insightsGoal || '')

      const response = await apiClient.post('/grey-mirror/upload-async', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        },
        timeout: 300000, // 5 minutes for large file uploads (handles slow connections)
        onUploadProgress: (progressEvent) => {
          const percentCompleted = Math.round((progressEvent.loaded * 100) / progressEvent.total)
          console.log(`📊 Upload progress: ${percentCompleted}%`)
        }
      })

      console.log(`✅ Job created: ${response.data.jobId}`)
      return response.data

    } catch (error) {
      console.error('❌ Failed to upload async:', error)
      throw error
    }
  },

  /**
   * Get job status and results
   * @param {string} jobId - Job ID from uploadAsync
   * @returns {Promise<JobStatus>}
   */
  getJobStatus: async (jobId) => {
    try {
      const response = await apiClient.get(`/grey-mirror/job/${jobId}`)
      return response.data
    } catch (error) {
      console.error('❌ Failed to get job status:', error)
      throw error
    }
  },

  /**
   * Stream job progress updates with SSE
   * @param {string} jobId - Job ID from uploadAsync
   * @param {Function} onProgress - Callback(data) for progress updates
   * @param {Function} onComplete - Callback() when job completes
   * @param {Function} onError - Callback(error) on error
   * @returns {EventSource}
   */
  streamJobProgress: (jobId, onProgress, onComplete, onError) => {
    try {
      const token = localStorage.getItem('authToken')
      const baseURL = import.meta.env.VITE_API_BASE_URL || '/api'
      const eventSource = new EventSource(
        `${baseURL}/grey-mirror/job/${jobId}/stream?token=${token}`
      )

      eventSource.onmessage = (event) => {
        const data = JSON.parse(event.data)

        if (data.done) {
          eventSource.close()
          if (onComplete) onComplete()
        } else if (onProgress) {
          onProgress(data)
        }
      }

      eventSource.onerror = (error) => {
        console.error('SSE stream error:', error)
        eventSource.close()
        if (onError) onError(error)
      }

      return eventSource
    } catch (error) {
      console.error('Failed to start SSE stream:', error)
      if (onError) onError(error)
      throw error
    }
  },

  /**
   * Poll for job status until complete
   * Alternative to SSE for browsers that don't support it
   * @param {string} jobId - Job ID from uploadAsync
   * @param {Function} onProgress - Callback(data) for progress updates
   * @param {number} intervalMs - Polling interval (default 2000ms)
   * @returns {Promise<JobResults>}
   */
  pollJobStatus: async (jobId, onProgress, intervalMs = 2000) => {
    return new Promise((resolve, reject) => {
      const poll = async () => {
        try {
          const status = await relationshipAPI.getJobStatus(jobId)

          if (onProgress) {
            onProgress({
              progress: status.progress,
              message: status.message,
              status: status.status
            })
          }

          if (status.status === 'completed') {
            clearInterval(intervalId)
            // Include messageCount in results
            const results = status.results || {}
            results.messageCount = status.messageCount
            resolve(results)
          } else if (status.status === 'failed') {
            clearInterval(intervalId)
            reject(new Error(status.error || 'Analysis failed'))
          }
        } catch (error) {
          clearInterval(intervalId)
          reject(error)
        }
      }

      const intervalId = setInterval(poll, intervalMs)
      poll() // Start immediately
    })
  },

  /**
   * Upload and analyze conversation data (LEGACY - use uploadAsync for large files)
   * Parses messages on frontend then sends to ML service
   * ⚠️ Subject to Cloudflare 100s timeout for large files
   * @param {string | File} data - Text data or File object
   * @param {string} method - 'paste' | 'file' | 'screenshot'
   * @param {object} personalization - User/contact names and insights goal
   * @returns {Promise<AnalysisResponse>}
   */
  uploadAndAnalyze: async (data, method = 'paste', personalization = {}) => {
    try {
      let fileContent = data

      // Read file content if it's a File object
      if (method === 'file' && data instanceof File) {
        console.log(`📂 Reading file: ${data.name} (${data.size} bytes)`)
        fileContent = await readFileAsText(data)
        console.log(`✅ File read successfully, content length: ${fileContent.length}`)
      }

      // Parse messages on frontend using existing parser
      console.log(`🔄 Parsing messages on frontend...`)
      const messages = parseConversationData(fileContent, method)

      if (!messages || messages.length === 0) {
        throw new Error('No messages could be parsed from the file. Please check the format.')
      }

      console.log(`✅ Parsed ${messages.length} messages`)

      // Send parsed messages directly to ML service
      console.log(`🧠 Sending ${messages.length} messages to ML service...`)
      const response = await apiClient.post('/grey-mirror/analyze-advanced', {
        messages,
        personalization: {
          userName: personalization.userName || 'You',
          contactName: personalization.contactName || 'Them',
          insightsGoal: personalization.insightsGoal || ''
        }
      }, {
        timeout: 300000 // 5 minutes for ML analysis
      })

      console.log(`✅ Analysis complete!`)
      return response

    } catch (error) {
      console.error('❌ Failed to upload and analyze:', error)
      throw error
    }
  },

  /**
   * Process screenshot image with OCR
   * Extracts text from conversation screenshots
   * @param {File} imageFile - Image file (jpg, png, etc)
   * @returns {Promise<{text: string, confidence: number}>}
   */
  processScreenshot: async (imageFile) => {
    try {
      const formData = new FormData()
      formData.append('image', imageFile)
      formData.append('timestamp', new Date().toISOString())

      return await apiClient.post('relationship/ocr', formData, {
        headers: {
          'Content-Type': 'multipart/form-data'
        }
      })
    } catch (error) {
      console.error('Failed to process screenshot:', error)
      throw error
    }
  },

  /**
   * Get analysis progress
   * Check how far along the analysis is processing
   * @param {string} analysisId
   * @returns {Promise<{progress: number, status: string, estimatedTime: number}>}
   */
  getAnalysisProgress: async (analysisId) => {
    try {
      return await apiClient.get(`/relationship/progress/${analysisId}`)
    } catch (error) {
      console.error('Failed to get analysis progress:', error)
      throw error
    }
  },

  /**
   * Get analysis results
   * Retrieves completed analysis with all metrics
   * @param {string} analysisId
   * @returns {Promise<AnalysisResults>}
   */
  getResults: async (analysisId) => {
    try {
      return await apiClient.get(`/relationship/results/${analysisId}`)
    } catch (error) {
      console.error('Failed to get analysis results:', error)
      throw error
    }
  },

  /**
   * Export analysis results
   * Generate downloadable report (PDF, CSV, JSON)
   * @param {string} analysisId
   * @param {string} format - 'pdf' | 'csv' | 'json'
   * @returns {Promise<Blob>}
   */
  exportResults: async (analysisId, format = 'pdf') => {
    try {
      return await apiClient.get(
        `/relationship/export/${analysisId}`,
        {
          params: { format },
          responseType: 'blob'
        }
      )
    } catch (error) {
      console.error('Failed to export results:', error)
      throw error
    }
  },

  /**
   * Stream analysis progress with SSE
   * For real-time progress updates during analysis
   * @param {string} analysisId
   * @param {Function} onProgress - Callback for progress updates
   * @returns {EventSource}
   */
  streamAnalysisProgress: (analysisId, onProgress) => {
    try {
      const token = localStorage.getItem('authToken')
      const eventSource = new EventSource(
        `${import.meta.env.VITE_API_BASE_URL || '/api'}/relationship/stream/${analysisId}?token=${token}`
      )

      eventSource.onmessage = (event) => {
        const data = JSON.parse(event.data)
        onProgress(data)
      }

      eventSource.onerror = (error) => {
        console.error('Stream error:', error)
        eventSource.close()
      }

      return eventSource
    } catch (error) {
      console.error('Failed to stream analysis progress:', error)
      throw error
    }
  }
}

/**
 * Helper: Read File object as text
 * @param {File} file - File object to read
 * @returns {Promise<string>} File contents as text
 */
function readFileAsText(file) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = (e) => resolve(e.target.result)
    reader.onerror = (e) => reject(new Error('Failed to read file'))
    reader.readAsText(file)
  })
}
