import apiClient, { initializeTokenRefresh } from './client'

/**
 * Auth API Service
 * Handles user authentication and authorization:
 * - Login/Signup
 * - Token management
 * - User profile
 * FIX 15: Token refresh interceptor setup and automatic refresh
 */

export const authAPI = {
  /**
   * User login
   * @param {string} email
   * @param {string} password
   * @returns {Promise<{user: User, token: string}>}
   */
  login: async (email, password) => {
    try {
      const response = await apiClient.post('/login', {
        email,
        password
      })

      // Store tokens in localStorage
      if (response.token) {
        localStorage.setItem('authToken', response.token)
      }
      // Backend doesn't provide refreshToken, but that's ok for now
      if (response.refreshToken) {
        localStorage.setItem('refreshToken', response.refreshToken)
      }

      // FIX 15: Initialize token refresh interceptor on successful login
      initializeTokenRefresh(authAPI.refreshToken)

      return response
    } catch (error) {
      console.error('Login failed:', error)
      throw error
    }
  },

  /**
   * User signup/registration
   * @param {string} email
   * @param {string} password
   * @param {string} name
   * @returns {Promise<{user: User, token: string}>}
   */
  signup: async (email, password, name) => {
    try {
      const response = await apiClient.post('/register', {
        email,
        password,
        username: name || email.split('@')[0] // Backend expects username, not name
      })

      // Store tokens in localStorage
      if (response.token) {
        localStorage.setItem('authToken', response.token)
      }
      if (response.refreshToken) {
        localStorage.setItem('refreshToken', response.refreshToken)
      }

      // FIX 15: Initialize token refresh interceptor on successful signup
      initializeTokenRefresh(authAPI.refreshToken)

      return response
    } catch (error) {
      console.error('Signup failed:', error)
      throw error
    }
  },

  /**
   * Refresh authentication token
   * Called when token is about to expire
   * @returns {Promise<{token: string, refreshToken: string}>}
   */
  refreshToken: async () => {
    try {
      const refreshToken = localStorage.getItem('refreshToken')
      if (!refreshToken) {
        throw new Error('No refresh token available')
      }

      const response = await apiClient.post('/auth/refresh', {
        refreshToken
      })

      // Update tokens
      if (response.token) {
        localStorage.setItem('authToken', response.token)
      }
      if (response.refreshToken) {
        localStorage.setItem('refreshToken', response.refreshToken)
      }

      return response
    } catch (error) {
      console.error('Token refresh failed:', error)
      // If refresh fails, clear tokens and redirect to login
      authAPI.logout()
      throw error
    }
  },

  /**
   * Logout user
   * SECURITY: Calls server-side logout to clear httpOnly cookie
   * Also clears client-side tokens
   */
  logout: async () => {
    try {
      // Call server-side logout to clear httpOnly cookie
      await apiClient.post('/logout')
    } catch (error) {
      console.error('Server logout failed:', error)
      // Continue with client-side cleanup even if server call fails
    } finally {
      // Clear client-side tokens
      localStorage.removeItem('authToken')
      localStorage.removeItem('refreshToken')
    }
  },

  /**
   * Get current user profile
   * Extracts user info from the JWT token stored in localStorage
   * @returns {Promise<User>}
   */
  getCurrentUser: async () => {
    try {
      const token = localStorage.getItem('authToken')
      if (!token) {
        throw new Error('No auth token found')
      }

      // Decode JWT token (format: header.payload.signature)
      const parts = token.split('.')
      if (parts.length !== 3) {
        throw new Error('Invalid token format')
      }

      // Decode the payload (add padding if necessary)
      const payload = parts[1]
      const padded = payload + '='.repeat((4 - (payload.length % 4)) % 4)
      const decoded = JSON.parse(atob(padded))

      // ARCHITECTURAL FIX: Validate decoded payload
      if (!decoded || !decoded.id) {
        throw new Error('Invalid token payload')
      }

      // ARCHITECTURAL FIX: Check token expiration
      if (decoded.exp && decoded.exp * 1000 < Date.now()) {
        throw new Error('Token expired')
      }

      // Return user data from token
      return {
        id: decoded.id,
        email: decoded.email,
        verified: decoded.verified || false,
        isPremium: decoded.isPremium || false
      }
    } catch (error) {
      console.error('Failed to fetch current user:', error)
      throw error
    }
  },

  /**
   * Update user profile
   * @param {object} updates - Profile updates
   * @returns {Promise<User>}
   */
  updateProfile: async (updates) => {
    try {
      return await apiClient.patch('/auth/me', updates)
    } catch (error) {
      console.error('Failed to update profile:', error)
      throw error
    }
  },

  /**
   * Change user password
   * @param {string} currentPassword
   * @param {string} newPassword
   * @returns {Promise<void>}
   */
  changePassword: async (currentPassword, newPassword) => {
    try {
      return await apiClient.post('/auth/change-password', {
        currentPassword,
        newPassword
      })
    } catch (error) {
      console.error('Failed to change password:', error)
      throw error
    }
  },

  /**
   * Request password reset
   * TODO: Implement UI for password reset flow (ForgotPasswordPage component)
   * Backend endpoint exists but no UI implementation yet
   * @param {string} email
   * @returns {Promise<void>}
   */
  requestPasswordReset: async (email) => {
    try {
      return await apiClient.post('/auth/forgot-password', {
        email
      })
    } catch (error) {
      console.error('Failed to request password reset:', error)
      throw error
    }
  },

  /**
   * Reset password with token
   * TODO: Implement UI for password reset completion (ResetPasswordPage component)
   * Backend endpoint exists but no UI implementation yet
   * @param {string} token - Reset token from email
   * @param {string} newPassword
   * @returns {Promise<void>}
   */
  resetPassword: async (token, newPassword) => {
    try {
      return await apiClient.post('/auth/reset-password', {
        token,
        newPassword
      })
    } catch (error) {
      console.error('Failed to reset password:', error)
      throw error
    }
  },

  /**
   * Verify email address
   * TODO: Implement UI for email verification (EmailVerificationPage component)
   * Backend endpoint exists but no UI implementation yet
   * @param {string} token - Verification token from email
   * @returns {Promise<void>}
   */
  verifyEmail: async (token) => {
    try {
      return await apiClient.post('/auth/verify-email', {
        token
      })
    } catch (error) {
      console.error('Failed to verify email:', error)
      throw error
    }
  }
}
