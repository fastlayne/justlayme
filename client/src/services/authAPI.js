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
   * SECURITY FIX: No longer stores tokens in localStorage
   * Authentication token is now stored in httpOnly cookie by server
   * @param {string} email
   * @param {string} password
   * @returns {Promise<{user: User}>}
   */
  login: async (email, password) => {
    try {
      const response = await apiClient.post('/login', {
        email,
        password
      })

      // Token is now stored in httpOnly cookie by server
      // No need to store in localStorage (security improvement)
      // Cookies are automatically sent with every request

      return response
    } catch (error) {
      console.error('Login failed:', error)
      throw error
    }
  },

  /**
   * User signup/registration
   * SECURITY FIX: No longer stores tokens in localStorage
   * Authentication token is now stored in httpOnly cookie by server
   * @param {string} email
   * @param {string} password
   * @param {string} name
   * @returns {Promise<{user: User}>}
   */
  signup: async (email, password, name) => {
    try {
      const response = await apiClient.post('/register', {
        email,
        password,
        username: name || email.split('@')[0] // Backend expects username, not name
      })

      // Token is now stored in httpOnly cookie by server
      // No need to store in localStorage (security improvement)

      return response
    } catch (error) {
      console.error('Signup failed:', error)
      throw error
    }
  },

  /**
   * Refresh authentication token
   * SECURITY FIX: Token refresh now handled via httpOnly cookies
   * Server validates existing cookie and issues new cookie
   * @returns {Promise<{user: User}>}
   */
  refreshToken: async () => {
    try {
      const response = await apiClient.post('/auth/refresh')

      // New token is automatically set in httpOnly cookie by server
      // No need to manually update localStorage

      return response
    } catch (error) {
      console.error('Token refresh failed:', error)
      // If refresh fails, logout (clears cookie on server)
      authAPI.logout()
      throw error
    }
  },

  /**
   * Logout user
   * SECURITY FIX: Only clears httpOnly cookie on server
   * No client-side token storage to clear
   */
  logout: async () => {
    try {
      // Call server-side logout to clear httpOnly cookie
      await apiClient.post('/logout')
    } catch (error) {
      console.error('Server logout failed:', error)
      // Error is logged but not thrown - user is logged out anyway
    }
    // No localStorage cleanup needed - tokens are only in httpOnly cookies
  },

  /**
   * Get current user profile
   * SECURITY FIX: Cannot decode httpOnly cookie on client
   * Must call backend API to get user info
   * @returns {Promise<User>}
   */
  getCurrentUser: async () => {
    try {
      // Call backend to get current user from cookie
      const response = await apiClient.get('/auth/me')
      return response.user
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
