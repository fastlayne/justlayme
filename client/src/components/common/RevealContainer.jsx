import React from 'react'
import { useScrollReveal } from '@/hooks/useScrollReveal'
import './RevealContainer.css'

/**
 * RevealContainer Component
 * Materializes from nowhere as user scrolls
 * Multiple animation variants for different effects
 */

const RevealContainer = ({
  children,
  variant = 'fade-up',
  delay = 0,
  threshold = 0.1,
  className = '',
}) => {
  const [ref, isVisible] = useScrollReveal({ threshold, triggerOnce: true })

  return (
    <div
      ref={ref}
      className={`reveal-container ${variant} ${isVisible ? 'revealed' : ''} ${className}`}
      style={{ '--reveal-delay': `${delay}ms` }}
    >
      {children}
    </div>
  )
}

export default RevealContainer
