import { useContext } from 'react'
import { ChatContext } from '@/contexts/ChatContext'

/**
 * useChat Hook
 * Provides chat operations and state
 * Handles message sending, conversation management, pagination
 * ARCHITECTURAL FIX: Returns stable memoized functions from context
 * This prevents infinite loops in useEffect dependencies
 */

export function useChat() {
  const context = useContext(ChatContext)

  if (!context) {
    throw new Error('useChat must be used within ChatProvider')
  }

  return {
    // State
    conversations: context.conversations,
    activeConversationId: context.activeConversationId,
    messages: context.messages,
    isLoadingMessages: context.isLoadingMessages,
    isLoadingConversations: context.isLoadingConversations,
    messageError: context.messageError,
    conversationError: context.conversationError,
    typingIndicator: context.typingIndicator,
    pagination: context.pagination,

    // Methods
    setLoadingConversations: context.setLoadingConversations,
    setLoadingMessages: context.setLoadingMessages,
    setConversations: context.setConversations,
    setActiveConversation: context.setActiveConversation,
    setMessages: context.setMessages,
    addMessage: context.addMessage,
    prependMessages: context.prependMessages,
    updateMessage: context.updateMessage,
    deleteMessage: context.deleteMessage,
    deleteConversation: context.deleteConversation,
    setTyping: context.setTyping,
    clearTyping: context.clearTyping,
    setMessageError: context.setMessageError,
    setConversationError: context.setConversationError,
    clearErrors: context.clearErrors,
    setPagination: context.setPagination,

    // ARCHITECTURAL FIX: Return stable memoized functions from context
    // These have stable references and won't cause infinite loops
    fetchConversations: context.fetchConversations,
    fetchMessages: context.fetchMessages,
    startConversation: context.startConversation,
    sendMessage: context.sendMessage,
    deleteMessageById: context.deleteMessageById,
    deleteConversationById: context.deleteConversationById
  }
}
