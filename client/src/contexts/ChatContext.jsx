import { createContext, useReducer, useCallback, useRef } from 'react'
import CircuitBreaker from '@/utils/circuitBreaker'
import { chatAPI } from '@/services/chatAPI'

/**
 * Chat Context
 * Manages chat messages, conversations, and conversation state
 * Handles pagination, loading states, and error handling
 * ARCHITECTURAL FIX: Provides memoized fetch functions with circuit breaker
 */

export const ChatContext = createContext()

const initialState = {
  conversations: [],
  activeConversationId: null,
  messages: [],
  isLoadingConversations: false,
  isLoadingMessages: false,
  messageError: null,
  conversationError: null,
  typingIndicator: {
    isVisible: false,
    characterName: ''
  },
  pagination: {
    page: 0,
    pageSize: 50,
    hasMore: false,
    total: 0
  }
}

const ACTIONS = {
  SET_LOADING_CONVERSATIONS: 'SET_LOADING_CONVERSATIONS',
  SET_LOADING_MESSAGES: 'SET_LOADING_MESSAGES',
  SET_CONVERSATIONS: 'SET_CONVERSATIONS',
  SET_ACTIVE_CONVERSATION: 'SET_ACTIVE_CONVERSATION',
  SET_MESSAGES: 'SET_MESSAGES',
  ADD_MESSAGE: 'ADD_MESSAGE',
  PREPEND_MESSAGES: 'PREPEND_MESSAGES',
  UPDATE_MESSAGE: 'UPDATE_MESSAGE',
  DELETE_MESSAGE: 'DELETE_MESSAGE',
  DELETE_CONVERSATION: 'DELETE_CONVERSATION',
  SET_TYPING: 'SET_TYPING',
  CLEAR_TYPING: 'CLEAR_TYPING',
  SET_MESSAGE_ERROR: 'SET_MESSAGE_ERROR',
  SET_CONVERSATION_ERROR: 'SET_CONVERSATION_ERROR',
  CLEAR_ERRORS: 'CLEAR_ERRORS',
  SET_PAGINATION: 'SET_PAGINATION'
}

function chatReducer(state, action) {
  switch (action.type) {
    case ACTIONS.SET_LOADING_CONVERSATIONS:
      return { ...state, isLoadingConversations: action.payload }

    case ACTIONS.SET_LOADING_MESSAGES:
      return { ...state, isLoadingMessages: action.payload }

    case ACTIONS.SET_CONVERSATIONS:
      return { ...state, conversations: action.payload }

    case ACTIONS.SET_ACTIVE_CONVERSATION:
      return {
        ...state,
        activeConversationId: action.payload,
        messages: [],
        pagination: { ...initialState.pagination }
      }

    case ACTIONS.SET_MESSAGES:
      return {
        ...state,
        messages: action.payload.messages,
        pagination: {
          ...state.pagination,
          page: action.payload.page || 0,
          total: action.payload.total || 0,
          hasMore: action.payload.hasMore || false
        }
      }

    case ACTIONS.ADD_MESSAGE:
      return {
        ...state,
        messages: [...state.messages, action.payload]
      }

    case ACTIONS.PREPEND_MESSAGES:
      return {
        ...state,
        messages: [...action.payload, ...state.messages],
        pagination: {
          ...state.pagination,
          page: state.pagination.page + 1,
          hasMore: action.payload.length === state.pagination.pageSize
        }
      }

    case ACTIONS.UPDATE_MESSAGE:
      // FIX 7: Handle message ID persistence - replace temp IDs with server IDs
      return {
        ...state,
        messages: state.messages.map((msg) => {
          if (msg.id === action.payload.id) {
            // If updating with new ID, remove old message and update with new ID
            if (action.payload.updates.id && action.payload.updates.id !== msg.id) {
              return { ...msg, ...action.payload.updates }
            }
            return { ...msg, ...action.payload.updates }
          }
          return msg
        })
      }

    case ACTIONS.DELETE_MESSAGE:
      return {
        ...state,
        messages: state.messages.filter((msg) => msg.id !== action.payload)
      }

    case ACTIONS.DELETE_CONVERSATION:
      return {
        ...state,
        conversations: state.conversations.filter(
          (conv) => conv.id !== action.payload
        ),
        activeConversationId:
          state.activeConversationId === action.payload ? null : state.activeConversationId,
        messages: state.activeConversationId === action.payload ? [] : state.messages
      }

    case ACTIONS.SET_TYPING:
      return {
        ...state,
        typingIndicator: {
          isVisible: true,
          characterName: action.payload
        }
      }

    case ACTIONS.CLEAR_TYPING:
      return {
        ...state,
        typingIndicator: { isVisible: false, characterName: '' }
      }

    case ACTIONS.SET_MESSAGE_ERROR:
      return { ...state, messageError: action.payload }

    case ACTIONS.SET_CONVERSATION_ERROR:
      return { ...state, conversationError: action.payload }

    case ACTIONS.CLEAR_ERRORS:
      return { ...state, messageError: null, conversationError: null }

    case ACTIONS.SET_PAGINATION:
      return {
        ...state,
        pagination: { ...state.pagination, ...action.payload }
      }

    default:
      return state
  }
}

export function ChatProvider({ children }) {
  const [state, dispatch] = useReducer(chatReducer, initialState)

  // Circuit breaker for API calls - prevents infinite retry loops
  const circuitBreakerRef = useRef(new CircuitBreaker({
    failureThreshold: 5,
    resetTimeout: 30000,
    name: 'ChatAPI'
  }))

  const setLoadingConversations = useCallback((loading) => {
    dispatch({ type: ACTIONS.SET_LOADING_CONVERSATIONS, payload: loading })
  }, [])

  const setLoadingMessages = useCallback((loading) => {
    dispatch({ type: ACTIONS.SET_LOADING_MESSAGES, payload: loading })
  }, [])

  const setConversations = useCallback((conversations) => {
    dispatch({ type: ACTIONS.SET_CONVERSATIONS, payload: conversations })
  }, [])

  const setActiveConversation = useCallback((conversationId) => {
    dispatch({ type: ACTIONS.SET_ACTIVE_CONVERSATION, payload: conversationId })
  }, [])

  const setMessages = useCallback((messages, page, total, hasMore) => {
    dispatch({
      type: ACTIONS.SET_MESSAGES,
      payload: { messages, page, total, hasMore }
    })
  }, [])

  const addMessage = useCallback((message) => {
    dispatch({ type: ACTIONS.ADD_MESSAGE, payload: message })
  }, [])

  const prependMessages = useCallback((messages) => {
    dispatch({ type: ACTIONS.PREPEND_MESSAGES, payload: messages })
  }, [])

  const updateMessage = useCallback((messageId, updates) => {
    dispatch({ type: ACTIONS.UPDATE_MESSAGE, payload: { id: messageId, updates } })
  }, [])

  const deleteMessage = useCallback((messageId) => {
    dispatch({ type: ACTIONS.DELETE_MESSAGE, payload: messageId })
  }, [])

  const deleteConversation = useCallback((conversationId) => {
    dispatch({ type: ACTIONS.DELETE_CONVERSATION, payload: conversationId })
  }, [])

  const setTyping = useCallback((characterName) => {
    dispatch({ type: ACTIONS.SET_TYPING, payload: characterName })
  }, [])

  const clearTyping = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_TYPING })
  }, [])

  const setMessageError = useCallback((error) => {
    dispatch({ type: ACTIONS.SET_MESSAGE_ERROR, payload: error })
  }, [])

  const setConversationError = useCallback((error) => {
    dispatch({ type: ACTIONS.SET_CONVERSATION_ERROR, payload: error })
  }, [])

  const clearErrors = useCallback(() => {
    dispatch({ type: ACTIONS.CLEAR_ERRORS })
  }, [])

  const setPagination = useCallback((pagination) => {
    dispatch({ type: ACTIONS.SET_PAGINATION, payload: pagination })
  }, [])

  // ARCHITECTURAL FIX: Memoized API wrapper functions with circuit breaker
  // These have STABLE references - won't cause infinite loops in useEffect
  const fetchConversations = useCallback(async () => {
    setLoadingConversations(true)
    try {
      const conversations = await circuitBreakerRef.current.execute(async () => {
        return await chatAPI.getConversations()
      })
      setConversations(conversations)
      return conversations
    } catch (error) {
      // Only log error once, don't spam console
      if (!error.circuitOpen) {
        console.error('[ChatContext] Failed to fetch conversations:', error.message)
      }
      setConversationError(error.message)
      throw error
    } finally {
      setLoadingConversations(false)
    }
  }, [setLoadingConversations, setConversations, setConversationError])

  const fetchMessages = useCallback(async (conversationId, page = 0) => {
    setLoadingMessages(true)
    try {
      const result = await circuitBreakerRef.current.execute(async () => {
        return await chatAPI.getMessages(conversationId, page, state.pagination.pageSize)
      })
      if (page === 0) {
        setMessages(result.messages, page, result.total, result.hasMore)
      } else {
        prependMessages(result.messages)
      }
      return result
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[ChatContext] Failed to fetch messages:', error.message)
      }
      setMessageError(error.message)
      throw error
    } finally {
      setLoadingMessages(false)
    }
  }, [setLoadingMessages, setMessages, prependMessages, setMessageError, state.pagination.pageSize])

  const startConversation = useCallback(async (characterId) => {
    setLoadingConversations(true)
    try {
      const conversation = await circuitBreakerRef.current.execute(async () => {
        return await chatAPI.startConversation(characterId)
      })
      setConversations([conversation, ...state.conversations])
      setActiveConversation(conversation.id)
      setMessages([], 0, 0, false)
      return conversation
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[ChatContext] Failed to start conversation:', error.message)
      }
      setConversationError(error.message)
      throw error
    } finally {
      setLoadingConversations(false)
    }
  }, [setLoadingConversations, setConversations, setActiveConversation, setMessages, setConversationError, state.conversations])

  const sendMessage = useCallback(async (content, fileUrl = null, characterMetadata = {}) => {
    if (!state.activeConversationId) {
      throw new Error('No active conversation')
    }

    // Optimistic update
    const tempMessageId = `temp-${Date.now()}`
    const optimisticMessage = {
      id: tempMessageId,
      conversationId: state.activeConversationId,
      role: 'user',
      content,
      fileUrl,
      timestamp: new Date(),
      isOptimistic: true
    }

    addMessage(optimisticMessage)

    try {
      setTyping('...')

      // Build conversation history from current messages
      const history = state.messages
        .filter(msg => !msg.isOptimistic)
        .slice(-20)
        .map(msg => ({
          role: msg.role,
          content: msg.content
        }))

      const metadata = {
        ...characterMetadata,
        history: history
      }

      const response = await circuitBreakerRef.current.execute(async () => {
        return await chatAPI.sendMessage(
          state.activeConversationId,
          content,
          fileUrl,
          metadata
        )
      })

      // Replace optimistic message with real message
      updateMessage(tempMessageId, {
        id: response.message.id,
        timestamp: response.message.timestamp,
        isOptimistic: false
      })

      // Add character response
      if (response.response) {
        addMessage(response.response)
      }

      clearTyping()
      return response.message
    } catch (error) {
      // Remove optimistic message on error
      deleteMessage(tempMessageId)
      if (!error.circuitOpen) {
        console.error('[ChatContext] Failed to send message:', error.message)
      }
      setMessageError(error.message)
      clearTyping()
      throw error
    }
  }, [state.activeConversationId, state.messages, addMessage, setTyping, updateMessage, clearTyping, deleteMessage, setMessageError])

  const deleteMessageById = useCallback(async (messageId) => {
    if (!state.activeConversationId) {
      throw new Error('No active conversation')
    }

    try {
      await circuitBreakerRef.current.execute(async () => {
        return await chatAPI.deleteMessage(state.activeConversationId, messageId)
      })
      deleteMessage(messageId)
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[ChatContext] Failed to delete message:', error.message)
      }
      setMessageError(error.message)
      throw error
    }
  }, [state.activeConversationId, deleteMessage, setMessageError])

  const deleteConversationById = useCallback(async (conversationId) => {
    try {
      await circuitBreakerRef.current.execute(async () => {
        return await chatAPI.deleteConversation(conversationId)
      })
      deleteConversation(conversationId)
    } catch (error) {
      if (!error.circuitOpen) {
        console.error('[ChatContext] Failed to delete conversation:', error.message)
      }
      setConversationError(error.message)
      throw error
    }
  }, [deleteConversation, setConversationError])

  const value = {
    // State
    ...state,

    // Methods
    setLoadingConversations,
    setLoadingMessages,
    setConversations,
    setActiveConversation,
    setMessages,
    addMessage,
    prependMessages,
    updateMessage,
    deleteMessage,
    deleteConversation,
    setTyping,
    clearTyping,
    setMessageError,
    setConversationError,
    clearErrors,
    setPagination,

    // ARCHITECTURAL FIX: Memoized API wrappers (stable references)
    fetchConversations,
    fetchMessages,
    startConversation,
    sendMessage,
    deleteMessageById,
    deleteConversationById
  }

  return <ChatContext.Provider value={value}>{children}</ChatContext.Provider>
}
