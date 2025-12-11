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
    description: 'Shows when someone avoids difficult topics by changing the subject or making jokes. High deflection means someone regularly sidesteps serious conversations. This can indicate discomfort with vulnerability or conflict.',
    category: 'communication'
  },
  repair_attempts: {
    title: 'Repair Attempts',
    description: 'Counts how often each person tries to fix misunderstandings or smooth over conflicts. Phrases like "I meant...", "let me clarify", or "I\'m sorry" indicate repair attempts. Healthy relationships show balanced repair efforts from both people.',
    category: 'conflict'
  },
  vulnerability: {
    title: 'Vulnerability Sharing',
    description: 'Measures emotional openness and willingness to share feelings, fears, or personal struggles. Higher vulnerability creates deeper intimacy. Imbalanced vulnerability (one person always sharing, the other guarded) can indicate trust issues.',
    category: 'emotional'
  },
  turn_taking: {
    title: 'Turn Taking Balance',
    description: 'Who talks more? This shows the conversational balance - whether both people contribute equally or one dominates. Healthy conversations have 50/50 turn-taking. Imbalance may show one person feels unheard or the other is self-focused.',
    category: 'communication'
  },
  question_ratio: {
    title: 'Question Engagement',
    description: 'Tracks how many questions each person asks. Questions show curiosity and interest in the other person. If one person asks most questions, they may be carrying the emotional labor of the conversation while the other person is disengaged.',
    category: 'engagement'
  },
  emotional_momentum: {
    title: 'Emotional Momentum',
    description: 'Shows how emotions build or fade during conversations. Do positive moments lead to more warmth? Do conflicts escalate or de-escalate? This reveals emotional patterns - whether you fuel each other\'s feelings or calm things down.',
    category: 'emotional'
  },
  shared_vocabulary: {
    title: 'Shared Vocabulary',
    description: 'Identifies words and phrases you both use repeatedly. Couples develop their own "language" with inside jokes, nicknames, and common expressions. Strong shared vocabulary indicates deep connection and time spent together.',
    category: 'communication'
  },
  conversation_dynamics: {
    title: 'Conversation Dynamics',
    description: 'The overall rhythm and flow of your messages. Do you have smooth back-and-forth exchanges? Long monologues? Quick bursts? This shows communication patterns - whether conversations feel natural or forced.',
    category: 'patterns'
  },
  topic_stability: {
    title: 'Topic Stability',
    description: 'How well you stay on one topic versus jumping around. Low stability might mean scattered, surface-level chats. High stability shows you can have deeper, focused conversations about important subjects without constant topic switching.',
    category: 'communication'
  },
  conversation_spiral: {
    title: 'Conversation Spirals',
    description: 'Detects when you argue about the same things repeatedly without resolution. Circular patterns like "we keep fighting about X" indicate unresolved core issues. Breaking these spirals requires addressing the root problem, not just the symptoms.',
    category: 'conflict'
  },
  stress_adaptation: {
    title: 'Stress Adaptation',
    description: 'How does your communication change under stress or during conflicts? Do you become cold, aggressive, withdrawn? Or do you stay warm and engaged? This reveals coping mechanisms and emotional regulation skills.',
    category: 'emotional'
  },
  entropy: {
    title: 'Conversation Entropy',
    description: 'Measures how predictable or chaotic your conversations are. Very high entropy means unpredictable, scattered exchanges. Very low means rigid, formulaic chats. Moderate entropy suggests natural, varied but coherent communication.',
    category: 'patterns'
  },
  linguistic_matching: {
    title: 'Linguistic Matching',
    description: 'Do you mirror each other\'s communication style? Matching means using similar words, sentence structures, and tone. High matching shows rapport and connection. One-sided matching might mean one person is adjusting while the other isn\'t.',
    category: 'communication'
  },
  power_dynamics: {
    title: 'Power Dynamics',
    description: 'Who controls the conversation? This tracks dominance patterns - who decides topics, who apologizes more, who asks for permission. Healthy relationships have balanced power. Imbalance can indicate control issues or inequality.',
    category: 'patterns'
  },
  positivity_reciprocity: {
    title: 'Positivity Reciprocity',
    description: 'When one person is positive, does the other match that energy? Or do they stay neutral/negative? Reciprocity means both people contribute to good vibes. One-sided positivity can feel exhausting for the person trying to keep things upbeat.',
    category: 'emotional'
  },
  responsibility_avoidance: {
    title: 'Responsibility Avoidance',
    description: 'Tracks patterns of deflecting blame with phrases like "you made me...", "it\'s not my fault", or "you always...". High avoidance means someone struggles to own their actions. Healthy accountability requires both people taking responsibility.',
    category: 'conflict'
  },
  emotional_deflection: {
    title: 'Emotional Deflection',
    description: 'When serious emotional topics come up, does someone make jokes, change subjects, or use sarcasm? Deflection protects against vulnerability but prevents deeper connection. Repeated deflection might indicate fear of intimacy or past trauma.',
    category: 'emotional'
  },

  // New 5 ML-powered analyzers
  love_language: {
    title: 'Love Language Detection',
    description: 'Discovers how you each express and receive love. The 5 love languages are: Words of Affirmation (compliments, "I love you"), Quality Time (wanting to hang out), Acts of Service (doing things for each other), Receiving Gifts (thoughtful presents), and Physical Touch (hugs, kisses). Knowing your love languages helps you feel appreciated.',
    category: 'advanced'
  },
  gottman_ratio: {
    title: 'Gottman 5:1 Ratio',
    description: 'Research by Dr. John Gottman found that healthy relationships maintain at least 5 positive interactions for every 1 negative one. This metric measures your positive-to-negative ratio. Below 5:1 means negativity is overwhelming the good moments. Above 5:1 indicates a strong, resilient relationship.',
    category: 'advanced'
  },
  response_time: {
    title: 'Response Time Patterns',
    description: 'How quickly do you reply to each other? Fast responses often signal high interest and priority. Slow responses might indicate busy schedules or lower emotional investment. Consistent response times show reliability. Wildly varying times could mean inconsistent interest or avoidant attachment style.',
    category: 'advanced'
  },
  future_planning: {
    title: 'Future Planning Analysis',
    description: 'Do you talk about the future together? Mentions of "next week", "next year", making plans, or long-term thinking show commitment and investment. If one person plans the future while the other stays in the present, it might indicate different levels of commitment or uncertainty about the relationship.',
    category: 'advanced'
  },
  emoji: {
    title: 'Emoji Communication',
    description: 'Emojis are digital body language. Hearts and positive emojis show affection. Lots of emojis indicate expressive, warm communication. Rare emoji use might mean someone is more serious or reserved. Mismatched emoji styles (one person uses tons, the other uses none) can create communication gaps.',
    category: 'advanced'
  },

  // Legacy metrics for backward compatibility
  sentiment: {
    title: 'Sentiment Analysis',
    description: 'Overall emotional tone of your conversations. Are messages mostly positive, negative, or neutral? This shows the general mood of the relationship. Consistently negative sentiment can predict relationship problems. Balanced or positive sentiment indicates emotional health.',
    category: 'emotional'
  },
  patterns: {
    title: 'Communication Patterns',
    description: 'Who texts more often? What times of day? What length messages? This reveals communication habits and preferences. Imbalanced patterns (one person initiating all conversations) might mean unequal interest or different communication needs.',
    category: 'patterns'
  },
  engagement: {
    title: 'Emotional Engagement',
    description: 'Depth of emotional investment in conversations. Are messages thoughtful and engaged, or short and surface-level? High engagement means both people care about meaningful connection. Low engagement might indicate emotional distance or disinterest.',
    category: 'engagement'
  },
  conflict: {
    title: 'Double/Triple Texting',
    description: 'Sending multiple messages before getting a reply. This shows investment but can also indicate anxiety or need for validation. Who double-texts more reveals who worries more about the relationship or has higher communication needs.',
    category: 'conflict'
  },
  apologyPatterns: {
    title: 'Apologies & Reconciliation',
    description: 'Who says sorry more often? Are apologies sincere ("I apologize for...") or defensive ("sorry but...")? Healthy relationships have balanced apologies. One person always apologizing might indicate power imbalance or a people-pleaser dynamic.',
    category: 'conflict'
  },
  toxicity: {
    title: 'Toxicity Analysis',
    description: 'Detects harmful language patterns: insults, blame, contempt, name-calling, threats. Even occasional toxicity damages trust. Consistent toxicity is a major red flag. Healthy relationships keep toxicity near zero through respectful communication even during conflicts.',
    category: 'conflict'
  },
  positivity: {
    title: 'Positivity Index',
    description: 'Overall relationship health based on kindness, appreciation, humor, support, and warmth in messages. High positivity means you lift each other up. Low positivity suggests the relationship has become cold or critical. This is one of the strongest predictors of relationship satisfaction.',
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
