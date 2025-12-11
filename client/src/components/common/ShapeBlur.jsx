import { useEffect, useState } from 'react'
import './ShapeBlur.scss'

/**
 * ShapeBlur Component
 * Animated blur shapes for glassmorphic effects around containers
 * Creates premium animated blur border effect
 *
 * Features:
 * - Animated gradient blur shapes
 * - Customizable border thickness
 * - Responsive to container size
 * - "Thinnest" setting for subtle effects
 */

export function ShapeBlur({ children, thickness = 'thin' }) {
  const [isAnimating, setIsAnimating] = useState(true)

  useEffect(() => {
    setIsAnimating(true)
  }, [])

  return (
    <div className={`shape-blur-wrapper ${thickness}`}>
      {/* Animated blur shapes */}
      <div className="blur-shapes">
        <div className="blur-shape blur-shape-1" />
        <div className="blur-shape blur-shape-2" />
        <div className="blur-shape blur-shape-3" />
      </div>

      {/* Content */}
      <div className="shape-blur-content">
        {children}
      </div>
    </div>
  )
}

export default ShapeBlur
