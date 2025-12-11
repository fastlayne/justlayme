/**
 * LoadingContext
 * Centralized state management for loading indicators across the app
 * Handles:
 * - Character switch loading state
 * - File upload loading state and progress
 * - Analysis loading state and progress
 *
 * Prevents multiple simultaneous operations and ensures clean state transitions
 */

import { createContext, useReducer, useCallback, useContext } from 'react'

export const LoadingContext = createContext()

const initialState = {
  // Character switching
  characterSwitch: {
    isLoading: false,
    status: 'idle', // idle | loading | success | error
    character: null,
    error: null
  },

  // File upload
  fileUpload: {
    isLoading: false,
    status: 'idle', // idle | uploading | success | error
    progress: 0,
    fileName: null,
    error: null,
    fileUrl: null
  },

  // Analysis
  analysis: {
    isLoading: false,
    status: 'idle', // idle | analyzing | success | error
    progress: 0,
    stage: null, // 'processing' | 'analyzing' | 'compiling' | null
    error: null,
    analysisId: null,
    canCancel: false
  }
}

const ACTIONS = {
  // Character switch
  START_CHARACTER_SWITCH: 'START_CHARACTER_SWITCH',
  COMPLETE_CHARACTER_SWITCH: 'COMPLETE_CHARACTER_SWITCH',
  ERROR_CHARACTER_SWITCH: 'ERROR_CHARACTER_SWITCH',
  RESET_CHARACTER_SWITCH: 'RESET_CHARACTER_SWITCH',

  // File upload
  START_FILE_UPLOAD: 'START_FILE_UPLOAD',
  UPDATE_UPLOAD_PROGRESS: 'UPDATE_UPLOAD_PROGRESS',
  COMPLETE_FILE_UPLOAD: 'COMPLETE_FILE_UPLOAD',
  ERROR_FILE_UPLOAD: 'ERROR_FILE_UPLOAD',
  RESET_FILE_UPLOAD: 'RESET_FILE_UPLOAD',

  // Analysis
  START_ANALYSIS: 'START_ANALYSIS',
  UPDATE_ANALYSIS_PROGRESS: 'UPDATE_ANALYSIS_PROGRESS',
  UPDATE_ANALYSIS_STAGE: 'UPDATE_ANALYSIS_STAGE',
  COMPLETE_ANALYSIS: 'COMPLETE_ANALYSIS',
  ERROR_ANALYSIS: 'ERROR_ANALYSIS',
  CANCEL_ANALYSIS: 'CANCEL_ANALYSIS',
  RESET_ANALYSIS: 'RESET_ANALYSIS'
}

function loadingReducer(state, action) {
  switch (action.type) {
    // Character switch actions
    case ACTIONS.START_CHARACTER_SWITCH:
      return {
        ...state,
        characterSwitch: {
          isLoading: true,
          status: 'loading',
          character: action.payload,
          error: null
        }
      }

    case ACTIONS.COMPLETE_CHARACTER_SWITCH:
      return {
        ...state,
        characterSwitch: {
          isLoading: false,
          status: 'success',
          character: action.payload,
          error: null
        }
      }

    case ACTIONS.ERROR_CHARACTER_SWITCH:
      return {
        ...state,
        characterSwitch: {
          isLoading: false,
          status: 'error',
          character: state.characterSwitch.character,
          error: action.payload
        }
      }

    case ACTIONS.RESET_CHARACTER_SWITCH:
      return {
        ...state,
        characterSwitch: initialState.characterSwitch
      }

    // File upload actions
    case ACTIONS.START_FILE_UPLOAD:
      return {
        ...state,
        fileUpload: {
          isLoading: true,
          status: 'uploading',
          progress: 0,
          fileName: action.payload,
          error: null,
          fileUrl: null
        }
      }

    case ACTIONS.UPDATE_UPLOAD_PROGRESS:
      return {
        ...state,
        fileUpload: {
          ...state.fileUpload,
          progress: action.payload
        }
      }

    case ACTIONS.COMPLETE_FILE_UPLOAD:
      return {
        ...state,
        fileUpload: {
          isLoading: false,
          status: 'success',
          progress: 100,
          fileName: state.fileUpload.fileName,
          error: null,
          fileUrl: action.payload
        }
      }

    case ACTIONS.ERROR_FILE_UPLOAD:
      return {
        ...state,
        fileUpload: {
          isLoading: false,
          status: 'error',
          progress: 0,
          fileName: state.fileUpload.fileName,
          error: action.payload,
          fileUrl: null
        }
      }

    case ACTIONS.RESET_FILE_UPLOAD:
      return {
        ...state,
        fileUpload: initialState.fileUpload
      }

    // Analysis actions
    case ACTIONS.START_ANALYSIS:
      return {
        ...state,
        analysis: {
          isLoading: true,
          status: 'analyzing',
          progress: 0,
          stage: 'processing',
          error: null,
          analysisId: action.payload,
          canCancel: true
        }
      }

    case ACTIONS.UPDATE_ANALYSIS_PROGRESS:
      return {
        ...state,
        analysis: {
          ...state.analysis,
          progress: action.payload
        }
      }

    case ACTIONS.UPDATE_ANALYSIS_STAGE:
      return {
        ...state,
        analysis: {
          ...state.analysis,
          stage: action.payload
        }
      }

    case ACTIONS.COMPLETE_ANALYSIS:
      return {
        ...state,
        analysis: {
          isLoading: false,
          status: 'success',
          progress: 100,
          stage: 'complete',
          error: null,
          analysisId: state.analysis.analysisId,
          canCancel: false
        }
      }

    case ACTIONS.ERROR_ANALYSIS:
      return {
        ...state,
        analysis: {
          isLoading: false,
          status: 'error',
          progress: 0,
          stage: null,
          error: action.payload,
          analysisId: state.analysis.analysisId,
          canCancel: false
        }
      }

    case ACTIONS.CANCEL_ANALYSIS:
      return {
        ...state,
        analysis: {
          isLoading: false,
          status: 'idle',
          progress: 0,
          stage: null,
          error: null,
          analysisId: null,
          canCancel: false
        }
      }

    case ACTIONS.RESET_ANALYSIS:
      return {
        ...state,
        analysis: initialState.analysis
      }

    default:
      return state
  }
}

export function LoadingProvider({ children }) {
  const [state, dispatch] = useReducer(loadingReducer, initialState)

  // Character switch callbacks
  const startCharacterSwitch = useCallback((character) => {
    dispatch({ type: ACTIONS.START_CHARACTER_SWITCH, payload: character })
  }, [])

  const completeCharacterSwitch = useCallback((character) => {
    dispatch({ type: ACTIONS.COMPLETE_CHARACTER_SWITCH, payload: character })
  }, [])

  const errorCharacterSwitch = useCallback((error) => {
    dispatch({ type: ACTIONS.ERROR_CHARACTER_SWITCH, payload: error })
  }, [])

  const resetCharacterSwitch = useCallback(() => {
    dispatch({ type: ACTIONS.RESET_CHARACTER_SWITCH })
  }, [])

  // File upload callbacks
  const startFileUpload = useCallback((fileName) => {
    dispatch({ type: ACTIONS.START_FILE_UPLOAD, payload: fileName })
  }, [])

  const updateUploadProgress = useCallback((progress) => {
    dispatch({ type: ACTIONS.UPDATE_UPLOAD_PROGRESS, payload: progress })
  }, [])

  const completeFileUpload = useCallback((fileUrl) => {
    dispatch({ type: ACTIONS.COMPLETE_FILE_UPLOAD, payload: fileUrl })
  }, [])

  const errorFileUpload = useCallback((error) => {
    dispatch({ type: ACTIONS.ERROR_FILE_UPLOAD, payload: error })
  }, [])

  const resetFileUpload = useCallback(() => {
    dispatch({ type: ACTIONS.RESET_FILE_UPLOAD })
  }, [])

  // Analysis callbacks
  const startAnalysis = useCallback((analysisId) => {
    dispatch({ type: ACTIONS.START_ANALYSIS, payload: analysisId })
  }, [])

  const updateAnalysisProgress = useCallback((progress) => {
    dispatch({ type: ACTIONS.UPDATE_ANALYSIS_PROGRESS, payload: progress })
  }, [])

  const updateAnalysisStage = useCallback((stage) => {
    dispatch({ type: ACTIONS.UPDATE_ANALYSIS_STAGE, payload: stage })
  }, [])

  const completeAnalysis = useCallback(() => {
    dispatch({ type: ACTIONS.COMPLETE_ANALYSIS })
  }, [])

  const errorAnalysis = useCallback((error) => {
    dispatch({ type: ACTIONS.ERROR_ANALYSIS, payload: error })
  }, [])

  const cancelAnalysis = useCallback(() => {
    dispatch({ type: ACTIONS.CANCEL_ANALYSIS })
  }, [])

  const resetAnalysis = useCallback(() => {
    dispatch({ type: ACTIONS.RESET_ANALYSIS })
  }, [])

  const value = {
    // State
    characterSwitch: state.characterSwitch,
    fileUpload: state.fileUpload,
    analysis: state.analysis,

    // Character switch methods
    startCharacterSwitch,
    completeCharacterSwitch,
    errorCharacterSwitch,
    resetCharacterSwitch,

    // File upload methods
    startFileUpload,
    updateUploadProgress,
    completeFileUpload,
    errorFileUpload,
    resetFileUpload,

    // Analysis methods
    startAnalysis,
    updateAnalysisProgress,
    updateAnalysisStage,
    completeAnalysis,
    errorAnalysis,
    cancelAnalysis,
    resetAnalysis
  }

  return (
    <LoadingContext.Provider value={value}>
      {children}
    </LoadingContext.Provider>
  )
}

/**
 * Hook to use LoadingContext
 */
export function useLoading() {
  const context = useContext(LoadingContext)
  if (!context) {
    throw new Error('useLoading must be used within LoadingProvider')
  }
  return context
}
