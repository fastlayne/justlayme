import { createContext, useState, useCallback } from 'react'

export const PageTransitionContext = createContext()

export function PageTransitionProvider({ children }) {
  const [isTransitioning, setIsTransitioning] = useState(false)
  const [nextPath, setNextPath] = useState(null)

  const startTransition = useCallback((targetPath) => {
    setNextPath(targetPath)
    setIsTransitioning(true)
  }, [])

  const endTransition = useCallback(() => {
    setIsTransitioning(false)
    setNextPath(null)
  }, [])

  return (
    <PageTransitionContext.Provider
      value={{
        isTransitioning,
        nextPath,
        startTransition,
        endTransition,
      }}
    >
      {children}
    </PageTransitionContext.Provider>
  )
}
