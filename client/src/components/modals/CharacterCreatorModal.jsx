import { useState } from 'react'
import { useCharacters } from '@/hooks/useCharacters'
import { useChat } from '@/hooks/useChat'
import { useModal } from '@/hooks/useModal'
import { useNotification } from '@/hooks/useNotification'
import ErrorBoundary from '@/components/ErrorBoundary'
import ProfileCard from '@/components/common/ProfileCard'
import './CharacterCreatorModal.scss'

/**
 * CharacterCreatorModal Component
 * Futuristic 3-step character fabrication chamber with holographic effects
 */

const STEPS = [
  { id: 1, title: 'Identity', subtitle: 'Define core attributes' },
  { id: 2, title: 'Personality', subtitle: 'Shape character traits' },
  { id: 3, title: 'Finalize', subtitle: 'Review and create' }
]

export default function CharacterCreatorModal({ modalId, onClose }) {
  const { createCharacter } = useCharacters()
  const { startConversation } = useChat()
  const notification = useNotification()
  const [currentStep, setCurrentStep] = useState(1)
  const [isClosing, setIsClosing] = useState(false)
  const [formData, setFormData] = useState({
    name: '',
    bio: '',
    avatar: '',
    personality: ''
  })
  const [loading, setLoading] = useState(false)

  const handleChange = (e) => {
    const { name, value } = e.target
    setFormData((prev) => ({ ...prev, [name]: value }))
  }

  const handleNext = () => {
    if (currentStep === 1 && !formData.name.trim()) {
      notification.warning('Character name is required')
      return
    }
    if (currentStep < 3) {
      setCurrentStep(currentStep + 1)
    }
  }

  const handlePrev = () => {
    if (currentStep > 1) {
      setCurrentStep(currentStep - 1)
    }
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

    if (formData.name.trim().length < 2) {
      notification.warning('Character name must be at least 2 characters')
      return
    }

    setLoading(true)
    try {
      const newCharacter = await createCharacter(formData)
      notification.success(`${formData.name} materialized successfully!`)

      try {
        await startConversation(newCharacter.id)
      } catch (conversationError) {
        console.error('Failed to start conversation:', conversationError)
        notification.warning('Character created, but failed to start conversation.')
      }

      handleClose()
      setFormData({ name: '', bio: '', avatar: '', personality: '' })
      setCurrentStep(1)
    } catch (error) {
      console.error('Character creation error:', error)
      notification.error(error.message || 'Failed to create character')
    } finally {
      setLoading(false)
    }
  }

  return (
    <div className={`modal-overlay fabrication-chamber ${isClosing ? 'closing' : ''}`} onClick={handleClose}>
      <div className="modal-content character-fabricator" onClick={(e) => e.stopPropagation()}>
        <ErrorBoundary>
          {/* Holographic particles */}
          <div className="holographic-particles">
            {[...Array(20)].map((_, i) => (
              <div key={i} className="particle" style={{ '--particle-delay': `${i * 0.1}s` }} />
            ))}
          </div>

          {/* Header with progress */}
          <div className="fabricator-header">
            <h2 className="fabricator-title">
              <span className="title-glow">Character Fabrication Chamber</span>
            </h2>
            <button className="modal-close holographic-btn" onClick={handleClose}>✕</button>
          </div>

          {/* Progress indicator */}
          <div className="fabrication-progress">
            {STEPS.map((step, index) => (
              <div
                key={step.id}
                className={`progress-step ${currentStep >= step.id ? 'active' : ''} ${currentStep === step.id ? 'current' : ''}`}
              >
                <div className="step-number">{step.id}</div>
                <div className="step-info">
                  <div className="step-title">{step.title}</div>
                  <div className="step-subtitle">{step.subtitle}</div>
                </div>
                {index < STEPS.length - 1 && <div className="step-connector" />}
              </div>
            ))}
          </div>

          {/* Main content area */}
          <div className="fabrication-content">
            {/* Left: Form */}
            <div className="form-panel">
              <form onSubmit={handleSubmit} className="fabrication-form">
                {/* Step 1: Identity */}
                <div className={`form-step ${currentStep === 1 ? 'active' : ''}`}>
                  <div className="form-group floating-label">
                    <input
                      id="name"
                      type="text"
                      name="name"
                      placeholder=" "
                      value={formData.name}
                      onChange={handleChange}
                      disabled={loading}
                      required
                      className="holographic-input"
                    />
                    <label htmlFor="name">Character Name *</label>
                    <div className="input-glow" />
                  </div>

                  <div className="form-group floating-label">
                    <input
                      id="avatar"
                      type="url"
                      name="avatar"
                      placeholder=" "
                      value={formData.avatar}
                      onChange={handleChange}
                      disabled={loading}
                      className="holographic-input"
                    />
                    <label htmlFor="avatar">Avatar URL</label>
                    <div className="input-glow" />
                  </div>
                </div>

                {/* Step 2: Personality */}
                <div className={`form-step ${currentStep === 2 ? 'active' : ''}`}>
                  <div className="form-group floating-label">
                    <textarea
                      id="bio"
                      name="bio"
                      placeholder=" "
                      value={formData.bio}
                      onChange={handleChange}
                      disabled={loading}
                      rows={4}
                      className="holographic-input"
                    />
                    <label htmlFor="bio">Background & Bio</label>
                    <div className="input-glow" />
                  </div>

                  <div className="form-group floating-label">
                    <input
                      id="personality"
                      type="text"
                      name="personality"
                      placeholder=" "
                      value={formData.personality}
                      onChange={handleChange}
                      disabled={loading}
                      className="holographic-input"
                    />
                    <label htmlFor="personality">Personality Traits</label>
                    <div className="input-glow" />
                  </div>
                </div>

                {/* Step 3: Review */}
                <div className={`form-step ${currentStep === 3 ? 'active' : ''}`}>
                  <div className="review-section">
                    <h3 className="review-title">Character Specification</h3>
                    <div className="review-item">
                      <span className="review-label">Name:</span>
                      <span className="review-value">{formData.name || 'Not set'}</span>
                    </div>
                    <div className="review-item">
                      <span className="review-label">Personality:</span>
                      <span className="review-value">{formData.personality || 'Default'}</span>
                    </div>
                    <div className="review-item">
                      <span className="review-label">Bio Length:</span>
                      <span className="review-value">{formData.bio.length} characters</span>
                    </div>
                    <div className="fabrication-ready">
                      <div className="ready-indicator" />
                      <span>{loading ? 'Materializing...' : 'Ready to fabricate'}</span>
                    </div>
                  </div>
                </div>
              </form>
            </div>

            {/* Right: Live Preview */}
            <div className="preview-panel">
              <div className="preview-label">Live Preview</div>
              <div className="character-preview">
                <ProfileCard
                  name={formData.name || 'New Character'}
                  title={formData.personality || 'AI Companion'}
                  status={formData.bio ? formData.bio.substring(0, 100) + '...' : 'No bio yet'}
                  avatar={formData.avatar}
                  enableTilt={true}
                  behindGlowEnabled={true}
                  behindGlowColor="rgba(6, 182, 212, 0.5)"
                />
              </div>
            </div>
          </div>

          {/* Navigation */}
          <div className="fabrication-actions">
            <button
              type="button"
              className="holographic-btn secondary"
              onClick={handlePrev}
              disabled={currentStep === 1 || loading}
            >
              ← Previous
            </button>
            <div className="step-indicator">
              Step {currentStep} of {STEPS.length}
            </div>
            {currentStep < 3 ? (
              <button
                type="button"
                className="holographic-btn primary"
                onClick={handleNext}
                disabled={loading}
              >
                Next →
              </button>
            ) : (
              <button
                type="button"
                className="holographic-btn primary pulse"
                onClick={handleSubmit}
                disabled={loading}
              >
                {loading ? '⚡ Materializing...' : '✨ Fabricate Character'}
              </button>
            )}
          </div>
        </ErrorBoundary>
      </div>
    </div>
  )
}
