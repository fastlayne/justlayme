import { useState } from 'react'
import MetricCard from './MetricCard'
import './MetricsExplorer.scss'

/**
 * MetricsExplorer Component
 * Displays 7 key relationship metrics with expandable per-person breakdowns
 * ENHANCED: Now supports per-person sections and comparison data
 */

const METRIC_DEFINITIONS = [
  {
    id: 'sentiment',
    title: 'Sentiment Analysis',
    icon: null,
    description: 'Overall emotional tone of conversations - who is more positive or negative?',
  },
  {
    id: 'patterns',
    title: 'Communication Patterns',
    icon: null,
    description: 'Frequency and style of interactions - who texts more?',
  },
  {
    id: 'engagement',
    title: 'Emotional Engagement',
    icon: null,
    description: 'Depth of emotional investment - who is more invested?',
  },
  {
    id: 'conflict',
    title: 'Double/Triple Texting',
    icon: null,
    description: 'Message streaks and investment levels - who double texts more?',
  },
  {
    id: 'apologyPatterns',
    title: 'Apologies & Reconciliation',
    icon: null,
    description: 'Who apologizes more and how sincere are they?',
  },
  {
    id: 'toxicity',
    title: 'Toxicity Analysis',
    icon: null,
    description: 'Negative language and tone detection - who is more toxic?',
  },
  {
    id: 'positivity',
    title: 'Positivity Index',
    icon: null,
    description: 'Overall relationship health score - who is more positive?',
  },
]

export default function MetricsExplorer({ results = {}, expandedMetrics = [] }) {
  // ARCHITECTURAL FIX: Ensure expandedMetrics is always an array
  const [localExpanded, setLocalExpanded] = useState(Array.isArray(expandedMetrics) ? expandedMetrics : [])

  const toggleMetric = (id) => {
    setLocalExpanded((prev) => {
      // ARCHITECTURAL FIX: Defensive check to ensure prev is always an array
      const current = Array.isArray(prev) ? prev : []
      return current.includes(id) ? current.filter((m) => m !== id) : [...current, id]
    })
  }

  return (
    <div className="metrics-explorer">
      <h2>Relationship Metrics</h2>
      <p className="explorer-description">
        Click on any metric to view detailed per-person breakdowns and comparisons
      </p>

      <div className="metrics-grid">
        {METRIC_DEFINITIONS.map((metric) => {
          const metricData = results[metric.id] || {}
          return (
            <MetricCard
              key={metric.id}
              title={metric.title}
              icon={metric.icon}
              value={metricData.value || '—'}
              description={metric.description}
              details={metricData.details || []}
              sections={metricData.sections || null}
              comparison={metricData.comparison || null}
              summary={metricData.summary || ''}
              isExpanded={localExpanded.includes(metric.id)}
              onToggle={() => toggleMetric(metric.id)}
            />
          )
        })}
      </div>
    </div>
  )
}
