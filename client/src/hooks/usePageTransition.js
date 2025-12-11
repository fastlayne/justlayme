import { useContext } from 'react'
import { PageTransitionContext } from '@/contexts/PageTransitionContext'

export function usePageTransition() {
  const context = useContext(PageTransitionContext)

  if (!context) {
    throw new Error('usePageTransition must be used within PageTransitionProvider')
  }

  return context
}
