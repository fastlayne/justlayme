import React from 'react'
import './Beams.css'

/**
 * Beams Component
 * Animated light rays background
 * Inspired by react-bits design patterns
 */

const Beams = ({
  direction = 'vertical', // vertical (from top) or horizontal (from left)
  color = 'rgba(6, 182, 212, 0.15)',
  beamCount = 8,
  className = '',
}) => {
  const beams = Array.from({ length: beamCount }, (_, i) => i)

  return (
    <div className={`beams-container beams-${direction} ${className}`}>
      {beams.map((beam) => (
        <div
          key={beam}
          className="beam"
          style={{
            '--beam-index': beam,
            '--beam-color': color,
            '--beam-delay': `${beam * 0.3}s`,
            '--beam-duration': `${4 + beam * 0.5}s`,
          }}
        />
      ))}
      <div className="beams-glow" />
    </div>
  )
}

export default Beams
