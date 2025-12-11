import { useContext } from 'react'
import { UIContext } from '@/contexts/UIContext'
import NeuralCharacterBuilder from './modals/NeuralCharacterBuilder'
import SettingsModal from './modals/SettingsModal'
import PremiumPaywallModal from './modals/PremiumPaywallModal'

/**
 * ModalRenderer Component
 * Renders all active modals from the modal stack
 * Should be placed at the root level of the app (in App.jsx)
 * UPDATED: Now using new NeuralCharacterBuilder instead of old CharacterCreatorModal
 */

export default function ModalRenderer() {
  const { modalStack, closeModal } = useContext(UIContext)

  if (!modalStack || modalStack.length === 0) {
    return null
  }

  const renderModal = (modal) => {
    switch (modal.type) {
      case 'character-creator':
        return (
          <NeuralCharacterBuilder
            key={modal.id}
            modalId={modal.id}
            onClose={() => closeModal(modal.id)}
          />
        )
      case 'settings':
        return (
          <SettingsModal
            key={modal.id}
            modalId={modal.id}
            onClose={() => closeModal(modal.id)}
          />
        )
      case 'premium-paywall':
        return (
          <PremiumPaywallModal
            key={modal.id}
            modalId={modal.id}
            onClose={() => closeModal(modal.id)}
            feature={modal.feature || 'this premium feature'}
          />
        )
      default:
        return null
    }
  }

  return <>{modalStack.map(renderModal)}</>
}
