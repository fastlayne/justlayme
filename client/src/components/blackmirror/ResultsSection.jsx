import { useState } from 'react'
import MetricsExplorer from './MetricsExplorer'
import ExportButton from './ExportButton'
import LLMInsightsModal from './LLMInsightsModal'
import './ResultsSection.scss'

/**
 * ResultsSection Component
 * Displays final analysis results and export options
 * Includes elegant LLM integration for deeper AI analysis
 */

export default function ResultsSection({
  results = {},
  expandedMetrics = [],
  onRestart = () => {},
}) {
  const [isLLMModalOpen, setIsLLMModalOpen] = useState(false)
  return (
    <div className="results-section">
      {/* Header */}
      <div className="results-header">
        <h2>Analysis Complete</h2>
        <p>Here are your relationship insights and metrics</p>
      </div>

      {/* Summary Stats */}
      <div className="summary-stats">
        <div className="stat-card">
          <div className="stat-content">
            <div className="stat-label">Overall Health</div>
            <div className="stat-value">{results.healthScore || '—'}</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-content">
            <div className="stat-label">Messages Analyzed</div>
            <div className="stat-value">{results.messageCount || '—'}</div>
          </div>
        </div>
        <div className="stat-card">
          <div className="stat-content">
            <div className="stat-label">Analysis Date</div>
            <div className="stat-value">{results.date || '—'}</div>
          </div>
        </div>
      </div>

      {/* Metrics Explorer */}
      <MetricsExplorer results={results} expandedMetrics={expandedMetrics} />

      {/* Actions */}
      <div className="results-actions">
        <button
          className="btn btn-primary"
          onClick={() => setIsLLMModalOpen(true)}
        >
          Get AI Analysis
        </button>
        <ExportButton results={results} />
        <button className="btn btn-secondary" onClick={onRestart}>
          Analyze Another
        </button>
      </div>

      {/* LLM Insights Modal */}
      <LLMInsightsModal
        isOpen={isLLMModalOpen}
        results={results}
        onClose={() => setIsLLMModalOpen(false)}
      />
    </div>
  )
}
