import { createContext, useReducer, useCallback } from 'react'

/**
 * GreyMirror Context
 * Manages The Grey Mirror analysis state:
 * - File upload and processing
 * - ML analysis execution
 * - Analysis results from ML orchestrator
 * - Expanded metrics
 */

export const BlackMirrorContext = createContext()

const initialState = {
  uploadedFile: null,
  uploadMethod: null,
  uploadProgress: 0,
  isAnalyzing: false,
  analysisId: null,
  analysisResults: null,
  mlReport: null,
  expandedMetrics: [],
  error: null,
  exportFormat: null,
  isExporting: false,
  // Personalization data for customized analysis
  personalization: {
    userName: 'You',
    contactName: 'Them',
    insightsGoal: '',
  }
}

const ACTIONS = {
  SET_UPLOADED_FILE: 'SET_UPLOADED_FILE',
  SET_UPLOAD_PROGRESS: 'SET_UPLOAD_PROGRESS',
  SET_ANALYZING: 'SET_ANALYZING',
  SET_ANALYSIS_ID: 'SET_ANALYSIS_ID',
  SET_ANALYSIS_RESULTS: 'SET_ANALYSIS_RESULTS',
  SET_ML_REPORT: 'SET_ML_REPORT',
  TOGGLE_METRIC_EXPANDED: 'TOGGLE_METRIC_EXPANDED',
  EXPAND_METRIC: 'EXPAND_METRIC',
  COLLAPSE_METRIC: 'COLLAPSE_METRIC',
  COLLAPSE_ALL_METRICS: 'COLLAPSE_ALL_METRICS',
  SET_ERROR: 'SET_ERROR',
  CLEAR_ERROR: 'CLEAR_ERROR',
  SET_EXPORTING: 'SET_EXPORTING',
  CLEAR_RESULTS: 'CLEAR_RESULTS',
  SET_PERSONALIZATION: 'SET_PERSONALIZATION'
}

function blackMirrorReducer(state, action) {
  switch (action.type) {
    case ACTIONS.SET_UPLOADED_FILE:
      return {
        ...state,
        uploadedFile: action.payload.file,
        uploadMethod: action.payload.method,
        uploadProgress: 0
      }

    case ACTIONS.SET_UPLOAD_PROGRESS:
      return { ...state, uploadProgress: action.payload }

    case ACTIONS.SET_ANALYZING:
      return { ...state, isAnalyzing: action.payload }

    case ACTIONS.SET_ANALYSIS_ID:
      return { ...state, analysisId: action.payload }

    case ACTIONS.SET_ANALYSIS_RESULTS:
      return {
        ...state,
        analysisResults: action.payload,
        isAnalyzing: false,
        error: null
      }

    case ACTIONS.SET_ML_REPORT:
      return {
        ...state,
        mlReport: action.payload,
        isAnalyzing: false,
        error: null
      }

    case ACTIONS.TOGGLE_METRIC_EXPANDED:
      // ARCHITECTURAL FIX: Ensure expandedMetrics is always an array
      const currentExpanded = Array.isArray(state.expandedMetrics) ? state.expandedMetrics : []
      return {
        ...state,
        expandedMetrics: currentExpanded.includes(action.payload)
          ? currentExpanded.filter((m) => m !== action.payload)
          : [...currentExpanded, action.payload]
      }

    case ACTIONS.EXPAND_METRIC:
      // ARCHITECTURAL FIX: Ensure expandedMetrics is always an array
      const expanded = Array.isArray(state.expandedMetrics) ? state.expandedMetrics : []
      return {
        ...state,
        expandedMetrics: expanded.includes(action.payload)
          ? expanded
          : [...expanded, action.payload]
      }

    case ACTIONS.COLLAPSE_METRIC:
      // ARCHITECTURAL FIX: Ensure expandedMetrics is always an array
      const collapsed = Array.isArray(state.expandedMetrics) ? state.expandedMetrics : []
      return {
        ...state,
        expandedMetrics: collapsed.filter((m) => m !== action.payload)
      }

    case ACTIONS.COLLAPSE_ALL_METRICS:
      return { ...state, expandedMetrics: [] }

    case ACTIONS.SET_ERROR:
      return { ...state, error: action.payload, isAnalyzing: false }

    case ACTIONS.CLEAR_ERROR:
      return { ...state, error: null }

    case ACTIONS.SET_EXPORTING:
      return { ...state, isExporting: action.payload }

    case ACTIONS.CLEAR_RESULTS:
      return {
        ...state,
        uploadedFile: null,
        uploadMethod: null,
        uploadProgress: 0,
        analysisId: null,
        analysisResults: null,
        expandedMetrics: [],
        error: null
      }

    case ACTIONS.SET_PERSONALIZATION:
      return {
        ...state,
        personalization: {
          ...state.personalization,
          ...action.payload
        }
      }

    default:
      return state
  }
}

export function BlackMirrorProvider({ children }) {
  const [state, dispatch] = useReducer(blackMirrorReducer, initialState)

  const setUploadedFile = useCallback((file, method) => {
    dispatch({
      type: ACTIONS.SET_UPLOADED_FILE,
      payload: { file, method }
    })
  }, [])

  const setUploadProgress = useCallback((progress) => {
    dispatch({ type: ACTIONS.SET_UPLOAD_PROGRESS, payload: progress })
  }, [])

  const setAnalyzing = useCallback((analyzing) => {
    dispatch({ type: ACTIONS.SET_ANALYZING, payload: analyzing })
  }, [])

  const setAnalysisId = useCallback((id) => {
    dispatch({ type: ACTIONS.SET_ANALYSIS_ID, payload: id })
  }, [])

  const setAnalysisResults = useCallback((results) => {
    dispatch({ type: ACTIONS.SET_ANALYSIS_RESULTS, payload: results })
  }, [])

  const setMLReport = useCallback((report) => {
    dispatch({ type: ACTIONS.SET_ML_REPORT, payload: report })
  }, [])

  const toggleMetricExpanded = useCallback((metricId) => {
    dispatch({ type: ACTIONS.TOGGLE_METRIC_EXPANDED, payload: metricId })
  }, [])

  const expandMetric = useCallback((metricId) => {
    dispatch({ type: ACTIONS.EXPAND_METRIC, payload: metricId })
  }, [])

  const collapseMetric = useCallback((metricId) => {
    dispatch({ type: ACTIONS.COLLAPSE_METRIC, payload: metricId })
  }, [])

  const collapseAllMetrics = useCallback(() => {
    dispatch({ type: ACTIONS.COLLAPSE_ALL_METRICS })
  }, [])

  const setError = useCallback((error) => {
    dispatch({ type: ACTIONS.SET_ERROR, payload: error })
  }, [])

  const clearError = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_ERROR })
  }, [])

  const setExporting = useCallback((exporting) => {
    dispatch({ type: ACTIONS.SET_EXPORTING, payload: exporting })
  }, [])

  const clearResults = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_RESULTS })
  }, [])

  const setPersonalization = useCallback((data) => {
    dispatch({ type: ACTIONS.SET_PERSONALIZATION, payload: data })
  }, [])

  const value = {
    // State
    ...state,

    // Methods
    setUploadedFile,
    setUploadProgress,
    setAnalyzing,
    setAnalysisId,
    setAnalysisResults,
    setMLReport,
    toggleMetricExpanded,
    expandMetric,
    collapseMetric,
    collapseAllMetrics,
    setError,
    clearError,
    setExporting,
    clearResults,
    setPersonalization
  }

  return (
    <BlackMirrorContext.Provider value={value}>{children}</BlackMirrorContext.Provider>
  )
}
