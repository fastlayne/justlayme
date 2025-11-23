/**
 * Token Refresh Interceptor
 * FIX 15: Automatically refresh expired tokens before API calls
 *
 * Features:
 * - Detects token expiration
 * - Refreshes token 1 minute before expiration (proactive)
 * - Handles concurrent refresh requests (deduplication)
 * - Maintains user session without interruption
 * - Fails gracefully if refresh token is invalid
 */

let refreshPromise = null
let lastRefreshTime = 0
const MIN_REFRESH_INTERVAL = 10000 // 10 seconds minimum between refreshes

/**
 * Decode JWT token payload
 */
export function decodeToken(token) {
  try {
    if (!token) return null

    const parts = token.split('.')
    if (parts.length !== 3) return null

    const payload = parts[1]
    const padded = payload + '='.repeat((4 - (payload.length % 4)) % 4)
    return JSON.parse(atob(padded))
  } catch (error) {
    console.error('[TokenRefresh] Failed to decode token:', error)
    return null
  }
}

/**
 * Check if token is expired
 */
export function isTokenExpired(token) {
  const decoded = decodeToken(token)
  if (!decoded || !decoded.exp) return true

  // Token is expired if exp time (in seconds) is in the past
  const expirationTime = decoded.exp * 1000 // Convert to ms
  return expirationTime < Date.now()
}

/**
 * Check if token is expiring soon (within threshold)
 * @param {string} token - JWT token
 * @param {number} thresholdMs - Milliseconds before expiration to consider "soon" (default 1 minute)
 */
export function isTokenExpiringSoon(token, thresholdMs = 60000) {
  const decoded = decodeToken(token)
  if (!decoded || !decoded.exp) return true

  const expirationTime = decoded.exp * 1000 // Convert to ms
  const timeUntilExpiration = expirationTime - Date.now()

  return timeUntilExpiration <= thresholdMs
}

/**
 * Get time until token expiration in milliseconds
 */
export function getTimeUntilExpiration(token) {
  const decoded = decodeToken(token)
  if (!decoded || !decoded.exp) return 0

  const expirationTime = decoded.exp * 1000
  return Math.max(0, expirationTime - Date.now())
}

/**
 * Refresh the auth token
 * Uses deduplication to prevent multiple simultaneous refresh requests
 *
 * @param {function} refreshTokenFn - Async function that calls the refresh endpoint
 * @returns {Promise<object>} - New token response
 */
export async function refreshTokenAsync(refreshTokenFn) {
  // Prevent refreshing too frequently
  const now = Date.now()
  if (now - lastRefreshTime < MIN_REFRESH_INTERVAL) {
    console.warn('[TokenRefresh] Refresh attempted too soon, skipping')
    return null
  }

  // Deduplicate concurrent refresh requests
  if (refreshPromise) {
    console.log('[TokenRefresh] Refresh already in progress, waiting for existing request')
    return refreshPromise
  }

  lastRefreshTime = now

  refreshPromise = refreshTokenFn()
    .then((response) => {
      console.log('[TokenRefresh] Token refreshed successfully')
      refreshPromise = null
      return response
    })
    .catch((error) => {
      console.error('[TokenRefresh] Token refresh failed:', error.message)
      refreshPromise = null
      throw error
    })

  return refreshPromise
}

/**
 * Setup token refresh interceptor for axios client
 * @param {AxiosInstance} apiClient - Axios client instance
 * @param {function} refreshTokenFn - Async function to refresh token
 */
export function setupTokenRefreshInterceptor(apiClient, refreshTokenFn) {
  // Request interceptor: Check and refresh token before making request
  apiClient.interceptors.request.use(
    async (config) => {
      const token = localStorage.getItem('authToken')

      if (token && isTokenExpiringSoon(token)) {
        console.log('[TokenRefresh] Token expiring soon, refreshing before request')

        try {
          const refreshResponse = await refreshTokenAsync(() => refreshTokenFn())

          if (refreshResponse && refreshResponse.token) {
            localStorage.setItem('authToken', refreshResponse.token)
            config.headers.Authorization = `Bearer ${refreshResponse.token}`
          }
        } catch (error) {
          console.error('[TokenRefresh] Failed to refresh token, request will proceed with current token')
          // Request proceeds with current token - if it's actually expired, 401 response will handle it
        }
      }

      return config
    },
    (error) => {
      return Promise.reject(error)
    }
  )

  // Response interceptor: Handle 401 Unauthorized responses
  apiClient.interceptors.response.use(
    (response) => response,
    async (error) => {
      const { response, config } = error

      // If 401 and not already a refresh request
      if (response?.status === 401 && !config._tokenRefreshAttempted) {
        console.log('[TokenRefresh] Received 401, attempting to refresh token')
        config._tokenRefreshAttempted = true

        try {
          const refreshResponse = await refreshTokenAsync(() => refreshTokenFn())

          if (refreshResponse && refreshResponse.token) {
            localStorage.setItem('authToken', refreshResponse.token)
            config.headers.Authorization = `Bearer ${refreshResponse.token}`

            // Retry original request with new token
            return apiClient(config)
          }
        } catch (refreshError) {
          console.error('[TokenRefresh] Failed to refresh after 401 response')
          // Refresh failed - dispatch unauthorized event and let app handle logout
          window.dispatchEvent(new CustomEvent('auth:unauthorized', {
            detail: { message: 'Session expired. Please log in again.' }
          }))
          return Promise.reject(refreshError)
        }
      }

      return Promise.reject(error)
    }
  )
}

/**
 * Schedule a token refresh for a specific time before expiration
 * Returns cleanup function to cancel the scheduled refresh
 *
 * @param {string} token - JWT token
 * @param {function} refreshTokenFn - Async function to refresh token
 * @param {number} advanceMs - How far in advance to refresh (default 1 minute)
 * @returns {function} - Cleanup function to cancel the scheduled refresh
 */
export function scheduleTokenRefresh(token, refreshTokenFn, advanceMs = 60000) {
  const timeUntilExpiration = getTimeUntilExpiration(token)

  if (timeUntilExpiration <= 0) {
    console.warn('[TokenRefresh] Token already expired, not scheduling refresh')
    return () => {}
  }

  // Schedule refresh to happen `advanceMs` before expiration
  const refreshInMs = Math.max(0, timeUntilExpiration - advanceMs)

  console.log(
    `[TokenRefresh] Scheduled token refresh in ${(refreshInMs / 1000).toFixed(1)}s (expires in ${(timeUntilExpiration / 1000).toFixed(1)}s)`
  )

  const timeoutId = setTimeout(async () => {
    try {
      const newTokenResponse = await refreshTokenAsync(refreshTokenFn)
      if (newTokenResponse && newTokenResponse.token) {
        localStorage.setItem('authToken', newTokenResponse.token)
        // Schedule next refresh with new token
        scheduleTokenRefresh(newTokenResponse.token, refreshTokenFn, advanceMs)
      }
    } catch (error) {
      console.error('[TokenRefresh] Scheduled refresh failed:', error.message)
    }
  }, refreshInMs)

  // Return cleanup function
  return () => {
    clearTimeout(timeoutId)
    console.log('[TokenRefresh] Cancelled scheduled token refresh')
  }
}

/**
 * Validate and potentially refresh token on app startup
 * @param {function} refreshTokenFn - Async function to refresh token
 */
export async function validateAndRefreshTokenOnStartup(refreshTokenFn) {
  const token = localStorage.getItem('authToken')

  if (!token) {
    console.log('[TokenRefresh] No token found on startup')
    return null
  }

  if (isTokenExpired(token)) {
    console.log('[TokenRefresh] Token expired on startup, attempting refresh')

    try {
      const refreshResponse = await refreshTokenAsync(refreshTokenFn)
      if (refreshResponse && refreshResponse.token) {
        localStorage.setItem('authToken', refreshResponse.token)
        return refreshResponse
      }
    } catch (error) {
      console.error('[TokenRefresh] Failed to refresh expired token on startup')
      localStorage.removeItem('authToken')
      localStorage.removeItem('refreshToken')
      return null
    }
  }

  if (isTokenExpiringSoon(token)) {
    console.log('[TokenRefresh] Token expiring soon on startup, refreshing proactively')

    try {
      const refreshResponse = await refreshTokenAsync(refreshTokenFn)
      if (refreshResponse && refreshResponse.token) {
        localStorage.setItem('authToken', refreshResponse.token)
        return refreshResponse
      }
    } catch (error) {
      console.warn('[TokenRefresh] Proactive refresh on startup failed, proceeding with current token')
      return null
    }
  }

  console.log('[TokenRefresh] Token is valid on startup')
  return { token }
}
