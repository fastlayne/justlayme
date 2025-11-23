import { useState, useEffect } from 'react'
import './LLMInsightsModal.scss'

/**
 * LLMInsightsModal Component
 * Displays AI-generated deep analysis of relationship metrics
 * Streams results from backend LLM
 */

// Tips to show during AI analysis
const ANALYSIS_TIPS = [
  { title: 'Better Results', text: 'Include at least 100 messages for more accurate relationship insights.' },
  { title: 'Message Format', text: 'The "Name: message" format works best. Include timestamps when possible.' },
  { title: 'Time Range', text: 'Longer conversation history reveals more meaningful patterns over time.' },
  { title: 'Both Perspectives', text: 'Make sure to include messages from both people in the conversation.' },
  { title: 'Date Context', text: 'Including timestamps helps identify communication trends over days and weeks.' },
  { title: 'Natural Flow', text: 'Include full conversation threads rather than cherry-picked messages.' },
  { title: 'Processing Time', text: 'Deep AI analysis may take 1-3 minutes depending on conversation length.' },
  { title: 'Multiple Exports', text: 'You can combine message exports from different periods for comprehensive analysis.' },
  { title: 'Privacy First', text: 'Your messages are analyzed locally and never stored on our servers.' },
  { title: 'Iterative Insights', text: 'Run multiple analyses over time to track relationship dynamics.' },
]

export default function LLMInsightsModal({
  isOpen = false,
  results = {},
  onClose = () => {},
  onAnalyze = () => {},
  // PERSONALIZATION: Custom names and insights goal
  personalization = { userName: 'You', contactName: 'Them', insightsGoal: '' },
}) {
  const [isAnalyzing, setIsAnalyzing] = useState(false)
  const [insights, setInsights] = useState('')
  const [error, setError] = useState('')
  const [currentTipIndex, setCurrentTipIndex] = useState(0)

  // Rotate tips during analysis
  useEffect(() => {
    if (!isAnalyzing) return

    const interval = setInterval(() => {
      setCurrentTipIndex((prev) => (prev + 1) % ANALYSIS_TIPS.length)
    }, 4000) // Change tip every 4 seconds

    return () => clearInterval(interval)
  }, [isAnalyzing])

  const handleGetInsights = async () => {
    setIsAnalyzing(true)
    setError('')
    setInsights('')

    try {
      // ARCHITECTURAL FIX: Send metrics AND message excerpts for deep analysis
      // Message excerpts allow the LLM to provide specific, contextual insights
      const payload = {
        healthScore: results.healthScore,
        messageCount: results.messageCount,
        date: results.date,
        // Formatted metric values
        sentiment: results.sentiment,
        patterns: results.patterns,
        engagement: results.engagement,
        conflict: results.conflict,
        toxicity: results.toxicity,
        positivity: results.positivity,
        // Summary fields
        summary: results.summary,
        insights: results.insights,
        recommendations: results.recommendations,
        // Timestamp for context
        timestamp: results.timestamp,
        // ARCHITECTURAL FIX: Include message excerpts for deeper LLM analysis
        messageExcerpts: results.messageExcerpts || [],
        // PERSONALIZATION: Include custom names and user's analysis goal
        personalization: {
          userName: personalization.userName || 'You',
          contactName: personalization.contactName || 'Them',
          insightsGoal: personalization.insightsGoal || '',
        },
      }

      const response = await fetch('/api/grey-mirror/analyze-with-llm', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${localStorage.getItem('authToken') || ''}`,
        },
        credentials: 'include', // Include httpOnly cookies for authentication
        body: JSON.stringify(payload),
      })

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`)
      }

      // Stream the response
      const reader = response.body.getReader()
      const decoder = new TextDecoder()

      while (true) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value)
        setInsights((prev) => prev + chunk)
      }
    } catch (err) {
      setError(`Analysis failed: ${err.message}`)
      console.error('LLM analysis error:', err)
    } finally {
      setIsAnalyzing(false)
    }
  }

  if (!isOpen) return null

  return (
    <div className="llm-modal-overlay" onClick={onClose}>
      <div className="llm-modal" onClick={(e) => e.stopPropagation()}>
        {/* Header */}
        <div className="llm-modal-header">
          <h2>AI Deep Analysis</h2>
          <p>Let our AI dive deeper into your relationship dynamics</p>
          <button className="btn-close" onClick={onClose}>×</button>
        </div>

        {/* Content */}
        <div className="llm-modal-content">
          {isAnalyzing ? (
            // Loading state with rotating tips
            <div className="analyzing-state">
              <div className="loading-spinner-container">
                <div className="loading-spinner"></div>
              </div>
              <h3 className="analyzing-title">Analyzing your conversation...</h3>
              <p className="analyzing-subtitle">This may take 1-3 minutes for comprehensive analysis</p>

              {/* Rotating Tip */}
              <div className="tip-container">
                <div className="tip-card" key={currentTipIndex}>
                  <span className="tip-label">Tip</span>
                  <h4 className="tip-title">{ANALYSIS_TIPS[currentTipIndex].title}</h4>
                  <p className="tip-text">{ANALYSIS_TIPS[currentTipIndex].text}</p>
                </div>
              </div>
            </div>
          ) : insights ? (
            <div className="insights-display">
              <div className="insights-text">{insights}</div>
              <div className="insights-actions">
                <button
                  className="btn btn-primary"
                  onClick={handleGetInsights}
                  disabled={isAnalyzing}
                >
                  Regenerate Analysis
                </button>
                <button className="btn btn-secondary" onClick={onClose}>
                  Close
                </button>
              </div>
            </div>
          ) : error ? (
            <div className="error-display">
              <p className="error-text">{error}</p>
              <button
                className="btn btn-primary"
                onClick={handleGetInsights}
                disabled={isAnalyzing}
              >
                Try Again
              </button>
            </div>
          ) : (
            <div className="initial-state">
              <div className="info-box">
                <p><strong>What you'll get:</strong></p>
                <ul>
                  <li>Personalized relationship insights</li>
                  <li>Deeper pattern analysis</li>
                  <li>Actionable recommendations</li>
                  <li>Communication improvement tips</li>
                </ul>
              </div>
              <button
                className="btn btn-primary btn-large"
                onClick={handleGetInsights}
                disabled={isAnalyzing}
              >
                Get AI Analysis
              </button>
              <p className="info-text">
                Our AI will synthesize all metrics and provide detailed insights tailored to your relationship.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
