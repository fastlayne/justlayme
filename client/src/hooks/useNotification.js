import { useContext, useCallback } from 'react'
import { UIContext } from '@/contexts/UIContext'

/**
 * useNotification Hook
 * Notification management
 */

export function useNotification() {
  const context = useContext(UIContext)

  if (!context) {
    throw new Error('useNotification must be used within UIProvider')
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
