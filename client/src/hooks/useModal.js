import { useContext, useCallback, useRef } from 'react'
import { UIContext } from '@/contexts/UIContext'

/**
 * useModal Hook
 * Modal management for specific modal types
 * ARCHITECTURAL FIX: Added debouncing to prevent rapid clicking
 */

export function useModal(modalType) {
  const context = useContext(UIContext)
  const lastOpenTime = useRef(0)

  if (!context) {
    throw new Error('useModal must be used within UIProvider')
  }

  const modal = context.modalStack.find((m) => m.type === modalType)

  const openModal = useCallback(
    (data, id) => {
      // ARCHITECTURAL FIX: Debounce rapid clicks (500ms minimum between opens)
      const now = Date.now()
      if (now - lastOpenTime.current < 500) {
        console.log('[useModal] Debounced rapid modal open attempt')
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
