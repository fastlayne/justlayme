import { createContext, useReducer, useEffect, useCallback } from 'react'
import { authAPI } from '@/services/authAPI'

/**
 * Auth Context
 * Manages user authentication state and operations
 * Handles login, signup, logout, and token management
 */

export const AuthContext = createContext()

// Initial state
const initialState = {
  user: null,
  isAuthenticated: false,
  isLoading: true,
  isAuthenticating: false,
  error: null,
  token: null,
  refreshToken: null
}

// Action types
const ACTIONS = {
  SET_LOADING: 'SET_LOADING',
  SET_AUTHENTICATING: 'SET_AUTHENTICATING',
  LOGIN_SUCCESS: 'LOGIN_SUCCESS',
  SIGNUP_SUCCESS: 'SIGNUP_SUCCESS',
  LOGOUT: 'LOGOUT',
  SET_USER: 'SET_USER',
  SET_ERROR: 'SET_ERROR',
  CLEAR_ERROR: 'CLEAR_ERROR',
  TOKEN_REFRESH: 'TOKEN_REFRESH'
}

// Reducer
function authReducer(state, action) {
  switch (action.type) {
    case ACTIONS.SET_LOADING:
      return { ...state, isLoading: action.payload }

    case ACTIONS.SET_AUTHENTICATING:
      return { ...state, isAuthenticating: action.payload, error: null }

    case ACTIONS.LOGIN_SUCCESS:
    case ACTIONS.SIGNUP_SUCCESS:
      return {
        ...state,
        user: action.payload.user,
        isAuthenticated: true,
        token: action.payload.token,
        refreshToken: action.payload.refreshToken,
        isAuthenticating: false,
        error: null,
        isLoading: false
      }

    case ACTIONS.LOGOUT:
      return {
        ...state,
        user: null,
        isAuthenticated: false,
        token: null,
        refreshToken: null,
        error: null
      }

    case ACTIONS.SET_USER:
      return {
        ...state,
        user: action.payload,
        isAuthenticated: !!action.payload,
        isLoading: false
      }

    case ACTIONS.SET_ERROR:
      return { ...state, error: action.payload, isAuthenticating: false }

    case ACTIONS.CLEAR_ERROR:
      return { ...state, error: null }

    case ACTIONS.TOKEN_REFRESH:
      return {
        ...state,
        token: action.payload.token,
        refreshToken: action.payload.refreshToken
      }

    default:
      return state
  }
}

/**
 * Auth Provider Component
 * Wraps the app and provides authentication context
 */
export function AuthProvider({ children }) {
  const [state, dispatch] = useReducer(authReducer, initialState)

  // Initialize auth on mount - check if user is already logged in
  // ARCHITECTURAL FIX: Now uses httpOnly cookies instead of localStorage
  // Always try to get current user - cookie is sent automatically
  useEffect(() => {
    const initializeAuth = async () => {
      try {
        dispatch({ type: ACTIONS.SET_LOADING, payload: true })
        const user = await authAPI.getCurrentUser()

        // ARCHITECTURAL FIX: Verify user object is valid
        if (!user || !user.id) {
          throw new Error('Invalid user data received')
        }

        dispatch({
          type: ACTIONS.SET_USER,
          payload: user
        })
      } catch (error) {
        console.error('Failed to restore auth:', error)
        // Clear invalid session
        authAPI.logout()
        dispatch({ type: ACTIONS.LOGOUT })
      } finally {
        // ARCHITECTURAL FIX: Ensure loading state is always reset
        dispatch({ type: ACTIONS.SET_LOADING, payload: false })
      }
    }

    initializeAuth()
  }, [])

  // Login function
  const login = useCallback(async (email, password) => {
    dispatch({ type: ACTIONS.SET_AUTHENTICATING, payload: true })
    try {
      const response = await authAPI.login(email, password);
      if (!response.user || !response.user.id) {
        throw new Error('Invalid user data received from login');
      }
      dispatch({
        type: ACTIONS.LOGIN_SUCCESS,
        payload: response
      })
      return response.user
    } catch (error) {
      dispatch({
        type: ACTIONS.SET_ERROR,
        payload: error.message || 'Login failed'
      })
      throw error
    }
  }, [])

  // Signup function
  const signup = useCallback(async (email, password, name) => {
    dispatch({ type: ACTIONS.SET_AUTHENTICATING, payload: true })
    try {
      const response = await authAPI.signup(email, password, name);
       if (!response.user || !response.user.id) {
        throw new Error('Invalid user data received from signup');
      }
      dispatch({
        type: ACTIONS.SIGNUP_SUCCESS,
        payload: response
      })
      return response.user
    } catch (error) {
      dispatch({
        type: ACTIONS.SET_ERROR,
        payload: error.message || 'Signup failed'
      })
      throw error
    }
  }, [])

  // Logout function
  const logout = useCallback(() => {
    authAPI.logout()
    dispatch({ type: ACTIONS.LOGOUT })
  }, [])

  // Update user profile
  const updateProfile = useCallback(async (updates) => {
    try {
      const updatedUser = await authAPI.updateProfile(updates)
      dispatch({
        type: ACTIONS.SET_USER,
        payload: updatedUser
      })
      return updatedUser
    } catch (error) {
      dispatch({
        type: ACTIONS.SET_ERROR,
        payload: error.message || 'Profile update failed'
      })
      throw error
    }
  }, [])

  // Clear error message
  const clearError = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_ERROR })
  }, [])

  // Set user directly (for OAuth flows)
  const setUser = useCallback((user) => {
    dispatch({
      type: ACTIONS.SET_USER,
      payload: user
    })
  }, [])

  const value = {
    // State
    user: state.user,
    isAuthenticated: state.isAuthenticated,
    isLoading: state.isLoading,
    isAuthenticating: state.isAuthenticating,
    error: state.error,
    token: state.token,

    // Methods
    login,
    signup,
    logout,
    updateProfile,
    clearError,
    setUser
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
