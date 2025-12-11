import axios from 'axios'
import { setupTokenRefreshInterceptor } from '@/utils/tokenRefreshInterceptor'

/**
 * Axios HTTP Client
 * Central configuration for all API calls
 * Includes request/response interceptors for auth and error handling
 * FIX 15: Integrated token refresh interceptor for automatic token refresh
 */

// Use relative API path for proper routing through Cloudflare tunnel
// When accessing via justlay.me, /api calls go to the same domain (which tunnels to localhost:3333)
// When accessing via localhost, /api also works (goes to localhost:3333)
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || '/api'

const apiClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  },
  // SECURITY: Enable cookie sending for httpOnly cookie-based auth
  withCredentials: true
})

/**
 * Request Interceptor
 * SECURITY FIX: Removed Authorization header - now using httpOnly cookies exclusively
 * - Authentication is handled via httpOnly cookies (set by server)
 * - Cookies are automatically sent with every request via withCredentials: true
 * - This prevents XSS attacks and eliminates dual-auth session conflicts
 */
apiClient.interceptors.request.use(
  (config) => {
    // No Authorization header needed - cookies are sent automatically
    // via withCredentials: true in axios config
    return config
  },
  (error) => {
    return Promise.reject(error)
  }
)

/**
 * Response Interceptor
 * - Handles successful responses (extracts data)
 * - Handles errors globally
 *   - 401: Redirect to login
 *   - 429: Rate limiting
 *   - 5xx: Server errors
 * - Refreshes token if needed
 */
apiClient.interceptors.response.use(
  (response) => {
    return response.data
  },
  (error) => {
    const { response, code, message } = error

    if (!response) {
      // Network error (no response from server)
      console.error('[API Error - No Response]', code, message)
      return Promise.reject({
        type: 'NETWORK_ERROR',
        code,
        message: 'Network error. Please check your connection.'
      })
    }

    const { status, data } = response
    console.error(`[API Error] ${status}`, data)

    switch (status) {
      case 401:
        // Unauthorized - dispatch event for app to handle
        // SECURITY FIX: No localStorage cleanup needed (cookies only)
        window.dispatchEvent(new CustomEvent('auth:unauthorized', {
          detail: { message: 'Session expired. Please log in again.' }
        }))
        return Promise.reject({
          type: 'UNAUTHORIZED',
          status: 401,
          message: 'Session expired. Please log in again.'
        })

      case 403:
        // Forbidden
        return Promise.reject({
          type: 'FORBIDDEN',
          status: 403,
          message: 'You do not have permission to perform this action.'
        })

      case 404:
        // Not found
        return Promise.reject({
          type: 'NOT_FOUND',
          status: 404,
          message: data?.message || 'Resource not found.'
        })

      case 429:
        // Rate limited
        return Promise.reject({
          type: 'RATE_LIMITED',
          status: 429,
          message: 'Too many requests. Please wait a moment and try again.'
        })

      case 500:
      case 502:
      case 503:
      case 504:
        // Server error
        return Promise.reject({
          type: 'SERVER_ERROR',
          status,
          message: 'Server error. Please try again later.'
        })

      default:
        // Generic error
        return Promise.reject({
          type: 'ERROR',
          status,
          message: data?.message || 'An error occurred. Please try again.'
        })
    }
  }
)

// FIX 15: Setup token refresh interceptor with authAPI.refreshToken
// This will be initialized after import to avoid circular dependencies
let tokenRefreshInitialized = false

export function initializeTokenRefresh(refreshTokenFn) {
  if (tokenRefreshInitialized) return

  try {
    setupTokenRefreshInterceptor(apiClient, refreshTokenFn)
    tokenRefreshInitialized = true
    console.log('[API Client] Token refresh interceptor initialized')
  } catch (error) {
    console.error('[API Client] Failed to setup token refresh interceptor:', error)
  }
}

export default apiClient
