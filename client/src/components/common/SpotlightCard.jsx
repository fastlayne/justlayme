import React, { useRef, useState } from 'react'
import './SpotlightCard.css'

/**
 * SpotlightCard Component
 * Elegant card with dynamic spotlight effect following mouse
 * Inspired by react-bits design patterns
 */

const SpotlightCard = ({
  children,
  className = '',
  spotlightColor = 'rgba(255, 255, 255, 0.25)',
  spotlightSize = 300,
}) => {
  const cardRef = useRef(null)
  const [spotlightPosition, setSpotlightPosition] = useState({ x: 50, y: 50 })
  const [isHovering, setIsHovering] = useState(false)

  const handleMouseMove = (e) => {
    if (!cardRef.current) return

    const rect = cardRef.current.getBoundingClientRect()
    const x = ((e.clientX - rect.left) / rect.width) * 100
    const y = ((e.clientY - rect.top) / rect.height) * 100

    setSpotlightPosition({ x, y })
  }

  return (
    <div
      ref={cardRef}
      className={`spotlight-card ${className}`}
      onMouseMove={handleMouseMove}
      onMouseEnter={() => setIsHovering(true)}
      onMouseLeave={() => setIsHovering(false)}
      style={{
        '--spotlight-x': `${spotlightPosition.x}%`,
        '--spotlight-y': `${spotlightPosition.y}%`,
        '--spotlight-opacity': isHovering ? '1' : '0',
        '--spotlight-color': spotlightColor,
        '--spotlight-size': `${spotlightSize}px`,
      }}
    >
      <div className="spotlight-card-spotlight" />
      <div className="spotlight-card-content">{children}</div>
    </div>
  )
}

export default SpotlightCard
