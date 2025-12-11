/**
 * ErrorContext
 * Centralized error handling and recovery for async operations
 * Handles:
 * - Error display and user-visible messages
 * - Error boundaries and graceful degradation
 * - Retry mechanisms for failed operations
 * - Specific error type categorization
 */

import { createContext, useReducer, useCallback, useContext } from 'react'

export const ErrorContext = createContext()

const initialState = {
  errors: {}, // { errorId: { message, type, code, timestamp, canRetry, retryCount } }
  activeErrorId: null,
  globalError: null,
  retryRegistry: {} // { errorId: { retryFn, maxRetries, currentRetry } }
}

const ACTIONS = {
  ADD_ERROR: 'ADD_ERROR',
  CLEAR_ERROR: 'CLEAR_ERROR',
  CLEAR_ALL_ERRORS: 'CLEAR_ALL_ERRORS',
  SET_ACTIVE_ERROR: 'SET_ACTIVE_ERROR',
  RETRY_ERROR: 'RETRY_ERROR',
  MARK_ERROR_RESOLVED: 'MARK_ERROR_RESOLVED',
  SET_GLOBAL_ERROR: 'SET_GLOBAL_ERROR',
  CLEAR_GLOBAL_ERROR: 'CLEAR_GLOBAL_ERROR',
  REGISTER_RETRY: 'REGISTER_RETRY'
}

function errorReducer(state, action) {
  switch (action.type) {
    case ACTIONS.ADD_ERROR:
      const errorId = action.payload.id || `error_${Date.now()}`
      return {
        ...state,
        errors: {
          ...state.errors,
          [errorId]: {
            message: action.payload.message,
            type: action.payload.type || 'ERROR',
            code: action.payload.code || null,
            timestamp: Date.now(),
            canRetry: action.payload.canRetry || false,
            retryCount: 0,
            context: action.payload.context || {}
          }
        },
        activeErrorId: errorId
      }

    case ACTIONS.CLEAR_ERROR:
      const { [action.payload]: removed, ...remainingErrors } = state.errors
      return {
        ...state,
        errors: remainingErrors,
        activeErrorId: action.payload === state.activeErrorId ? null : state.activeErrorId
      }

    case ACTIONS.CLEAR_ALL_ERRORS:
      return {
        ...state,
        errors: {},
        activeErrorId: null
      }

    case ACTIONS.SET_ACTIVE_ERROR:
      return {
        ...state,
        activeErrorId: action.payload
      }

    case ACTIONS.RETRY_ERROR:
      const currentError = state.errors[action.payload]
      if (!currentError) return state
      return {
        ...state,
        errors: {
          ...state.errors,
          [action.payload]: {
            ...currentError,
            retryCount: currentError.retryCount + 1
          }
        }
      }

    case ACTIONS.MARK_ERROR_RESOLVED:
      return {
        ...state,
        errors: {
          ...state.errors,
          [action.payload]: {
            ...state.errors[action.payload],
            resolved: true
          }
        }
      }

    case ACTIONS.SET_GLOBAL_ERROR:
      return {
        ...state,
        globalError: {
          message: action.payload.message,
          type: action.payload.type || 'CRITICAL_ERROR',
          timestamp: Date.now()
        }
      }

    case ACTIONS.CLEAR_GLOBAL_ERROR:
      return {
        ...state,
        globalError: null
      }

    case ACTIONS.REGISTER_RETRY:
      return {
        ...state,
        retryRegistry: {
          ...state.retryRegistry,
          [action.payload.errorId]: {
            retryFn: action.payload.retryFn,
            maxRetries: action.payload.maxRetries || 3,
            currentRetry: 0
          }
        }
      }

    default:
      return state
  }
}

export function ErrorProvider({ children }) {
  const [state, dispatch] = useReducer(errorReducer, initialState)

  const addError = useCallback((message, type = 'ERROR', options = {}) => {
    const errorPayload = {
      id: options.id,
      message,
      type,
      code: options.code,
      canRetry: options.canRetry || false,
      context: options.context || {}
    }
    dispatch({ type: ACTIONS.ADD_ERROR, payload: errorPayload })
    return options.id || `error_${Date.now()}`
  }, [])

  const clearError = useCallback((errorId) => {
    dispatch({ type: ACTIONS.CLEAR_ERROR, payload: errorId })
  }, [])

  const clearAllErrors = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_ALL_ERRORS })
  }, [])

  const setActiveError = useCallback((errorId) => {
    dispatch({ type: ACTIONS.SET_ACTIVE_ERROR, payload: errorId })
  }, [])

  const retryError = useCallback(async (errorId) => {
    dispatch({ type: ACTIONS.RETRY_ERROR, payload: errorId })

    const retryInfo = state.retryRegistry[errorId]
    if (!retryInfo) return

    try {
      await retryInfo.retryFn()
      clearError(errorId)
    } catch (error) {
      // Error already registered, just increment retry count
      if (retryInfo.currentRetry < retryInfo.maxRetries) {
        retryInfo.currentRetry++
      } else {
        // Max retries reached - update error
        addError(
          `Operation failed after ${retryInfo.maxRetries} retries`,
          'RETRY_EXHAUSTED'
        )
      }
    }
  }, [state.retryRegistry, clearError, addError])

  const markErrorResolved = useCallback((errorId) => {
    dispatch({ type: ACTIONS.MARK_ERROR_RESOLVED, payload: errorId })
  }, [])

  const setGlobalError = useCallback((message, type = 'CRITICAL_ERROR') => {
    dispatch({
      type: ACTIONS.SET_GLOBAL_ERROR,
      payload: { message, type }
    })
  }, [])

  const clearGlobalError = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_GLOBAL_ERROR })
  }, [])

  const registerRetry = useCallback((errorId, retryFn, maxRetries = 3) => {
    dispatch({
      type: ACTIONS.REGISTER_RETRY,
      payload: { errorId, retryFn, maxRetries }
    })
  }, [])

  const value = {
    // State
    errors: state.errors,
    activeErrorId: state.activeErrorId,
    globalError: state.globalError,
    retryRegistry: state.retryRegistry,

    // Methods
    addError,
    clearError,
    clearAllErrors,
    setActiveError,
    retryError,
    markErrorResolved,
    setGlobalError,
    clearGlobalError,
    registerRetry,

    // Helpers
    hasErrors: () => Object.keys(state.errors).length > 0,
    getActiveError: () => state.activeErrorId ? state.errors[state.activeErrorId] : null,
    canRetryError: (errorId) => state.errors[errorId]?.canRetry || false
  }

  return (
    <ErrorContext.Provider value={value}>
      {children}
    </ErrorContext.Provider>
  )
}

export function useError() {
  const context = useContext(ErrorContext)
  if (!context) {
    throw new Error('useError must be used within ErrorProvider')
  }
  return context
}
