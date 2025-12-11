import { useState, useMemo } from 'react'
import MetricCard from './MetricCard'
import './MetricsExplorer.scss'

/**
 * MetricsExplorer Component
 * Dynamically displays all relationship metrics from the API response
 * ENHANCED: Now supports all 22 analyzers from the Python ML service
 */

// Analyzer metadata - maps analyzer keys to human-readable info
const ANALYZER_METADATA = {
  // Original 17 deterministic analyzers
  deflection: {
    title: 'Deflection Detection',
    description: 'Identifies patterns of avoiding topics or changing subjects to evade difficult conversations',
    category: 'communication'
  },
  repair_attempts: {
    title: 'Repair Attempts',
    description: 'Tracks efforts to fix miscommunications and resolve conflicts in conversation',
    category: 'conflict'
  },
  vulnerability: {
    title: 'Vulnerability Sharing',
    description: 'Measures emotional openness and willingness to share personal feelings',
    category: 'emotional'
  },
  turn_taking: {
    title: 'Turn Taking Balance',
    description: 'Analyzes conversational balance - who dominates and who listens',
    category: 'communication'
  },
  question_ratio: {
    title: 'Question Engagement',
    description: 'Tracks curiosity and interest through questions asked by each person',
    category: 'engagement'
  },
  emotional_momentum: {
    title: 'Emotional Momentum',
    description: 'Measures how emotions escalate or de-escalate during conversations',
    category: 'emotional'
  },
  shared_vocabulary: {
    title: 'Shared Vocabulary',
    description: 'Identifies common words and phrases that create connection',
    category: 'communication'
  },
  conversation_dynamics: {
    title: 'Conversation Dynamics',
    description: 'Overall flow, rhythm, and patterns in message exchanges',
    category: 'patterns'
  },
  topic_stability: {
    title: 'Topic Stability',
    description: 'How well conversations stay on track versus jumping between topics',
    category: 'communication'
  },
  conversation_spiral: {
    title: 'Conversation Spirals',
    description: 'Detects circular arguments or repetitive discussion patterns',
    category: 'conflict'
  },
  stress_adaptation: {
    title: 'Stress Adaptation',
    description: 'How communication style changes under pressure or conflict',
    category: 'emotional'
  },
  entropy: {
    title: 'Conversation Entropy',
    description: 'Measures unpredictability and randomness in conversation flow',
    category: 'patterns'
  },
  linguistic_matching: {
    title: 'Linguistic Matching',
    description: 'How closely communication styles mirror each other',
    category: 'communication'
  },
  power_dynamics: {
    title: 'Power Dynamics',
    description: 'Identifies dominance, submission, and control patterns',
    category: 'patterns'
  },
  positivity_reciprocity: {
    title: 'Positivity Reciprocity',
    description: 'Whether positive emotions are matched and returned',
    category: 'emotional'
  },
  responsibility_avoidance: {
    title: 'Responsibility Avoidance',
    description: 'Patterns of deflecting blame or avoiding accountability',
    category: 'conflict'
  },
  emotional_deflection: {
    title: 'Emotional Deflection',
    description: 'Avoiding emotional topics through jokes, sarcasm, or topic changes',
    category: 'emotional'
  },

  // New 5 ML-powered analyzers
  love_language: {
    title: 'Love Language Detection',
    description: 'Identifies primary love languages: Words of Affirmation, Quality Time, Acts of Service, Gifts, Physical Touch',
    category: 'advanced'
  },
  gottman_ratio: {
    title: 'Gottman 5:1 Ratio',
    description: 'Measures positive-to-negative interaction ratio (healthy relationships maintain 5:1 or higher)',
    category: 'advanced'
  },
  response_time: {
    title: 'Response Time Patterns',
    description: 'Analyzes message timing to reveal urgency, interest, and communication priorities',
    category: 'advanced'
  },
  future_planning: {
    title: 'Future Planning Analysis',
    description: 'Detects commitment signals through mentions of future plans and long-term thinking',
    category: 'advanced'
  },
  emoji: {
    title: 'Emoji Communication',
    description: 'Analyzes emoji usage patterns, emotional expression, and digital body language',
    category: 'advanced'
  },

  // Legacy metrics for backward compatibility
  sentiment: {
    title: 'Sentiment Analysis',
    description: 'Overall emotional tone of conversations - who is more positive or negative?',
    category: 'emotional'
  },
  patterns: {
    title: 'Communication Patterns',
    description: 'Frequency and style of interactions - who texts more?',
    category: 'patterns'
  },
  engagement: {
    title: 'Emotional Engagement',
    description: 'Depth of emotional investment - who is more invested?',
    category: 'engagement'
  },
  conflict: {
    title: 'Double/Triple Texting',
    description: 'Message streaks and investment levels - who double texts more?',
    category: 'conflict'
  },
  apologyPatterns: {
    title: 'Apologies & Reconciliation',
    description: 'Who apologizes more and how sincere are they?',
    category: 'conflict'
  },
  toxicity: {
    title: 'Toxicity Analysis',
    description: 'Negative language and tone detection - who is more toxic?',
    category: 'conflict'
  },
  positivity: {
    title: 'Positivity Index',
    description: 'Overall relationship health score - who is more positive?',
    category: 'emotional'
  }
}

export default function MetricsExplorer({
  results = {},
  expandedMetrics = [],
  personalization = { userName: 'You', contactName: 'Them' }
}) {
  // Build initial list of all metric IDs
  const allMetricIds = useMemo(() => {
    const metrics = []
    if (results.metrics && typeof results.metrics === 'object') {
      Object.keys(results.metrics).forEach(key => {
        const analyzerResult = results.metrics[key]
        if (analyzerResult?.success !== undefined) {
          if (analyzerResult.success && analyzerResult.data) {
            metrics.push(key)
          }
        } else if (analyzerResult && typeof analyzerResult === 'object') {
          metrics.push(key)
        }
      })
    } else {
      Object.keys(results).forEach((key) => {
        if (ANALYZER_METADATA[key] && results[key]) {
          metrics.push(key)
        }
      })
    }
    return metrics
  }, [results])

  // Auto-expand ALL metrics by default to show all data
  const [localExpanded, setLocalExpanded] = useState(allMetricIds)

  const toggleMetric = (id) => {
    setLocalExpanded((prev) => {
      const current = Array.isArray(prev) ? prev : []
      return current.includes(id) ? current.filter((m) => m !== id) : [...current, id]
    })
  }

  // Dynamically build metrics list from API response
  const metricsToDisplay = useMemo(() => {
    const metrics = []

    // Debug: log what we received
    console.log('[MetricsExplorer] Results received:', results)
    console.log('[MetricsExplorer] Results.metrics:', results?.metrics)

    // Check for new ML service format: results.metrics
    if (results.metrics && typeof results.metrics === 'object') {
      console.log('[MetricsExplorer] Using new ML service format')
      // New format: metrics is an object with analyzer results
      Object.entries(results.metrics).forEach(([key, analyzerResult]) => {
        console.log(`[MetricsExplorer] Processing metric: ${key}`, analyzerResult)

        // Handle both {success: true, data: {...}} and direct data formats
        let metricData = null
        if (analyzerResult?.success !== undefined) {
          // Format: {success: true, data: {...}}
          if (analyzerResult.success && analyzerResult.data) {
            metricData = analyzerResult.data
          }
        } else if (analyzerResult && typeof analyzerResult === 'object') {
          // Direct data format
          metricData = analyzerResult
        }

        if (metricData) {
          const metadata = ANALYZER_METADATA[key] || {
            title: key.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase()),
            description: `Analysis of ${key.replace(/_/g, ' ')}`,
            category: 'other'
          }

          metrics.push({
            id: key,
            title: metadata.title,
            description: metadata.description,
            category: metadata.category,
            data: metricData
          })
        }
      })
    } else {
      console.log('[MetricsExplorer] Using legacy format')
      // Legacy format: top-level keys
      Object.keys(results).forEach((key) => {
        if (ANALYZER_METADATA[key] && results[key]) {
          metrics.push({
            id: key,
            title: ANALYZER_METADATA[key].title,
            description: ANALYZER_METADATA[key].description,
            category: ANALYZER_METADATA[key].category,
            data: results[key]
          })
        }
      })
    }

    console.log('[MetricsExplorer] Total metrics to display:', metrics.length)

    // Sort: advanced analyzers first, then by category
    return metrics.sort((a, b) => {
      if (a.category === 'advanced' && b.category !== 'advanced') return -1
      if (a.category !== 'advanced' && b.category === 'advanced') return 1
      return a.title.localeCompare(b.title)
    })
  }, [results])

  if (metricsToDisplay.length === 0) {
    return (
      <div className="metrics-explorer">
        <h2>Relationship Metrics</h2>
        <p className="explorer-description">No metrics available to display</p>
      </div>
    )
  }

  return (
    <div className="metrics-explorer">
      <h2>Relationship Metrics</h2>
      <p className="explorer-description">
        Click on any metric to view detailed per-person breakdowns and comparisons
        {metricsToDisplay.some(m => m.category === 'advanced') && (
          <span className="advanced-badge"> • Including {metricsToDisplay.filter(m => m.category === 'advanced').length} Advanced ML Metrics</span>
        )}
      </p>

      <div className="metrics-grid">
        {metricsToDisplay.map((metric) => {
          const metricData = metric.data || {}

          // DEBUG: Log all data for this metric
          console.log(`[MetricsExplorer] Metric "${metric.title}" data:`, metricData)

          // Extract structured per-person data if available
          let sections = null
          let comparison = null

          // Check for common per-person patterns in the data
          const hasUserData = metricData.user || metricData.you || metricData[personalization.userName]
          const hasContactData = metricData.contact || metricData.them || metricData[personalization.contactName]

          if (hasUserData || hasContactData) {
            sections = {
              you: metricData.user || metricData.you || metricData[personalization.userName] || {},
              them: metricData.contact || metricData.them || metricData[personalization.contactName] || {}
            }
            console.log(`[MetricsExplorer] Extracted sections for "${metric.title}":`, sections)
          }

          // Build details from ALL fields - show EVERYTHING
          const autoDetails = []
          Object.entries(metricData).forEach(([key, val]) => {
            // Only skip these specific internal fields
            if (['value', 'score', 'summary', 'interpretation', 'sections', 'comparison'].includes(key)) {
              return
            }

            // For user/contact data, we'll show it in sections instead
            const isUserContactField = ['user', 'you', 'contact', 'them', personalization.userName, personalization.contactName].includes(key)

            // Skip empty values
            if (val === null || val === undefined || val === '') {
              return
            }

            // Format different types
            if (typeof val === 'object' && val !== null) {
              if (Array.isArray(val)) {
                if (val.length === 0) return // Skip empty arrays
                // Show array as single detail item
                const formattedArray = val.map(item => {
                  if (typeof item === 'object' && item !== null) {
                    // For object arrays, format each object nicely
                    return Object.entries(item).map(([k, v]) => `${k}: ${v}`).join(', ')
                  }
                  return String(item)
                }).join(' | ')

                if (!isUserContactField) {
                  autoDetails.push({
                    label: key.replace(/_/g, ' ').replace(/([A-Z])/g, ' $1').trim(),
                    value: formattedArray
                  })
                }
                return
              } else if (!isUserContactField) {
                // For non user/contact objects, show all key-value pairs as separate items
                const entries = Object.entries(val)
                if (entries.length === 0) return // Skip empty objects
                // Create individual detail items for each property
                entries.forEach(([k, v]) => {
                  if (v !== null && v !== undefined && v !== '') {
                    // Format nested values properly
                    let formattedValue = v
                    if (typeof v === 'object' && v !== null) {
                      if (Array.isArray(v)) {
                        formattedValue = v.join(', ')
                      } else {
                        formattedValue = Object.entries(v).map(([vk, vv]) => `${vk}: ${vv}`).join(', ')
                      }
                    }
                    autoDetails.push({
                      label: `${key} - ${k}`.replace(/_/g, ' ').replace(/([A-Z])/g, ' $1').trim(),
                      value: String(formattedValue)
                    })
                  }
                })
                return // Already processed this object
              } else {
                return // Skip user/contact objects as they go in sections
              }
            }

            if (!isUserContactField) {
              autoDetails.push({
                label: key.replace(/_/g, ' ').replace(/([A-Z])/g, ' $1').trim(),
                value: String(val)
              })
            }
          })

          console.log(`[MetricsExplorer] Final details for "${metric.title}":`, autoDetails)

          return (
            <MetricCard
              key={metric.id}
              title={metric.title}
              icon={null}
              value={metricData.value || metricData.score || '—'}
              description={metric.description}
              details={autoDetails}
              sections={sections || metricData.sections || null}
              comparison={comparison || metricData.comparison || null}
              summary={metricData.summary || metricData.interpretation || ''}
              isExpanded={localExpanded.includes(metric.id)}
              onToggle={() => toggleMetric(metric.id)}
              userName={personalization.userName || 'You'}
              contactName={personalization.contactName || 'Them'}
            />
          )
        })}
      </div>
    </div>
  )
}
