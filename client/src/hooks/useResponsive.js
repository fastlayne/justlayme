import { useState, useEffect } from 'react'

/**
 * useResponsive Hook
 * Responsive breakpoint detection
 */

export function useResponsive() {
  const [screenSize, setScreenSize] = useState({
    width: typeof window !== 'undefined' ? window.innerWidth : 0,
    height: typeof window !== 'undefined' ? window.innerHeight : 0
  })

  useEffect(() => {
    const handleResize = () => {
      setScreenSize({
        width: window.innerWidth,
        height: window.innerHeight
      })
    }

    window.addEventListener('resize', handleResize)
    return () => window.removeEventListener('resize', handleResize)
  }, [])

  return {
    width: screenSize.width,
    height: screenSize.height,
    isMobile: screenSize.width < 768,
    isTablet: screenSize.width >= 768 && screenSize.width < 1024,
    isDesktop: screenSize.width >= 1024,
    isSmallScreen: screenSize.width < 640,
    isLargeScreen: screenSize.width >= 1280,
    isPortrait: screenSize.height > screenSize.width,
    isLandscape: screenSize.width > screenSize.height
  }
}
