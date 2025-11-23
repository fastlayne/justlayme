import { useContext, useEffect, useState } from 'react'
import { UIContext } from '@/contexts/UIContext'

/**
 * useSidebar Hook
 * Sidebar state management and responsive behavior
 * ARCHITECTURAL FIX: Gracefully handles lazy-loaded component context timing
 */

export function useSidebar() {
  const context = useContext(UIContext)
  const [isMobileState, setIsMobileState] = useState(window.innerWidth < 768)

  // ARCHITECTURAL FIX: Provide safe defaults during initialization
  // This prevents crashes while UIProvider is initializing
  if (!context) {
    console.warn('[useSidebar] UIContext not yet available, using safe defaults')
    return {
      isOpen: false,
      isMobile: isMobileState,
      isTablet: false,
      isDesktop: false,
      toggle: () => console.warn('[useSidebar] Toggle called before context ready'),
      open: () => console.warn('[useSidebar] Open called before context ready'),
      close: () => console.warn('[useSidebar] Close called before context ready')
    }
  }

  // Handle window resize for responsive sidebar
  useEffect(() => {
    const handleResize = () => {
      const isMobile = window.innerWidth < 768
      setIsMobileState(isMobile)
      context.setMobileView(isMobile)

      // Auto-close sidebar on mobile if open
      if (isMobile && context.sidebarOpen) {
        context.setSidebarOpen(false)
      }
    }

    window.addEventListener('resize', handleResize)
    handleResize() // Initial check

    return () => window.removeEventListener('resize', handleResize)
  }, [context])

  return {
    isOpen: context.sidebarOpen,
    isMobile: context.isMobileView,
    isTablet: window.innerWidth >= 768 && window.innerWidth < 1024,
    isDesktop: window.innerWidth >= 1024,
    toggle: context.toggleSidebar,
    open: () => context.setSidebarOpen(true),
    close: () => context.setSidebarOpen(false)
  }
}
