import { useContext } from 'react'
import { AuthContext } from '@/contexts/AuthContext'

/**
 * useAuth Hook
 * Provides authentication state and operations
 */

export function useAuth() {
  const context = useContext(AuthContext)

  if (!context) {
    throw new Error('useAuth must be used within AuthProvider')
  }

  return {
    // State
    user: context.user,
    isAuthenticated: context.isAuthenticated,
    isLoading: context.isLoading,
    isAuthenticating: context.isAuthenticating,
    error: context.error,
    token: context.token,

    // Methods
    login: context.login,
    signup: context.signup,
    logout: context.logout,
    updateProfile: context.updateProfile,
    clearError: context.clearError,
    setUser: context.setUser
  }
}
