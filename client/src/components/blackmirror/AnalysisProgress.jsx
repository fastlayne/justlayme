import { useEffect, useState } from 'react'
import './AnalysisProgress.scss'

/**
 * AnalysisProgress Component
 * Shows real-time progress during relationship analysis
 */

const ANALYSIS_STEPS = [
  { step: 1, label: 'Processing Data', description: 'Preparing your conversation data' },
  { step: 2, label: 'Sentiment Analysis', description: 'Analyzing emotional tone' },
  { step: 3, label: 'Pattern Recognition', description: 'Identifying communication patterns' },
  { step: 4, label: 'Generating Insights', description: 'Creating comprehensive report' },
  { step: 5, label: 'Finalizing Results', description: 'Preparing visualizations' },
]

export default function AnalysisProgress({
  progress = 0,
  analysisId = null,
  uploadMethod = 'paste',
}) {
  const [currentStep, setCurrentStep] = useState(1)

  // Update current step based on progress
  useEffect(() => {
    const step = Math.ceil((progress / 100) * ANALYSIS_STEPS.length)
    setCurrentStep(Math.min(step || 1, ANALYSIS_STEPS.length))
  }, [progress])

  return (
    <div className="analysis-progress">
      {/* Header */}
      <div className="progress-header">
        <h2>Analyzing Your Data</h2>
        <p>Please wait while we process your conversation...</p>
      </div>

      {/* Progress Bar */}
      <div className="progress-container">
        <div className="progress-bar-wrapper">
          <div className="progress-bar" style={{ width: `${progress}%` }} />
        </div>
        <div className="progress-text">
          <span>{Math.round(progress)}%</span>
        </div>
      </div>

      {/* Steps Timeline */}
      <div className="steps-timeline">
        {ANALYSIS_STEPS.map((item) => (
          <div key={item.step} className={`step-item ${currentStep > item.step ? 'completed' : ''}`}>
            <div className="step-number">
              {currentStep > item.step ? '✓' : item.step}
            </div>
            <div className="step-content">
              <div className="step-label">{item.label}</div>
              <div className="step-description">{item.description}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Analysis Info */}
      <div className="analysis-info">
        <div className="info-item">
          <span className="info-label">Upload Method:</span>
          <span className="info-value">{uploadMethod === 'paste' ? 'Text Paste' : uploadMethod === 'file' ? 'File Upload' : 'Screenshot OCR'}</span>
        </div>
        {analysisId && (
          <div className="info-item">
            <span className="info-label">Analysis ID:</span>
            <span className="info-value">{analysisId.substring(0, 8)}...</span>
          </div>
        )}
      </div>

      {/* Tip */}
      <div className="progress-tip">
        <p>💡 This may take a few moments depending on conversation length</p>
      </div>
    </div>
  )
}
