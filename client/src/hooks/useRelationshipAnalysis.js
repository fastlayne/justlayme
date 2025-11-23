import { useContext } from 'react'
import { BlackMirrorContext } from '@/contexts/BlackMirrorContext'
import { relationshipAPI } from '@/services/relationshipAPI'

/**
 * useBlackMirror Hook
 * The Grey Mirror analysis operations and state
 */

export function useBlackMirror() {
  const context = useContext(BlackMirrorContext)

  if (!context) {
    throw new Error('useBlackMirror must be used within BlackMirrorProvider')
  }

  return {
    // State
    uploadedFile: context.uploadedFile,
    uploadMethod: context.uploadMethod,
    uploadProgress: context.uploadProgress,
    isAnalyzing: context.isAnalyzing,
    analysisId: context.analysisId,
    analysisResults: context.analysisResults,
    mlReport: context.mlReport,
    expandedMetrics: context.expandedMetrics,
    error: context.error,
    isExporting: context.isExporting,

    // Methods
    setUploadedFile: context.setUploadedFile,
    setUploadProgress: context.setUploadProgress,
    setAnalyzing: context.setAnalyzing,
    setAnalysisId: context.setAnalysisId,
    setAnalysisResults: context.setAnalysisResults,
    setMLReport: context.setMLReport,
    toggleMetricExpanded: context.toggleMetricExpanded,
    expandMetric: context.expandMetric,
    collapseMetric: context.collapseMetric,
    collapseAllMetrics: context.collapseAllMetrics,
    setError: context.setError,
    clearError: context.clearError,
    clearResults: context.clearResults,

    // API Wrappers
    uploadAndAnalyze: async (data, method = 'paste') => {
      context.setUploadedFile(data, method)
      context.setAnalyzing(true)
      context.clearError()

      // Clean up any existing polling before starting new one
      if (context._pollCleanup) {
        context._pollCleanup()
        context._pollCleanup = null
      }

      try {
        const response = await relationshipAPI.uploadAndAnalyze(data, method)
        context.setAnalysisId(response.analysisId)

        // Start streaming progress or polling
        if (response.analysisId) {
          return await context.pollAnalysisProgress(response.analysisId)
        }

        return response
      } catch (error) {
        context.setError(error.message)
        context.setAnalyzing(false)
        throw error
      }
    },

    pollAnalysisProgress: async (analysisId) => {
      const maxAttempts = 120 // 2 minutes with 1 second intervals
      let attempts = 0
      let isMounted = true // Track if component is still mounted
      let pollInterval = null

      return new Promise((resolve, reject) => {
        // Setup cleanup function that will be called on unmount or completion
        const cleanup = () => {
          isMounted = false
          if (pollInterval) {
            clearInterval(pollInterval)
            pollInterval = null
          }
        }

        pollInterval = setInterval(async () => {
          // Check if component is still mounted before proceeding
          if (!isMounted) {
            cleanup()
            reject(new Error('Component unmounted during polling'))
            return
          }

          attempts++

          try {
            const progress = await relationshipAPI.getAnalysisProgress(analysisId)

            // Check again after async operation
            if (!isMounted) {
              cleanup()
              reject(new Error('Component unmounted during polling'))
              return
            }

            if (progress.status === 'completed') {
              const results = await relationshipAPI.getResults(analysisId)

              // Final check before state updates
              if (isMounted) {
                context.setAnalysisResults(results)
                context.setAnalyzing(false)
              }

              cleanup()
              resolve(results)
            } else if (progress.status === 'error') {
              if (isMounted) {
                context.setError('Analysis failed. Please try again.')
                context.setAnalyzing(false)
              }
              cleanup()
              reject(new Error('Analysis failed'))
            } else {
              // Update progress only if still mounted
              if (isMounted) {
                context.setUploadProgress(progress.progress || 0)
              }
            }

            if (attempts >= maxAttempts) {
              if (isMounted) {
                context.setError('Analysis timed out. Please try again.')
                context.setAnalyzing(false)
              }
              cleanup()
              reject(new Error('Timeout'))
            }
          } catch (error) {
            if (isMounted) {
              context.setError(error.message)
              context.setAnalyzing(false)
            }
            cleanup()
            reject(error)
          }
        }, 1000)

        // Ensure cleanup happens on promise rejection/resolution
        // This is critical for preventing memory leaks
        Promise.resolve().then(() => {
          // Store cleanup function in closure for external access if needed
          context._pollCleanup = cleanup
        })
      })
    },

    processScreenshot: async (imageFile) => {
      try {
        const result = await relationshipAPI.processScreenshot(imageFile)
        return result.text
      } catch (error) {
        context.setError(error.message)
        throw error
      }
    },

    exportResults: async (format = 'pdf') => {
      if (!context.analysisId) {
        throw new Error('No analysis to export')
      }

      context.setExporting(true)

      try {
        const blob = await relationshipAPI.exportResults(context.analysisId, format)

        // Trigger download
        const url = window.URL.createObjectURL(blob)
        const link = document.createElement('a')
        link.href = url
        link.download = `relationship-analysis.${format}`
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
        window.URL.revokeObjectURL(url)

        return blob
      } catch (error) {
        context.setError(error.message)
        throw error
      } finally {
        context.setExporting(false)
      }
    },

    // Cleanup method to be called on component unmount
    cleanup: () => {
      if (context._pollCleanup) {
        context._pollCleanup()
        context._pollCleanup = null
      }
    }
  }
}
