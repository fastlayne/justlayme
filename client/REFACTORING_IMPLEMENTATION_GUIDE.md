# JustLayMe Client - Refactoring Implementation Guide

This guide provides step-by-step implementations for the top architectural recommendations.

---

## 1. Context Splitting: UIContext → 3 Focused Contexts

### Step 1: Create NavigationContext

**File:** `/src/contexts/NavigationContext.jsx`

```jsx
import { createContext, useState, useCallback, useEffect } from 'react'

export const NavigationContext = createContext()

const isMobileInitial = typeof window !== 'undefined' && window.innerWidth < 768

export function NavigationProvider({ children }) {
  const [sidebarOpen, setSidebarOpen] = useState(!isMobileInitial)
  const [isMobileView, setIsMobileView] = useState(isMobileInitial)

  // Handle responsive resizing
  useEffect(() => {
    const handleResize = () => {
      const mobile = window.innerWidth < 768
      setIsMobileView(mobile)
      // Close sidebar when switching from mobile to desktop
      if (!mobile && sidebarOpen) {
        setSidebarOpen(false)
      }
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [sidebarOpen])

  const toggleSidebar = useCallback(() => {
    setSidebarOpen(prev => !prev)
  }, [])

  const value = {
    sidebarOpen,
    setSidebarOpen,
    toggleSidebar,
    isMobileView,
    setMobileView: setIsMobileView
  }

  return (
    <NavigationContext.Provider value={value}>
      {children}
    </NavigationContext.Provider>
  )
}
```

### Step 2: Create ModalContext

**File:** `/src/contexts/ModalContext.jsx`

```jsx
import { createContext, useReducer, useCallback } from 'react'

export const ModalContext = createContext()

const initialState = {
  modalStack: []
}

const ACTIONS = {
  OPEN_MODAL: 'OPEN_MODAL',
  CLOSE_MODAL: 'CLOSE_MODAL',
  CLOSE_ALL_MODALS: 'CLOSE_ALL_MODALS',
  UPDATE_MODAL_DATA: 'UPDATE_MODAL_DATA'
}

function modalReducer(state, action) {
  switch (action.type) {
    case ACTIONS.OPEN_MODAL: {
      const existingModal = state.modalStack.find(m => m.type === action.payload.type)
      if (existingModal) {
        return {
          ...state,
          modalStack: state.modalStack.map(m =>
            m.type === action.payload.type
              ? { ...m, data: action.payload.data || {} }
              : m
          )
        }
      }
      return {
        ...state,
        modalStack: [
          ...state.modalStack,
          {
            id: action.payload.id,
            type: action.payload.type,
            isOpen: true,
            data: action.payload.data || {}
          }
        ]
      }
    }

    case ACTIONS.CLOSE_MODAL:
      return {
        ...state,
        modalStack: state.modalStack.filter(m => m.id !== action.payload)
      }

    case ACTIONS.CLOSE_ALL_MODALS:
      return { ...state, modalStack: [] }

    case ACTIONS.UPDATE_MODAL_DATA:
      return {
        ...state,
        modalStack: state.modalStack.map(m =>
          m.id === action.payload.id
            ? { ...m, data: { ...m.data, ...action.payload.data } }
            : m
        )
      }

    default:
      return state
  }
}

export function ModalProvider({ children }) {
  const [state, dispatch] = useReducer(modalReducer, initialState)

  const openModal = useCallback((type, data, id) => {
    const modalId = id || `${type}-${Date.now()}`
    dispatch({
      type: ACTIONS.OPEN_MODAL,
      payload: { id: modalId, type, data }
    })
    return modalId
  }, [])

  const closeModal = useCallback((id) => {
    dispatch({ type: ACTIONS.CLOSE_MODAL, payload: id })
  }, [])

  const closeAllModals = useCallback(() => {
    dispatch({ type: ACTIONS.CLOSE_ALL_MODALS })
  }, [])

  const updateModalData = useCallback((id, data) => {
    dispatch({
      type: ACTIONS.UPDATE_MODAL_DATA,
      payload: { id, data }
    })
  }, [])

  const value = {
    modalStack: state.modalStack,
    openModal,
    closeModal,
    closeAllModals,
    updateModalData
  }

  return (
    <ModalContext.Provider value={value}>
      {children}
    </ModalContext.Provider>
  )
}
```

### Step 3: Create NotificationContext

**File:** `/src/contexts/NotificationContext.jsx`

```jsx
import { createContext, useReducer, useCallback } from 'react'

export const NotificationContext = createContext()

const initialState = {
  notificationQueue: []
}

const ACTIONS = {
  ADD_NOTIFICATION: 'ADD_NOTIFICATION',
  REMOVE_NOTIFICATION: 'REMOVE_NOTIFICATION'
}

function notificationReducer(state, action) {
  switch (action.type) {
    case ACTIONS.ADD_NOTIFICATION:
      return {
        ...state,
        notificationQueue: [
          ...state.notificationQueue,
          {
            id: action.payload.id,
            message: action.payload.message,
            type: action.payload.type || 'info',
            duration: action.payload.duration || 3000
          }
        ]
      }

    case ACTIONS.REMOVE_NOTIFICATION:
      return {
        ...state,
        notificationQueue: state.notificationQueue.filter(
          n => n.id !== action.payload
        )
      }

    default:
      return state
  }
}

export function NotificationProvider({ children }) {
  const [state, dispatch] = useReducer(notificationReducer, initialState)

  const addNotification = useCallback((message, type = 'info', duration = 3000) => {
    const id = `notification-${Date.now()}`
    dispatch({
      type: ACTIONS.ADD_NOTIFICATION,
      payload: { id, message, type, duration }
    })

    if (duration > 0) {
      setTimeout(() => {
        dispatch({
          type: ACTIONS.REMOVE_NOTIFICATION,
          payload: id
        })
      }, duration)
    }

    return id
  }, [])

  const removeNotification = useCallback((id) => {
    dispatch({ type: ACTIONS.REMOVE_NOTIFICATION, payload: id })
  }, [])

  const value = {
    notificationQueue: state.notificationQueue,
    addNotification,
    removeNotification
  }

  return (
    <NotificationContext.Provider value={value}>
      {children}
    </NotificationContext.Provider>
  )
}
```

### Step 4: Update App.jsx Provider Structure

**File:** `/src/App.jsx` (Modified Provider Section)

```jsx
import { NavigationProvider } from './contexts/NavigationContext'
import { ModalProvider } from './contexts/ModalContext'
import { NotificationProvider } from './contexts/NotificationContext'

function App() {
  const AppProviders = ({ children }) => {
    if (GOOGLE_CLIENT_ID && GOOGLE_CLIENT_ID.trim() !== '') {
      return (
        <GoogleOAuthProvider clientId={GOOGLE_CLIENT_ID}>
          {children}
        </GoogleOAuthProvider>
      )
    }
    return <>{children}</>
  }

  return (
    <AppProviders>
      <PageTransitionProvider>
        <AuthProvider>
          <ChatProvider>
            <CharacterProvider>
              {/* NEW: Split UI contexts */}
              <NavigationProvider>
                <ModalProvider>
                  <NotificationProvider>
                    <BlackMirrorProvider>
                      <Router>
                        <TargetCursor />
                        <AppContent />
                        <ModalRenderer />
                      </Router>
                    </BlackMirrorProvider>
                  </NotificationProvider>
                </ModalProvider>
              </NavigationProvider>
              {/* END NEW */}
            </CharacterProvider>
          </ChatProvider>
        </AuthProvider>
      </PageTransitionProvider>
    </AppProviders>
  )
}

export default App
```

### Step 5: Update Hooks to Use New Contexts

**File:** `/src/hooks/useNavigation.js` (NEW)

```jsx
import { useContext } from 'react'
import { NavigationContext } from '@/contexts/NavigationContext'

export function useNavigation() {
  const context = useContext(NavigationContext)

  if (!context) {
    throw new Error('useNavigation must be used within NavigationProvider')
  }

  return context
}
```

**File:** `/src/hooks/useModal.js` (UPDATED)

```jsx
import { useContext, useCallback, useRef } from 'react'
import { ModalContext } from '@/contexts/ModalContext'

export function useModal(modalType) {
  const context = useContext(ModalContext)
  const lastOpenTime = useRef(0)

  if (!context) {
    throw new Error('useModal must be used within ModalProvider')
  }

  const modal = context.modalStack.find(m => m.type === modalType)

  const openModal = useCallback(
    (data, id) => {
      const now = Date.now()
      if (now - lastOpenTime.current < 500) {
        return null
      }
      lastOpenTime.current = now
      return context.openModal(modalType, data, id)
    },
    [context, modalType]
  )

  const closeModal = useCallback(() => {
    if (modal) {
      context.closeModal(modal.id)
    }
  }, [context, modal])

  const updateData = useCallback(
    (data) => {
      if (modal) {
        context.updateModalData(modal.id, data)
      }
    },
    [context, modal]
  )

  return {
    isOpen: !!modal,
    data: modal?.data || {},
    modalId: modal?.id,
    openModal,
    closeModal,
    updateData
  }
}
```

**File:** `/src/hooks/useNotification.js` (UPDATED)

```jsx
import { useContext, useCallback } from 'react'
import { NotificationContext } from '@/contexts/NotificationContext'

export function useNotification() {
  const context = useContext(NotificationContext)

  if (!context) {
    throw new Error('useNotification must be used within NotificationProvider')
  }

  const notify = useCallback(
    (message, type = 'info', duration = 3000) => {
      return context.addNotification(message, type, duration)
    },
    [context]
  )

  const success = useCallback(
    (message, duration = 3000) => {
      return context.addNotification(message, 'success', duration)
    },
    [context]
  )

  const error = useCallback(
    (message, duration = 5000) => {
      return context.addNotification(message, 'error', duration)
    },
    [context]
  )

  const warning = useCallback(
    (message, duration = 4000) => {
      return context.addNotification(message, 'warning', duration)
    },
    [context]
  )

  const info = useCallback(
    (message, duration = 3000) => {
      return context.addNotification(message, 'info', duration)
    },
    [context]
  )

  return {
    notifications: context.notificationQueue,
    notify,
    success,
    error,
    warning,
    info,
    remove: context.removeNotification
  }
}
```

---

## 2. Query Cache Implementation

### Step 1: Create Cache Utility

**File:** `/src/utils/queryCache.js`

```jsx
/**
 * Simple query cache for managing API response caching
 * Supports TTL, deduplication of in-flight requests, and cache invalidation
 */

class QueryCache {
  constructor(defaultTTL = 5 * 60 * 1000) {
    this.cache = new Map()
    this.inFlight = new Map()
    this.defaultTTL = defaultTTL
  }

  /**
   * Get cached value if not expired
   */
  get(key) {
    const entry = this.cache.get(key)
    if (!entry) return null

    if (Date.now() > entry.expiry) {
      this.cache.delete(key)
      return null
    }

    return entry.value
  }

  /**
   * Set cache value with TTL
   */
  set(key, value, ttl = this.defaultTTL) {
    const expiry = Date.now() + ttl
    this.cache.set(key, { value, expiry })
  }

  /**
   * Check if key exists and is not expired
   */
  has(key) {
    return this.get(key) !== null
  }

  /**
   * Get or fetch value - deduplicates in-flight requests
   */
  async getOrFetch(key, queryFn) {
    // Return cached value if available
    const cached = this.get(key)
    if (cached !== null) {
      return Promise.resolve(cached)
    }

    // Return existing in-flight request if one is already in progress
    if (this.inFlight.has(key)) {
      return this.inFlight.get(key)
    }

    // Create new fetch promise
    const promise = (async () => {
      try {
        const result = await queryFn()
        this.set(key, result)
        this.inFlight.delete(key)
        return result
      } catch (error) {
        this.inFlight.delete(key)
        throw error
      }
    })()

    // Track in-flight request
    this.inFlight.set(key, promise)
    return promise
  }

  /**
   * Clear specific cache entry or entire cache
   */
  clear(key) {
    if (key) {
      this.cache.delete(key)
    } else {
      this.cache.clear()
    }
  }

  /**
   * Get cache size (for debugging)
   */
  size() {
    return {
      cached: this.cache.size,
      inFlight: this.inFlight.size
    }
  }
}

export const queryCache = new QueryCache()
```

### Step 2: Create useQuery Hook

**File:** `/src/hooks/useQuery.js`

```jsx
import { useState, useEffect, useCallback, useRef } from 'react'
import { queryCache } from '@/utils/queryCache'

/**
 * React hook for data fetching with caching
 * Similar to React Query but lightweight
 *
 * @param {string} key - Cache key (should be unique per query)
 * @param {Function} queryFn - Async function that fetches data
 * @param {Object} options - Configuration options
 * @param {number} options.ttl - Time to live in milliseconds (default: 5 min)
 * @param {boolean} options.enabled - Whether to run the query (default: true)
 * @returns {Object} Query state and methods
 */
export function useQuery(key, queryFn, options = {}) {
  const { ttl = 5 * 60 * 1000, enabled = true } = options
  const [data, setData] = useState(null)
  const [error, setError] = useState(null)
  const [isLoading, setIsLoading] = useState(!queryCache.has(key))
  const mountedRef = useRef(true)

  // Track if component is mounted to prevent state updates after unmount
  useEffect(() => {
    return () => {
      mountedRef.current = false
    }
  }, [])

  // Fetch data
  useEffect(() => {
    if (!enabled) {
      setIsLoading(false)
      return
    }

    const fetchData = async () => {
      try {
        setIsLoading(true)
        const result = await queryCache.getOrFetch(key, async () => {
          return await queryFn()
        })

        if (mountedRef.current) {
          setData(result)
          setError(null)
        }
      } catch (err) {
        if (mountedRef.current) {
          setError(err)
          setData(null)
        }
      } finally {
        if (mountedRef.current) {
          setIsLoading(false)
        }
      }
    }

    fetchData()
  }, [key, queryFn, enabled, ttl])

  const refetch = useCallback(() => {
    queryCache.clear(key)
    setIsLoading(true)
    setError(null)
  }, [key])

  const invalidate = useCallback(() => {
    queryCache.clear(key)
  }, [key])

  return {
    data,
    error,
    isLoading,
    refetch,
    invalidate,
    isCached: !isLoading && data !== null
  }
}
```

### Step 3: Use Query Hook in Components

**File:** `/src/pages/ChatPage.jsx` (Example Usage)

```jsx
import { useQuery } from '@/hooks/useQuery'
import { chatAPI } from '@/services/chatAPI'

export default function ChatPage() {
  // No longer need to call fetchConversations manually!
  const {
    data: conversations,
    isLoading,
    error,
    refetch
  } = useQuery(
    'conversations',           // Cache key
    () => chatAPI.getConversations(), // Fetch function
    { ttl: 10 * 60 * 1000 }   // Cache for 10 minutes
  )

  if (error) {
    return <div className="error">Failed to load conversations</div>
  }

  return (
    <div className="chat-page">
      {isLoading && <LoadingSpinner />}
      <ConversationList conversations={conversations || []} />
      <button onClick={refetch}>Refresh</button>
    </div>
  )
}
```

**File:** `/src/components/chat/Sidebar.jsx` (Automatic Cache Sharing)

```jsx
export default function Sidebar() {
  // Same cache key = shares data with ChatPage!
  const { data: conversations } = useQuery(
    'conversations',
    () => chatAPI.getConversations()
  )

  return (
    <div className="sidebar">
      <ConversationList conversations={conversations || []} />
    </div>
  )
}
```

---

## 3. Standardized Error Class

**File:** `/src/utils/ApiError.js`

```jsx
/**
 * Standardized error class for API errors
 * Provides type-safe error handling across the application
 */

export class ApiError extends Error {
  constructor(type, status, message, originalError = null) {
    super(message)
    this.name = 'ApiError'
    this.type = type
    this.status = status
    this.originalError = originalError
  }

  // Helper methods for error checking
  isUnauthorized() {
    return this.type === 'UNAUTHORIZED'
  }

  isForbidden() {
    return this.type === 'FORBIDDEN'
  }

  isNotFound() {
    return this.type === 'NOT_FOUND'
  }

  isRateLimited() {
    return this.type === 'RATE_LIMITED'
  }

  isServerError() {
    return this.type === 'SERVER_ERROR'
  }

  isNetworkError() {
    return this.type === 'NETWORK_ERROR'
  }

  /**
   * Create ApiError from any error
   */
  static from(error, defaultMessage = 'An error occurred') {
    if (error instanceof ApiError) {
      return error
    }
    return new ApiError('ERROR', null, error.message || defaultMessage, error)
  }

  /**
   * Create 401 error
   */
  static unauthorized(message = 'Session expired. Please log in again.') {
    return new ApiError('UNAUTHORIZED', 401, message)
  }

  /**
   * Create 403 error
   */
  static forbidden(message = 'You do not have permission to perform this action.') {
    return new ApiError('FORBIDDEN', 403, message)
  }

  /**
   * Create 404 error
   */
  static notFound(message = 'Resource not found.') {
    return new ApiError('NOT_FOUND', 404, message)
  }

  /**
   * Create rate limit error
   */
  static rateLimited(message = 'Too many requests. Please wait a moment.') {
    return new ApiError('RATE_LIMITED', 429, message)
  }

  /**
   * Create server error
   */
  static serverError(message = 'Server error. Please try again later.') {
    return new ApiError('SERVER_ERROR', 500, message)
  }

  /**
   * Create network error
   */
  static networkError(message = 'Network error. Please check your connection.') {
    return new ApiError('NETWORK_ERROR', null, message)
  }
}
```

**File:** `/src/services/client.js` (Updated Response Interceptor)

```jsx
import { ApiError } from '@/utils/ApiError'

apiClient.interceptors.response.use(
  (response) => {
    return response.data
  },
  (error) => {
    const { response, code, message } = error

    if (!response) {
      // Network error (no response from server)
      console.error('[API Error - No Response]', code, message)
      return Promise.reject(ApiError.networkError())
    }

    const { status, data } = response
    console.error(`[API Error] ${status}`, data)

    switch (status) {
      case 401:
        return Promise.reject(ApiError.unauthorized())

      case 403:
        return Promise.reject(ApiError.forbidden())

      case 404:
        return Promise.reject(ApiError.notFound(data?.message))

      case 429:
        return Promise.reject(ApiError.rateLimited())

      case 500:
      case 502:
      case 503:
      case 504:
        return Promise.reject(ApiError.serverError())

      default:
        return Promise.reject(
          ApiError.from(error, data?.message || 'An error occurred')
        )
    }
  }
)
```

---

## 4. Constants Configuration

**File:** `/src/config/constants.js`

```jsx
/**
 * Application-wide constants
 * Centralizes magic numbers and strings
 */

export const APP = {
  NAME: 'JustLayMe',
  VERSION: '0.0.1',
  ENVIRONMENT: import.meta.env.MODE
}

export const MESSAGES = {
  MAX_RENDERED: 200,              // Max DOM messages to prevent memory leak
  MAX_LENGTH: 4096,               // Max message length
  FILE_MAX_SIZE: 5 * 1024 * 1024, // 5MB max file size
  ALLOWED_FILE_TYPES: [
    'image/jpeg',
    'image/png',
    'image/gif',
    'image/webp'
  ]
}

export const UI = {
  MOBILE_BREAKPOINT: 768,
  SIDEBAR_WIDTH: 300,
  MODAL_DEBOUNCE_MS: 500,
  NOTIFICATION_DURATION_SUCCESS: 3000,
  NOTIFICATION_DURATION_ERROR: 5000,
  NOTIFICATION_DURATION_WARNING: 4000,
  NOTIFICATION_DURATION_INFO: 3000
}

export const API = {
  BASE_URL: import.meta.env.VITE_API_BASE_URL || '/api',
  TIMEOUT: 30000,
  RETRY_MAX_ATTEMPTS: 5,
  RETRY_RESET_MS: 30000
}

export const CACHE = {
  CONVERSATIONS_TTL: 10 * 60 * 1000,  // 10 minutes
  CHARACTERS_TTL: 15 * 60 * 1000,     // 15 minutes
  MESSAGES_TTL: 5 * 60 * 1000,        // 5 minutes
  DEFAULT_TTL: 5 * 60 * 1000          // 5 minutes
}

export const ANIMATION = {
  PAGE_TRANSITION_DURATION: 300,
  MESSAGE_ANIMATION_DURATION: 200,
  SIDEBAR_ANIMATION_DURATION: 300
}
```

---

## 5. Component Documentation Standards

**File:** `/src/components/common/OptimizedImage.jsx`

```jsx
import { useState, useRef, useEffect } from 'react'

/**
 * OptimizedImage Component
 *
 * Renders images with lazy loading, error handling, and loading states
 * Prevents layout shift with aspect ratio preservation
 *
 * @component
 * @example
 * <OptimizedImage
 *   src={character.avatar}
 *   alt="Character Avatar"
 *   width={200}
 *   height={200}
 *   fallback={<div>No Image</div>}
 * />
 *
 * @param {Object} props
 * @param {string} props.src - Image source URL
 * @param {string} props.alt - Alt text for accessibility
 * @param {number} [props.width=200] - Image width in pixels
 * @param {number} [props.height=200] - Image height in pixels
 * @param {React.ReactNode} [props.fallback] - Component to show on error
 * @returns {React.ReactElement} Optimized image component
 */
export function OptimizedImage({
  src,
  alt,
  width = 200,
  height = 200,
  fallback = null
}) {
  const [isLoading, setIsLoading] = useState(true)
  const [error, setError] = useState(false)
  const imageRef = useRef(null)

  useEffect(() => {
    if (!src) {
      setError(true)
      setIsLoading(false)
      return
    }

    const img = new Image()
    img.onload = () => setIsLoading(false)
    img.onerror = () => {
      setIsLoading(false)
      setError(true)
    }
    img.src = src
  }, [src])

  if (error) {
    return fallback || <div className="image-error">{alt}</div>
  }

  return (
    <>
      {isLoading && (
        <div
          className="image-skeleton"
          style={{
            width,
            height,
            backgroundColor: '#e0e0e0',
            animation: 'pulse 1.5s infinite'
          }}
        />
      )}
      <img
        ref={imageRef}
        src={src}
        alt={alt}
        width={width}
        height={height}
        loading="lazy"
        decoding="async"
        style={{
          display: isLoading ? 'none' : 'block',
          maxWidth: '100%',
          height: 'auto'
        }}
      />
    </>
  )
}
```

---

## 6. Breaking Down SettingsModal

### Step 1: Extract Tabs into Sub-Components

**File:** `/src/components/modals/settings/AccountSettingsTab.jsx`

```jsx
import { useState } from 'react'
import { useAuth } from '@/hooks/useAuth'
import { useNotification } from '@/hooks/useNotification'

/**
 * Account Settings Tab
 * Displays user account information and account-related actions
 */
export function AccountSettingsTab() {
  const { user, logout } = useAuth()
  const notification = useNotification()
  const [showPasswordChange, setShowPasswordChange] = useState(false)

  const handleLogout = () => {
    logout()
    notification.success('Logged out successfully')
  }

  return (
    <div className="settings-section">
      <h3>Account Settings</h3>

      <div className="setting-item">
        <div className="setting-info">
          <p className="setting-label">Email</p>
          <p className="setting-value">{user?.email || 'Not set'}</p>
        </div>
      </div>

      <div className="setting-item">
        <div className="setting-info">
          <p className="setting-label">Account Status</p>
          <p className="setting-value">
            {user?.isPremium ? (
              <span className="status-premium">✨ Premium</span>
            ) : (
              <span className="status-free">Free</span>
            )}
          </p>
        </div>
      </div>

      <div className="setting-item">
        <div className="setting-info">
          <p className="setting-label">Password</p>
          <p className="setting-value">••••••••</p>
        </div>
        <button
          className="btn-text"
          onClick={() => setShowPasswordChange(!showPasswordChange)}
        >
          Change
        </button>
      </div>

      {showPasswordChange && (
        <div className="password-change-form">
          {/* Password change form here */}
        </div>
      )}

      <div className="setting-item">
        <button className="btn-secondary full-width" onClick={handleLogout}>
          Logout
        </button>
      </div>
    </div>
  )
}
```

**File:** `/src/components/modals/settings/CharacterSettingsTab.jsx`

```jsx
import { useState } from 'react'
import { useCharacters } from '@/hooks/useCharacters'
import { useNotification } from '@/hooks/useNotification'

/**
 * Character Settings Tab
 * Allows users to manage (edit/delete) their custom characters
 */
export function CharacterSettingsTab() {
  const { characters, updateCharacterData, deleteCharacterData } = useCharacters()
  const notification = useNotification()
  const [editingCharacter, setEditingCharacter] = useState(null)
  const [characterToDelete, setCharacterToDelete] = useState(null)

  const handleEditCharacter = (character) => {
    setEditingCharacter({ ...character })
  }

  const handleSaveCharacter = async () => {
    if (!editingCharacter) return

    try {
      await updateCharacterData(editingCharacter.id, {
        name: editingCharacter.name,
        bio: editingCharacter.bio,
        personality: editingCharacter.personality,
        avatar: editingCharacter.avatar
      })
      notification.success('Character updated successfully!')
      setEditingCharacter(null)
    } catch (error) {
      notification.error(`Failed to update character: ${error.message}`)
    }
  }

  const handleDeleteCharacter = async (characterId) => {
    try {
      await deleteCharacterData(characterId)
      notification.success('Character deleted successfully')
      setCharacterToDelete(null)
    } catch (error) {
      notification.error(`Failed to delete character: ${error.message}`)
    }
  }

  return (
    <div className="settings-section">
      <h3>Manage Characters</h3>
      <p className="section-description">
        Edit or delete your custom AI characters
      </p>

      {characters.length === 0 ? (
        <div className="empty-state">
          <p>No custom characters yet</p>
          <p className="text-sm">Create your first character to get started!</p>
        </div>
      ) : (
        <div className="character-list">
          {characters.map((character) => (
            <div key={character.id} className="character-item">
              <div className="character-avatar">{character.avatar || '🎭'}</div>
              <div className="character-info">
                <p className="character-name">{character.name}</p>
                <p className="character-bio">
                  {character.bio?.substring(0, 50)}...
                </p>
              </div>
              <div className="character-actions">
                <button
                  className="btn-icon"
                  onClick={() => handleEditCharacter(character)}
                  title="Edit character"
                >
                  ✏️
                </button>
                <button
                  className="btn-icon danger"
                  onClick={() => setCharacterToDelete(character.id)}
                  title="Delete character"
                >
                  🗑️
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Edit Modal */}
      {editingCharacter && (
        <div className="inline-modal">
          <h4>Edit Character</h4>
          <div className="form-group">
            <label>Name</label>
            <input
              type="text"
              value={editingCharacter.name}
              onChange={(e) =>
                setEditingCharacter({
                  ...editingCharacter,
                  name: e.target.value
                })
              }
            />
          </div>
          {/* More form fields... */}
          <div className="form-actions">
            <button
              className="btn-secondary"
              onClick={() => setEditingCharacter(null)}
            >
              Cancel
            </button>
            <button
              className="btn-primary"
              onClick={handleSaveCharacter}
            >
              Save Changes
            </button>
          </div>
        </div>
      )}

      {/* Delete Confirmation */}
      {characterToDelete && (
        <div className="inline-modal danger">
          <h4>⚠️ Delete Character?</h4>
          <p>
            This will permanently delete this character and all associated
            conversations. This cannot be undone.
          </p>
          <div className="form-actions">
            <button
              className="btn-secondary"
              onClick={() => setCharacterToDelete(null)}
            >
              Cancel
            </button>
            <button
              className="btn-danger"
              onClick={() => handleDeleteCharacter(characterToDelete)}
            >
              Delete Permanently
            </button>
          </div>
        </div>
      )}
    </div>
  )
}
```

### Step 2: Create Simplified Settings Modal

**File:** `/src/components/modals/SettingsModal.jsx` (Refactored)

```jsx
import { useState } from 'react'
import { AccountSettingsTab } from './settings/AccountSettingsTab'
import { CharacterSettingsTab } from './settings/CharacterSettingsTab'
import { AISettingsTab } from './settings/AISettingsTab'
import { ChatSettingsTab } from './settings/ChatSettingsTab'
import { PreferencesTab } from './settings/PreferencesTab'
import { DataPrivacyTab } from './settings/DataPrivacyTab'
import { PremiumTab } from './settings/PremiumTab'
import './SettingsModal.scss'

/**
 * Settings Modal Component
 *
 * Provides a tabbed interface for user settings management
 * Each tab is a separate component for better maintainability
 *
 * @param {Object} props
 * @param {string} props.modalId - Unique modal identifier
 * @param {Function} props.onClose - Callback when modal closes
 */
export default function SettingsModal({ modalId, onClose }) {
  const [activeTab, setActiveTab] = useState('account')

  const tabs = [
    { id: 'account', label: '👤 Account', component: AccountSettingsTab },
    { id: 'characters', label: '🎭 Characters', component: CharacterSettingsTab },
    { id: 'ai-settings', label: '🤖 AI Settings', component: AISettingsTab },
    { id: 'chat-settings', label: '💬 Chat', component: ChatSettingsTab },
    { id: 'preferences', label: '⚙️ Preferences', component: PreferencesTab },
    { id: 'data', label: '📊 Data & Privacy', component: DataPrivacyTab },
    { id: 'premium', label: '✨ Premium', component: PremiumTab }
  ]

  const activeTabComponent = tabs.find(t => t.id === activeTab)?.component

  return (
    <div className="modal-overlay" onClick={onClose}>
      <div className="modal-content settings-modal" onClick={(e) => e.stopPropagation()}>
        <div className="modal-header">
          <h2>Settings</h2>
          <button className="modal-close" onClick={onClose}>
            ✕
          </button>
        </div>

        <div className="settings-container">
          {/* Sidebar Tabs */}
          <div className="settings-sidebar">
            {tabs.map((tab) => (
              <button
                key={tab.id}
                className={`settings-tab ${activeTab === tab.id ? 'active' : ''}`}
                onClick={() => setActiveTab(tab.id)}
              >
                {tab.label}
              </button>
            ))}
          </div>

          {/* Content Area */}
          <div className="settings-content">
            {activeTabComponent && (
              <>
                {/* Dynamically render the active tab component */}
                {activeTabComponent({})}
              </>
            )}
          </div>
        </div>
      </div>
    </div>
  )
}
```

---

## Integration Checklist

Use this checklist to track your refactoring progress:

- [ ] Context Splitting (UIContext → 3 contexts)
  - [ ] Create NavigationContext
  - [ ] Create ModalContext
  - [ ] Create NotificationContext
  - [ ] Update App.jsx providers
  - [ ] Update useModal hook
  - [ ] Update useNotification hook
  - [ ] Remove old UIContext
  - [ ] Test all modals and navigation

- [ ] Query Cache Implementation
  - [ ] Create queryCache.js
  - [ ] Create useQuery hook
  - [ ] Update ChatPage to use useQuery
  - [ ] Update Sidebar to use useQuery
  - [ ] Remove manual fetchConversations calls
  - [ ] Test cache deduplication
  - [ ] Test cache TTL expiration

- [ ] Error Standardization
  - [ ] Create ApiError class
  - [ ] Update client.js interceptor
  - [ ] Update all API services to use ApiError
  - [ ] Update error handling in contexts
  - [ ] Test error flows

- [ ] SettingsModal Refactoring
  - [ ] Create AISettingsTab
  - [ ] Create ChatSettingsTab
  - [ ] Create PreferencesTab
  - [ ] Create DataPrivacyTab
  - [ ] Create PremiumTab
  - [ ] Create usePremium hook
  - [ ] Create useCharacterManagement hook
  - [ ] Refactor SettingsModal
  - [ ] Test all tabs

- [ ] Constants Configuration
  - [ ] Create constants.js
  - [ ] Replace all magic numbers
  - [ ] Update imports in components
  - [ ] Document all constants

- [ ] Testing
  - [ ] Add tests for new contexts
  - [ ] Add tests for useQuery hook
  - [ ] Add tests for SettingsModal tabs
  - [ ] Add tests for ApiError

