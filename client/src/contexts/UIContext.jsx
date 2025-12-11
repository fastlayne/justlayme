import { createContext, useReducer, useCallback, useState, useEffect } from 'react'

/**
 * UI Context
 * Manages modal stack, sidebar state, notifications, and UI preferences
 * ARCHITECTURAL FIX: Added initialization state to prevent race conditions
 */

export const UIContext = createContext(null)

// ARCHITECTURAL FIX: Check if mobile on initialization to set correct sidebar state
const isMobileInitial = typeof window !== 'undefined' && window.innerWidth < 768

const initialState = {
  sidebarOpen: !isMobileInitial, // Close sidebar by default on mobile
  isMobileView: isMobileInitial,
  modalStack: [],
  notificationQueue: [],
  selectedTab: 'chat'
}

const ACTIONS = {
  TOGGLE_SIDEBAR: 'TOGGLE_SIDEBAR',
  SET_SIDEBAR_OPEN: 'SET_SIDEBAR_OPEN',
  SET_MOBILE_VIEW: 'SET_MOBILE_VIEW',
  OPEN_MODAL: 'OPEN_MODAL',
  CLOSE_MODAL: 'CLOSE_MODAL',
  CLOSE_ALL_MODALS: 'CLOSE_ALL_MODALS',
  UPDATE_MODAL_DATA: 'UPDATE_MODAL_DATA',
  ADD_NOTIFICATION: 'ADD_NOTIFICATION',
  REMOVE_NOTIFICATION: 'REMOVE_NOTIFICATION',
  SET_SELECTED_TAB: 'SET_SELECTED_TAB'
}

function uiReducer(state, action) {
  switch (action.type) {
    case ACTIONS.TOGGLE_SIDEBAR:
      return { ...state, sidebarOpen: !state.sidebarOpen }

    case ACTIONS.SET_SIDEBAR_OPEN:
      return { ...state, sidebarOpen: action.payload }

    case ACTIONS.SET_MOBILE_VIEW:
      return { ...state, isMobileView: action.payload }

    case ACTIONS.OPEN_MODAL:
      // ARCHITECTURAL FIX: Prevent duplicate modals of the same type
      // Check if a modal of this type is already open
      const existingModal = state.modalStack.find(m => m.type === action.payload.type)

      if (existingModal) {
        // If modal of same type exists, update its data instead of creating a new one
        return {
          ...state,
          modalStack: state.modalStack.map(m =>
            m.type === action.payload.type
              ? { ...m, data: action.payload.data || {} }
              : m
          )
        }
      }

      // Otherwise, add the new modal to the stack
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

    case ACTIONS.CLOSE_MODAL:
      return {
        ...state,
        modalStack: state.modalStack.filter((m) => m.id !== action.payload)
      }

    case ACTIONS.CLOSE_ALL_MODALS:
      return { ...state, modalStack: [] }

    case ACTIONS.UPDATE_MODAL_DATA:
      return {
        ...state,
        modalStack: state.modalStack.map((m) =>
          m.id === action.payload.id
            ? { ...m, data: { ...m.data, ...action.payload.data } }
            : m
        )
      }

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
          (n) => n.id !== action.payload
        )
      }

    case ACTIONS.SET_SELECTED_TAB:
      return { ...state, selectedTab: action.payload }

    default:
      return state
  }
}

export function UIProvider({ children }) {
  const [state, dispatch] = useReducer(uiReducer, initialState)
  const [isInitialized, setIsInitialized] = useState(false)

  // ARCHITECTURAL FIX: Ensure context is fully initialized before rendering children
  useEffect(() => {
    setIsInitialized(true)
  }, [])

  const toggleSidebar = useCallback(() => {
    dispatch({ type: ACTIONS.TOGGLE_SIDEBAR })
  }, [])

  const setSidebarOpen = useCallback((open) => {
    dispatch({ type: ACTIONS.SET_SIDEBAR_OPEN, payload: open })
  }, [])

  const setMobileView = useCallback((isMobile) => {
    dispatch({ type: ACTIONS.SET_MOBILE_VIEW, payload: isMobile })
  }, [])

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

  const addNotification = useCallback((message, type = 'info', duration = 3000) => {
    const id = `notification-${Date.now()}`
    dispatch({
      type: ACTIONS.ADD_NOTIFICATION,
      payload: { id, message, type, duration }
    })

    // Auto-remove notification after duration
    if (duration > 0) {
      setTimeout(() => {
        dispatch({ type: ACTIONS.REMOVE_NOTIFICATION, payload: id })
      }, duration)
    }

    return id
  }, [])

  const removeNotification = useCallback((id) => {
    dispatch({ type: ACTIONS.REMOVE_NOTIFICATION, payload: id })
  }, [])

  const setSelectedTab = useCallback((tab) => {
    dispatch({ type: ACTIONS.SET_SELECTED_TAB, payload: tab })
  }, [])

  const value = {
    // State
    ...state,
    isInitialized,

    // Methods
    toggleSidebar,
    setSidebarOpen,
    setMobileView,
    openModal,
    closeModal,
    closeAllModals,
    updateModalData,
    addNotification,
    removeNotification,
    setSelectedTab
  }

  // ARCHITECTURAL FIX: Only render children when context is fully initialized
  // This prevents race conditions with lazy-loaded components
  if (!isInitialized) {
    return (
      <div style={{
        display: 'flex',
        justifyContent: 'center',
        alignItems: 'center',
        height: '100vh',
        background: 'linear-gradient(135deg, #0f0f23 0%, #1a1a2e 100%)',
        color: '#fff'
      }}>
        <div style={{ textAlign: 'center' }}>
          <div style={{ fontSize: '2rem', marginBottom: '1rem' }}>⚡</div>
          <div>Initializing...</div>
        </div>
      </div>
    )
  }

  return <UIContext.Provider value={value}>{children}</UIContext.Provider>
}
