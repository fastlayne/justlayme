import { useEffect, useState } from 'react'
import './AnalysisProgressModal.scss'

/**
 * AnalysisProgressModal Component
 * Shows real-time progress during Grey Mirror ML analysis
 * Displays pipeline stages with animated progress bar
 */

const STAGES = [
  {
    id: 'parsing',
    label: 'Parsing Conversation Data',
    duration: 2000,
    description: 'Reading and structuring your messages'
  },
  {
    id: 'extraction',
    label: 'Extracting Messages',
    duration: 3000,
    description: 'Identifying conversation patterns'
  },
  {
    id: 'analysis',
    label: 'Running ML Analysis',
    duration: 240000, // 4 minutes - main processing
    description: 'Processing through 22 advanced analyzers'
  },
  {
    id: 'insights',
    label: 'Generating Insights',
    duration: 15000,
    description: 'Compiling your relationship report'
  }
]

export default function AnalysisProgressModal({ isOpen, totalMessages = 0 }) {
  const [currentStageIndex, setCurrentStageIndex] = useState(0)
  const [stageProgress, setStageProgress] = useState(0)
  const [elapsedTime, setElapsedTime] = useState(0)

  // Stage progression
  useEffect(() => {
    if (!isOpen) {
      setCurrentStageIndex(0)
      setStageProgress(0)
      setElapsedTime(0)
      return
    }

    const currentStage = STAGES[currentStageIndex]
    const startTime = Date.now()

    const progressInterval = setInterval(() => {
      const elapsed = Date.now() - startTime
      const progress = Math.min((elapsed / currentStage.duration) * 100, 100)

      setStageProgress(progress)

      // Move to next stage when current completes
      if (progress >= 100 && currentStageIndex < STAGES.length - 1) {
        setCurrentStageIndex(prev => prev + 1)
        setStageProgress(0)
      }
    }, 100)

    return () => clearInterval(progressInterval)
  }, [isOpen, currentStageIndex])

  // Elapsed time counter
  useEffect(() => {
    if (!isOpen) return

    const timer = setInterval(() => {
      setElapsedTime(prev => prev + 1)
    }, 1000)

    return () => clearInterval(timer)
  }, [isOpen])

  if (!isOpen) return null

  const currentStage = STAGES[currentStageIndex]
  const overallProgress = ((currentStageIndex + (stageProgress / 100)) / STAGES.length) * 100

  const formatTime = (seconds) => {
    const mins = Math.floor(seconds / 60)
    const secs = seconds % 60
    return `${mins}:${secs.toString().padStart(2, '0')}`
  }

  return (
    <div className="analysis-progress-modal-overlay">
      <div className="analysis-progress-modal">
        {/* Neural Eye Animation */}
        <div className="neural-eye">
          <div className="eye-ring"></div>
          <div className="eye-pupil">
            <div className="scanning-beam"></div>
          </div>
        </div>

        {/* Header */}
        <h2 className="modal-title">NEURAL ANALYSIS IN PROGRESS</h2>
        <p className="modal-subtitle">
          Processing {totalMessages > 0 ? totalMessages.toLocaleString() : '...'} messages through 22 advanced analyzers
        </p>

        {/* Overall Progress Bar */}
        <div className="overall-progress">
          <div className="progress-bar">
            <div
              className="progress-fill"
              style={{ width: `${overallProgress}%` }}
            >
              <div className="progress-shine"></div>
            </div>
          </div>
          <div className="progress-label">
            {Math.round(overallProgress)}% Complete • {formatTime(elapsedTime)} elapsed
          </div>
        </div>

        {/* Pipeline Stages */}
        <div className="pipeline-stages">
          {STAGES.map((stage, index) => {
            const isActive = index === currentStageIndex
            const isCompleted = index < currentStageIndex
            const isPending = index > currentStageIndex

            return (
              <div
                key={stage.id}
                className={`stage ${isActive ? 'active' : ''} ${isCompleted ? 'completed' : ''} ${isPending ? 'pending' : ''}`}
              >
                <div className="stage-icon">
                  {isCompleted && <span className="icon-check">✓</span>}
                  {isActive && <span className="icon-spinner">◐</span>}
                  {isPending && <span className="icon-pending">○</span>}
                </div>
                <div className="stage-content">
                  <div className="stage-label">{stage.label}</div>
                  <div className="stage-description">{stage.description}</div>
                  {isActive && (
                    <div className="stage-progress-bar">
                      <div
                        className="stage-progress-fill"
                        style={{ width: `${stageProgress}%` }}
                      ></div>
                    </div>
                  )}
                </div>
              </div>
            )
          })}
        </div>

        {/* Footer */}
        <div className="modal-footer">
          <div className="neural-pulse"></div>
          <p className="footer-text">
            This may take several minutes for large conversations • Do not close this window
          </p>
        </div>
      </div>
    </div>
  )
}
