import apiClient from './client'

/**
 * RelationshipX API Service
 * Handles relationship analysis operations:
 * - Upload conversation data
 * - Process screenshots with OCR
 * - Get analysis progress and results
 * - Export results
 */

export const relationshipAPI = {
  /**
   * Upload and analyze conversation data
   * Accepts text, file, or screenshot upload
   * @param {string | File} data - Text data or File object
   * @param {string} method - 'paste' | 'file' | 'screenshot'
   * @returns {Promise<{analysisId: string, status: string}>}
   */
  uploadAndAnalyze: async (data, method = 'paste') => {
    try {
      if (method === 'file' || method === 'screenshot') {
        // File upload
        const formData = new FormData()
        formData.append('file', data)
        formData.append('method', method)
        formData.append('timestamp', new Date().toISOString())

        return await apiClient.post('relationship/analyze', formData, {
          headers: {
            'Content-Type': 'multipart/form-data'
          },
          onUploadProgress: (progressEvent) => {
            const percentCompleted = Math.round(
              (progressEvent.loaded * 100) / progressEvent.total
            )
          }
        })
      } else {
        // Text paste
        return await apiClient.post('relationship/analyze', {
          data,
          method,
          timestamp: new Date().toISOString()
        })
      }
    } catch (error) {
      console.error('Failed to upload and analyze:', error)
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
