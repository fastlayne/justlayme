import { useState, useEffect } from 'react'
import { motion } from 'motion/react'
import './StarBorder.scss'

/**
 * StarBorder Component
 * Animated star particles that dance around element borders
 * Creates a premium, glamorous effect for buttons and cards
 *
 * Features:
 * - Animated star particles orbiting element borders
 * - Customizable star count and colors
 * - Performance optimized with motion library
 * - Automatic size detection for responsive borders
 */

export function StarBorder({ children, starColor = '#06b6d4', starCount = 12 }) {
  const [containerRef, setContainerRef] = useState(null)
  const [dimensions, setDimensions] = useState({ width: 0, height: 0 })

  // Track container dimensions for star positioning
  useEffect(() => {
    if (!containerRef) return

    const updateDimensions = () => {
      setDimensions({
        width: containerRef.offsetWidth,
        height: containerRef.offsetHeight
      })
    }

    updateDimensions()

    const observer = new ResizeObserver(updateDimensions)
    observer.observe(containerRef)

    return () => observer.disconnect()
  }, [containerRef])

  // Generate star positions around the perimeter
  const generateStarPositions = (index, total) => {
    const angle = (index / total) * Math.PI * 2
    const radius = Math.max(dimensions.width, dimensions.height) / 2 + 15

    return {
      x: Math.cos(angle) * radius + dimensions.width / 2,
      y: Math.sin(angle) * radius + dimensions.height / 2,
      angle
    }
  }

  const stars = Array.from({ length: starCount }, (_, i) => i)

  return (
    <div className="star-border-container" ref={setContainerRef}>
      {/* Star particles container */}
      <div className="star-border-wrapper" style={{
        width: `${dimensions.width}px`,
        height: `${dimensions.height}px`
      }}>
        {stars.map((index) => {
          const position = generateStarPositions(index, starCount)
          const delay = (index / starCount) * 2

          return (
            <motion.div
              key={index}
              className="star"
              animate={{
                x: [
                  position.x - dimensions.width / 2,
                  (position.x - dimensions.width / 2) * 1.1,
                  position.x - dimensions.width / 2
                ],
                y: [
                  position.y - dimensions.height / 2,
                  (position.y - dimensions.height / 2) * 1.1,
                  position.y - dimensions.height / 2
                ],
                opacity: [0, 1, 0.5, 1, 0],
                scale: [0.5, 1, 1.2, 1, 0.5]
              }}
              transition={{
                duration: 4,
                delay,
                repeat: Infinity,
                ease: 'easeInOut'
              }}
              style={{
                color: starColor,
                left: `${dimensions.width / 2}px`,
                top: `${dimensions.height / 2}px`
              }}
            >
              ✦
            </motion.div>
          )
        })}
      </div>

      {/* Animated border effect */}
      <svg className="star-border-svg" viewBox={`0 0 ${dimensions.width} ${dimensions.height}`}>
        <defs>
          <linearGradient id="star-border-gradient" x1="0%" y1="0%" x2="100%" y2="100%">
            <stop offset="0%" stopColor={starColor} stopOpacity="0.3" />
            <stop offset="50%" stopColor={starColor} stopOpacity="0.6" />
            <stop offset="100%" stopColor={starColor} stopOpacity="0.3" />
          </linearGradient>

          <filter id="star-glow">
            <feGaussianBlur stdDeviation="2" result="coloredBlur" />
            <feMerge>
              <feMergeNode in="coloredBlur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
        </defs>

        {/* Top border */}
        <motion.line
          x1="0"
          y1="0"
          x2={dimensions.width}
          y2="0"
          stroke="url(#star-border-gradient)"
          strokeWidth="2"
          filter="url(#star-glow)"
          initial={{ strokeDashoffset: dimensions.width * 2 }}
          animate={{ strokeDashoffset: 0 }}
          transition={{
            duration: 3,
            repeat: Infinity,
            ease: 'linear'
          }}
          style={{ strokeDasharray: dimensions.width * 2 }}
        />

        {/* Right border */}
        <motion.line
          x1={dimensions.width}
          y1="0"
          x2={dimensions.width}
          y2={dimensions.height}
          stroke="url(#star-border-gradient)"
          strokeWidth="2"
          filter="url(#star-glow)"
          initial={{ strokeDashoffset: dimensions.height * 2 }}
          animate={{ strokeDashoffset: 0 }}
          transition={{
            duration: 3,
            delay: 0.75,
            repeat: Infinity,
            ease: 'linear'
          }}
          style={{ strokeDasharray: dimensions.height * 2 }}
        />

        {/* Bottom border */}
        <motion.line
          x1={dimensions.width}
          y1={dimensions.height}
          x2="0"
          y2={dimensions.height}
          stroke="url(#star-border-gradient)"
          strokeWidth="2"
          filter="url(#star-glow)"
          initial={{ strokeDashoffset: dimensions.width * 2 }}
          animate={{ strokeDashoffset: 0 }}
          transition={{
            duration: 3,
            delay: 1.5,
            repeat: Infinity,
            ease: 'linear'
          }}
          style={{ strokeDasharray: dimensions.width * 2 }}
        />

        {/* Left border */}
        <motion.line
          x1="0"
          y1={dimensions.height}
          x2="0"
          y2="0"
          stroke="url(#star-border-gradient)"
          strokeWidth="2"
          filter="url(#star-glow)"
          initial={{ strokeDashoffset: dimensions.height * 2 }}
          animate={{ strokeDashoffset: 0 }}
          transition={{
            duration: 3,
            delay: 2.25,
            repeat: Infinity,
            ease: 'linear'
          }}
          style={{ strokeDasharray: dimensions.height * 2 }}
        />
      </svg>

      {/* Content */}
      {children}
    </div>
  )
}

export default StarBorder
