import { useState, useRef, useEffect } from 'react'
import { useCharacters } from '@/hooks/useCharacters'
import { useChat } from '@/hooks/useChat'
import { useNotification } from '@/hooks/useNotification'
import ErrorBoundary from '@/components/ErrorBoundary'
import './NeuralCharacterBuilder.scss'

/**
 * Neural Character Builder
 * COMPLETELY NEW DESIGN: Build characters by connecting neural nodes
 * Features: Drag & drop personality nodes, glassmorphism, AI suggestions, particle system
 */

const PERSONALITY_TRAITS = [
  { id: 'creative', label: 'Creative', emoji: '🎨', color: '#8b5cf6' },
  { id: 'logical', label: 'Logical', emoji: '🧠', color: '#06b6d4' },
  { id: 'empathetic', label: 'Empathetic', emoji: '❤️', color: '#ec4899' },
  { id: 'adventurous', label: 'Adventurous', emoji: '🌟', color: '#f59e0b' },
  { id: 'mysterious', label: 'Mysterious', emoji: '🌙', color: '#6366f1' },
  { id: 'playful', label: 'Playful', emoji: '🎭', color: '#10b981' },
  { id: 'serious', label: 'Serious', emoji: '📚', color: '#64748b' },
  { id: 'flirty', label: 'Flirty', emoji: '😘', color: '#f43f5e' },
  { id: 'dominant', label: 'Dominant', emoji: '👑', color: '#dc2626' },
  { id: 'submissive', label: 'Submissive', emoji: '🦋', color: '#a78bfa' },
  { id: 'witty', label: 'Witty', emoji: '💡', color: '#fbbf24' },
  { id: 'calm', label: 'Calm', emoji: '🧘', color: '#34d399' }
]

const AI_ARCHETYPES = [
  { name: 'The Mentor', traits: ['empathetic', 'logical', 'calm'], description: 'Wise guide and advisor' },
  { name: 'The Rebel', traits: ['adventurous', 'playful', 'witty'], description: 'Free-spirited troublemaker' },
  { name: 'The Seductress', traits: ['flirty', 'mysterious', 'dominant'], description: 'Alluring enchantress' },
  { name: 'The Artist', traits: ['creative', 'empathetic', 'playful'], description: 'Passionate creative soul' }
]

export default function NeuralCharacterBuilder({ modalId, onClose }) {
  const { createCharacter } = useCharacters()
  const { startConversation } = useChat()
  const notification = useNotification()

  const [formData, setFormData] = useState({
    name: '',
    bio: '',
    avatar: '',
    personality: ''
  })

  const [selectedTraits, setSelectedTraits] = useState([])
  const [activeArchetype, setActiveArchetype] = useState(null)
  const [loading, setLoading] = useState(false)
  const [isClosing, setIsClosing] = useState(false)
  const [showAdvanced, setShowAdvanced] = useState(false)
  const canvasRef = useRef(null)

  // Neural network particle animation
  useEffect(() => {
    const canvas = canvasRef.current
    if (!canvas) return

    const ctx = canvas.getContext('2d')
    canvas.width = canvas.offsetWidth
    canvas.height = canvas.offsetHeight

    const particles = []
    const particleCount = 50
    const connectionDistance = 150

    class Particle {
      constructor() {
        this.x = Math.random() * canvas.width
        this.y = Math.random() * canvas.height
        this.vx = (Math.random() - 0.5) * 0.5
        this.vy = (Math.random() - 0.5) * 0.5
        this.radius = Math.random() * 2 + 1
      }

      update() {
        this.x += this.vx
        this.y += this.vy

        if (this.x < 0 || this.x > canvas.width) this.vx *= -1
        if (this.y < 0 || this.y > canvas.height) this.vy *= -1
      }

      draw() {
        ctx.beginPath()
        ctx.arc(this.x, this.y, this.radius, 0, Math.PI * 2)
        ctx.fillStyle = 'rgba(139, 92, 246, 0.6)'
        ctx.fill()
      }
    }

    for (let i = 0; i < particleCount; i++) {
      particles.push(new Particle())
    }

    function animate() {
      ctx.clearRect(0, 0, canvas.width, canvas.height)

      particles.forEach((particle, i) => {
        particle.update()
        particle.draw()

        // Draw connections
        particles.slice(i + 1).forEach(otherParticle => {
          const dx = particle.x - otherParticle.x
          const dy = particle.y - otherParticle.y
          const distance = Math.sqrt(dx * dx + dy * dy)

          if (distance < connectionDistance) {
            ctx.beginPath()
            ctx.moveTo(particle.x, particle.y)
            ctx.lineTo(otherParticle.x, otherParticle.y)
            ctx.strokeStyle = `rgba(139, 92, 246, ${0.2 * (1 - distance / connectionDistance)})`
            ctx.lineWidth = 0.5
            ctx.stroke()
          }
        })
      })

      requestAnimationFrame(animate)
    }

    animate()
  }, [])

  const handleTraitToggle = (traitId) => {
    setSelectedTraits(prev =>
      prev.includes(traitId)
        ? prev.filter(t => t !== traitId)
        : [...prev, traitId]
    )
    setActiveArchetype(null) // Clear archetype when manually selecting
  }

  const handleArchetypeSelect = (archetype) => {
    setActiveArchetype(archetype.name)
    setSelectedTraits(archetype.traits)
    notification.info(`Applied ${archetype.name} archetype`)
  }

  const handleChange = (e) => {
    const { name, value } = e.target
    setFormData(prev => ({ ...prev, [name]: value }))
  }

  const handleClose = () => {
    setIsClosing(true)
    setTimeout(() => {
      onClose()
      setIsClosing(false)
    }, 300)
  }

  const handleSubmit = async (e) => {
    e.preventDefault()

    if (!formData.name.trim()) {
      notification.warning('Character name is required')
      return
    }

    if (selectedTraits.length === 0) {
      notification.warning('Select at least one personality trait')
      return
    }

    setLoading(true)
    try {
      // Build personality description from selected traits
      const traitLabels = selectedTraits
        .map(id => PERSONALITY_TRAITS.find(t => t.id === id)?.label)
        .filter(Boolean)
        .join(', ')

      const personalityText = formData.personality ||
        `A ${traitLabels.toLowerCase()} character with unique personality traits`

      const characterData = {
        ...formData,
        personality: personalityText,
        traits: selectedTraits // Store for future use
      }

      const newCharacter = await createCharacter(characterData)
      notification.success(`✨ ${formData.name} has been created!`)

      try {
        await startConversation(newCharacter.id)
      } catch (conversationError) {
        console.error('Failed to start conversation:', conversationError)
        notification.warning('Character created, but failed to start conversation.')
      }

      handleClose()
      setFormData({ name: '', bio: '', avatar: '', personality: '' })
      setSelectedTraits([])
      setActiveArchetype(null)
    } catch (error) {
      console.error('Character creation error:', error)
      notification.error(error.message || 'Failed to create character')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className={`modal-overlay neural-builder-overlay ${isClosing ? 'closing' : ''}`} onClick={handleClose}>
      <div className="modal-content neural-builder" onClick={(e) => e.stopPropagation()}>
        <ErrorBoundary>
          {/* Neural network background */}
          <canvas ref={canvasRef} className="neural-canvas" />

          {/* Header */}
          <div className="neural-header">
            <div className="header-content">
              <h2 className="neural-title">
                <span className="title-icon">🧬</span>
                Neural Character Builder
              </h2>
              <p className="neural-subtitle">Design your perfect AI companion</p>
            </div>
            <button className="neural-close" onClick={handleClose}>✕</button>
          </div>

          {/* Main content */}
          <div className="neural-content">
            {/* Left: Basic Info */}
            <div className="neural-panel info-panel glass-panel">
              <h3 className="panel-title">Character Identity</h3>

              <div className="form-group neural-input-group">
                <label>Name *</label>
                <input
                  type="text"
                  name="name"
                  placeholder="Enter character name..."
                  value={formData.name}
                  onChange={handleChange}
                  disabled={loading}
                  className="neural-input"
                  autoFocus
                />
              </div>

              <div className="form-group neural-input-group">
                <label>Avatar URL</label>
                <input
                  type="url"
                  name="avatar"
                  placeholder="https://..."
                  value={formData.avatar}
                  onChange={handleChange}
                  disabled={loading}
                  className="neural-input"
                />
              </div>

              <div className="form-group neural-input-group">
                <label>Biography</label>
                <textarea
                  name="bio"
                  placeholder="Describe your character's background..."
                  value={formData.bio}
                  onChange={handleChange}
                  disabled={loading}
                  rows={4}
                  className="neural-input"
                />
              </div>

              {/* Advanced options toggle */}
              <button
                type="button"
                className="advanced-toggle"
                onClick={() => setShowAdvanced(!showAdvanced)}
              >
                {showAdvanced ? '▼' : '▶'} Advanced Options
              </button>

              {showAdvanced && (
                <div className="form-group neural-input-group">
                  <label>Custom Personality (Optional)</label>
                  <textarea
                    name="personality"
                    placeholder="Override with custom personality description..."
                    value={formData.personality}
                    onChange={handleChange}
                    disabled={loading}
                    rows={3}
                    className="neural-input"
                  />
                </div>
              )}
            </div>

            {/* Center: Neural Network */}
            <div className="neural-panel network-panel glass-panel">
              <h3 className="panel-title">Personality Matrix</h3>

              {/* AI Archetypes */}
              <div className="archetypes-section">
                <label className="section-label">Quick Start Archetypes</label>
                <div className="archetypes-grid">
                  {AI_ARCHETYPES.map(archetype => (
                    <button
                      key={archetype.name}
                      type="button"
                      className={`archetype-card ${activeArchetype === archetype.name ? 'active' : ''}`}
                      onClick={() => handleArchetypeSelect(archetype)}
                      disabled={loading}
                    >
                      <div className="archetype-name">{archetype.name}</div>
                      <div className="archetype-desc">{archetype.description}</div>
                    </button>
                  ))}
                </div>
              </div>

              {/* Personality Traits Grid */}
              <div className="traits-section">
                <label className="section-label">
                  Build Custom Traits
                  {selectedTraits.length > 0 && (
                    <span className="trait-count">({selectedTraits.length} selected)</span>
                  )}
                </label>
                <div className="traits-grid">
                  {PERSONALITY_TRAITS.map(trait => {
                    const isSelected = selectedTraits.includes(trait.id)
                    return (
                      <button
                        key={trait.id}
                        type="button"
                        className={`trait-node ${isSelected ? 'selected' : ''}`}
                        onClick={() => handleTraitToggle(trait.id)}
                        disabled={loading}
                        style={{
                          '--trait-color': trait.color,
                          '--trait-glow': isSelected ? `${trait.color}80` : 'transparent'
                        }}
                      >
                        <span className="trait-emoji">{trait.emoji}</span>
                        <span className="trait-label">{trait.label}</span>
                        {isSelected && <span className="trait-check">✓</span>}
                      </button>
                    )
                  })}
                </div>
              </div>
            </div>

            {/* Right: Preview */}
            <div className="neural-panel preview-panel glass-panel">
              <h3 className="panel-title">Character Preview</h3>

              <div className="character-preview-card">
                <div className="preview-avatar">
                  {formData.avatar ? (
                    <img src={formData.avatar} alt="Avatar" onError={(e) => e.target.src = '/assets/default-avatar.png'} />
                  ) : (
                    <div className="avatar-placeholder">
                      <span>👤</span>
                    </div>
                  )}
                </div>

                <div className="preview-info">
                  <h4 className="preview-name">{formData.name || 'Unnamed Character'}</h4>

                  {selectedTraits.length > 0 && (
                    <div className="preview-traits">
                      {selectedTraits.map(traitId => {
                        const trait = PERSONALITY_TRAITS.find(t => t.id === traitId)
                        return trait ? (
                          <span key={traitId} className="preview-trait" style={{ background: `${trait.color}20`, color: trait.color }}>
                            {trait.emoji} {trait.label}
                          </span>
                        ) : null
                      })}
                    </div>
                  )}

                  {formData.bio && (
                    <div className="preview-bio">
                      <label>Bio:</label>
                      <p>{formData.bio.substring(0, 100)}{formData.bio.length > 100 ? '...' : ''}</p>
                    </div>
                  )}

                  {activeArchetype && (
                    <div className="preview-archetype">
                      <span className="archetype-badge">✨ {activeArchetype}</span>
                    </div>
                  )}
                </div>

                <div className="preview-stats">
                  <div className="stat-item">
                    <span className="stat-label">Traits</span>
                    <span className="stat-value">{selectedTraits.length}/12</span>
                  </div>
                  <div className="stat-item">
                    <span className="stat-label">Complexity</span>
                    <span className="stat-value">{selectedTraits.length < 3 ? 'Simple' : selectedTraits.length < 6 ? 'Moderate' : 'Complex'}</span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Footer Actions */}
          <div className="neural-footer">
            <button
              type="button"
              className="neural-btn secondary"
              onClick={handleClose}
              disabled={loading}
            >
              Cancel
            </button>
            <button
              type="button"
              className="neural-btn primary"
              onClick={handleSubmit}
              disabled={loading || !formData.name.trim() || selectedTraits.length === 0}
            >
              {loading ? (
                <>
                  <span className="btn-spinner">⚡</span>
                  Creating...
                </>
              ) : (
                <>
                  <span className="btn-icon">✨</span>
                  Create Character
                </>
              )}
            </button>
          </div>
        </ErrorBoundary>
      </div>
    </div>
  )
}
