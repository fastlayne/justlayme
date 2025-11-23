/**
 * mlOrchestrator.js
 * Main orchestrator that runs all ML analysis modules
 * Coordinates analysis pipeline and returns comprehensive relationship metrics
 */

import { parseConversationData, getConversationStats } from './messageParser'
import { analyzeSentiment, compareSentiment } from './sentimentAnalyzer'
import { analyzeCommunicationPatterns } from './communicationPatterns'
import { detectDoubleTexting, analyzeStreakTiming } from './doubleTextingDetector'
import { analyzeWeekdayWeekend } from './weekdayWeekendAnalyzer'
import { analyzeResponseTimes, analyzeCallbackConsistency } from './responseTimeAnalyzer'
import { classifyToxicity } from './toxicityClassifier'
import { scoreEngagement } from './engagementScorer'
import { calculatePositivityIndex } from './positivityIndex'
import { detectApologyPatterns } from './apologyClassifier'

/**
 * Run complete RelationshipX analysis pipeline
 * @param {string|object} data - Raw conversation data
 * @param {string} format - Format type: 'paste', 'file', 'screenshot'
 * @returns {Promise<Object>} Complete analysis results
 */
export async function runCompleteAnalysis(data, format = 'paste', personalization = null) {
  try {
    // Step 1: Parse and normalize messages
    console.log('[MLOrchestrator] Starting analysis...')
    console.log('[MLOrchestrator] Input data length:', typeof data === 'string' ? data.length : 'non-string')
    const messages = parseConversationData(data, format)

    console.log('[MLOrchestrator] Parsed messages count:', messages?.length || 0)

    if (!messages || messages.length < 2) {
      return {
        success: false,
        error: 'Need at least 2 messages for analysis',
        messageCount: messages ? messages.length : 0,
      }
    }

    // Step 2: Get basic stats
    const stats = getConversationStats(messages)
    console.log('[MLOrchestrator] Stats totalMessages:', stats.totalMessages)

    // Step 3: Run all analysis modules in parallel where possible
    // CRITICAL FIX: Use Promise.allSettled instead of Promise.all
    // This ensures that if one analysis module fails, others continue executing
    // Rather than all-or-nothing failure, we get partial results and can report which modules succeeded
    const analysisResults = await Promise.allSettled([
      Promise.resolve(analyzeSentiment(messages)),
      Promise.resolve(compareSentiment(messages)),
      Promise.resolve(analyzeCommunicationPatterns(messages)),
      Promise.resolve(detectDoubleTexting(messages)),
      Promise.resolve(analyzeStreakTiming(messages)),
      Promise.resolve(analyzeWeekdayWeekend(messages)),
      Promise.resolve(analyzeResponseTimes(messages)),
      Promise.resolve(analyzeCallbackConsistency(messages)),
      Promise.resolve(classifyToxicity(messages)),
      Promise.resolve(scoreEngagement(messages)),
      Promise.resolve(calculatePositivityIndex(messages)),
      Promise.resolve(detectApologyPatterns(messages)), // NEW: Apology/reconciliation analysis
    ])

    // Extract results from settled promises with fallback values for failed modules
    const extractSettledResult = (result, defaultValue) =>
      result.status === 'fulfilled' ? result.value : defaultValue

    const sentiment = extractSettledResult(analysisResults[0], { summary: 'Analysis unavailable', data: null })
    const sentimentComparison = extractSettledResult(analysisResults[1], { summary: 'Analysis unavailable', data: null })
    const communicationPatterns = extractSettledResult(analysisResults[2], { summary: 'Analysis unavailable', data: null })
    const doubleTexting = extractSettledResult(analysisResults[3], { summary: 'Analysis unavailable', data: null })
    const streakTiming = extractSettledResult(analysisResults[4], { summary: 'Analysis unavailable', data: null })
    const weekdayWeekend = extractSettledResult(analysisResults[5], { summary: 'Analysis unavailable', data: null })
    const responseTimes = extractSettledResult(analysisResults[6], { summary: 'Analysis unavailable', data: null })
    const callbacks = extractSettledResult(analysisResults[7], { summary: 'Analysis unavailable', data: null })
    const toxicity = extractSettledResult(analysisResults[8], { summary: 'Analysis unavailable', data: null })
    const engagement = extractSettledResult(analysisResults[9], { summary: 'Analysis unavailable', data: null })
    const positivity = extractSettledResult(analysisResults[10], { summary: 'Analysis unavailable', data: null })
    const apologyPatterns = extractSettledResult(analysisResults[11], { summary: 'Analysis unavailable', hasApologies: false })

    // Step 4: Compile comprehensive report
    const report = {
      success: true,
      timestamp: new Date().toISOString(),
      stats,
      metrics: {
        sentiment,
        sentimentComparison,
        communicationPatterns,
        doubleTexting,
        streakTiming,
        weekdayWeekend,
        responseTimes,
        callbacks,
        toxicity,
        engagement,
        positivity,
        apologyPatterns, // NEW: Apology/reconciliation analysis
      },
      summary: generateComprehensiveSummary({
        sentiment,
        doubleTexting,
        responseTimes,
        toxicity,
        engagement,
        positivity,
      }),
      insights: extractKeyInsights({
        doubleTexting,
        weekdayWeekend,
        responseTimes,
        engagement,
        positivity,
      }),
      recommendations: generateRecommendations({
        toxicity,
        engagement,
        positivity,
        responseTimes,
      }),
    }

    // ARCHITECTURAL FIX: Transform to UI-compatible format
    // Include message excerpts for LLM deep analysis
    return transformForUI(report, messages, personalization)
  } catch (error) {
    console.error('Analysis error:', error)
    return {
      success: false,
      error: error.message,
      errorDetails: error.stack,
    }
  }
}

/**
 * Generate comprehensive summary
 * @param {Object} metrics - All metrics
 * @returns {string} Summary text
 */
function generateComprehensiveSummary(metrics) {
  const sections = []

  // Overall health
  sections.push(`🏥 Overall Relationship Health: ${metrics.positivity.health.toUpperCase()} (${metrics.positivity.score}/100)`)
  sections.push(metrics.positivity.summary)

  // Sentiment analysis
  sections.push(`\n💭 Sentiment Profile: ${metrics.sentiment.sentiment.toUpperCase()}`)
  sections.push(metrics.sentiment.summary)

  // Double texting
  if (metrics.doubleTexting.hasDoubleTexts) {
    sections.push(`\n📱 Double Texting Pattern Detected`)
    sections.push(metrics.doubleTexting.comparison.interpretation)
    sections.push(`Your investment score: ${metrics.doubleTexting.you.investmentScore}/100`)
    sections.push(`Their investment score: ${metrics.doubleTexting.them.investmentScore}/100`)
  }

  // Response times
  if (metrics.responseTimes.you.average) {
    sections.push(`\n⏱️ Response Times`)
    sections.push(`You: ${metrics.responseTimes.you.average} avg (${metrics.responseTimes.you.averageReadiness})`)
    sections.push(`Them: ${metrics.responseTimes.them.average} avg (${metrics.responseTimes.them.averageReadiness})`)
  }

  // Toxicity
  if (metrics.toxicity.hasToxicity) {
    sections.push(`\n⚠️ Toxicity Alert: ${metrics.toxicity.level.toUpperCase()}`)
    sections.push(metrics.toxicity.summary)
  } else {
    sections.push(`\n✨ Clean Communication: No significant toxicity detected`)
  }

  // Engagement
  sections.push(`\n❤️ Emotional Engagement: ${metrics.engagement.level.toUpperCase()} (${metrics.engagement.overallScore}/100)`)
  sections.push(metrics.engagement.summary)

  return sections.join('\n')
}

/**
 * Extract key insights
 * @param {Object} metrics - Key metrics
 * @returns {Array} Insights
 */
function extractKeyInsights(metrics) {
  const insights = []

  // Double texting insight
  if (metrics.doubleTexting.hasDoubleTexts) {
    const diff = metrics.doubleTexting.comparison.difference
    if (diff > 20) {
      const person = metrics.doubleTexting.comparison.moreInvested
      insights.push({
        category: 'Investment Level',
        insight: `${person === 'you' ? 'You' : 'They'} show significantly higher investment through double texting patterns`,
        importance: 'high',
      })
    }
  }

  // Weekday vs weekend pattern
  if (metrics.weekdayWeekend.patterns && metrics.weekdayWeekend.patterns.length > 0) {
    insights.push({
      category: 'Availability',
      insight: `${metrics.weekdayWeekend.patterns[0].name}: ${metrics.weekdayWeekend.patterns[0].description}`,
      importance: 'medium',
    })
  }

  // Response time insight
  if (metrics.responseTimes.you.average && metrics.responseTimes.them.average) {
    const comparison = metrics.responseTimes.comparison
    if (comparison.faster !== 'equal') {
      insights.push({
        category: 'Responsiveness',
        insight: `${comparison.faster === 'you' ? 'You' : 'They'} respond ${comparison.percentDifference}% faster on average`,
        importance: 'medium',
      })
    }
  }

  // Engagement insight
  if (metrics.engagement.you.drivers && metrics.engagement.you.drivers.length > 0) {
    insights.push({
      category: 'Engagement',
      insight: `Your main engagement driver is ${metrics.engagement.you.drivers[0].name.toLowerCase()}`,
      importance: 'low',
    })
  }

  // Health trend
  if (metrics.positivity.trend && metrics.positivity.trend !== 'insufficient_data') {
    insights.push({
      category: 'Trend',
      insight: `Relationship is ${metrics.positivity.trend} over time`,
      importance: metrics.positivity.trend === 'declining' ? 'high' : 'low',
    })
  }

  return insights.sort((a, b) => {
    const importanceMap = { high: 0, medium: 1, low: 2 }
    return importanceMap[a.importance] - importanceMap[b.importance]
  })
}

/**
 * Generate recommendations
 * @param {Object} metrics - Key metrics
 * @returns {Array} Recommendations
 */
function generateRecommendations(metrics) {
  const recommendations = []

  // Toxicity recommendation
  if (metrics.toxicity.level === 'high' || metrics.toxicity.level === 'severe') {
    recommendations.push({
      priority: 'high',
      action: 'Address Toxicity',
      details: 'Consider having a calm discussion about communication style. Try using "I feel" statements instead of blaming.',
    })
  }

  // Engagement recommendation
  if (metrics.engagement.overallScore < 40) {
    recommendations.push({
      priority: 'high',
      action: 'Increase Engagement',
      details: 'Try asking more questions, using emoji, or sharing more personal details to deepen connection.',
    })
  }

  // Response time recommendation
  if (metrics.responseTimes.you.averageMs && metrics.responseTimes.them.averageMs) {
    const ratio = Math.max(metrics.responseTimes.you.averageMs, metrics.responseTimes.them.averageMs) /
                  Math.min(metrics.responseTimes.you.averageMs, metrics.responseTimes.them.averageMs)

    if (ratio > 3) {
      const slower = metrics.responseTimes.you.averageMs > metrics.responseTimes.them.averageMs ? 'you' : 'them'
      recommendations.push({
        priority: 'medium',
        action: 'Improve Response Time',
        details: `${slower === 'you' ? 'You' : 'They'} take significantly longer to respond. Try checking messages more often.`,
      })
    }
  }

  // Health recommendation
  if (metrics.positivity.score < 40) {
    recommendations.push({
      priority: 'high',
      action: 'Assess Relationship Health',
      details: metrics.positivity.recommendation,
    })
  } else if (metrics.positivity.score >= 70) {
    recommendations.push({
      priority: 'low',
      action: 'Maintain Momentum',
      details: 'Relationship is healthy! Continue investing in open communication and positive interactions.',
    })
  }

  return recommendations.sort((a, b) => {
    const priorityMap = { high: 0, medium: 1, low: 2 }
    return priorityMap[a.priority] - priorityMap[b.priority]
  })
}

/**
 * Transform ML report to UI-compatible format
 * Maps nested metrics structure to flat structure expected by UI components
 * ENHANCED: Now includes per-person sections for detailed breakdowns
 * @param {Object} report - Raw ML analysis report
 * @param {Array} messages - Raw messages for LLM excerpts
 * @returns {Object} UI-compatible report
 */
function transformForUI(report, messages = [], personalization = null) {
  const { stats, metrics, timestamp, summary, insights, recommendations } = report

  // ARCHITECTURAL FIX: Extract message excerpts for LLM deep analysis
  // Select a representative sample of messages (not too many to avoid payload size issues)
  const messageExcerpts = extractMessageExcerpts(messages)

  // Format date for display
  const date = new Date(timestamp).toLocaleDateString('en-US', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })

  // ARCHITECTURAL FIX: Map nested metrics to flat UI structure with per-person sections
  return {
    // Top-level summary stats (for ResultsSection header cards)
    healthScore: metrics.positivity?.score || 0,
    messageCount: stats?.totalMessages || 0,
    date,

    // Metrics for MetricsExplorer - ENHANCED with sections for per-person breakdowns
    // ARCHITECTURAL FIX: Map actual classifier property names correctly
    sentiment: {
      value: `${metrics.sentiment?.sentiment || 'Unknown'} (${Math.round((metrics.sentiment?.overallScore || 0) * 100)}/100)`,
      // sentimentComparison has youSentiment/themSentiment properties
      sections: metrics.sentimentComparison?.youSentiment && metrics.sentimentComparison?.themSentiment ? {
        you: {
          score: Math.round((metrics.sentimentComparison.youSentiment.score || 0) * 100),
          sentiment: metrics.sentimentComparison.youSentiment.sentiment || 'Unknown',
          messageCount: metrics.sentimentComparison.youSentiment.messageCount || 0,
        },
        them: {
          score: Math.round((metrics.sentimentComparison.themSentiment.score || 0) * 100),
          sentiment: metrics.sentimentComparison.themSentiment.sentiment || 'Unknown',
          messageCount: metrics.sentimentComparison.themSentiment.messageCount || 0,
        },
      } : null,
      comparison: metrics.sentimentComparison?.comparison ? {
        morePositive: metrics.sentimentComparison.comparison.morePositive || 'equal',
        interpretation: metrics.sentimentComparison.comparison.interpretation || '',
      } : null,
      summary: metrics.sentiment?.summary || '',
      details: [],
    },

    patterns: {
      // communicationPatterns.frequency has the per-person data
      value: `${metrics.communicationPatterns?.frequency?.total || 0} messages`,
      sections: metrics.communicationPatterns?.frequency ? {
        you: {
          messageCount: metrics.communicationPatterns.frequency.youInitiated || 0,
          averageLength: metrics.communicationPatterns.frequency.averageMessageLength?.you || 0,
          questions: metrics.communicationPatterns.engagement?.questions?.you || 0,
          emoji: metrics.communicationPatterns.engagement?.emoji?.you || 0,
        },
        them: {
          messageCount: metrics.communicationPatterns.frequency.theyResponded || 0,
          averageLength: metrics.communicationPatterns.frequency.averageMessageLength?.them || 0,
          questions: metrics.communicationPatterns.engagement?.questions?.them || 0,
          emoji: metrics.communicationPatterns.engagement?.emoji?.them || 0,
        },
      } : null,
      comparison: metrics.communicationPatterns?.frequency ? {
        whoTextsMore: metrics.communicationPatterns.frequency.youInitiated > metrics.communicationPatterns.frequency.theyResponded ? 'you' :
                      metrics.communicationPatterns.frequency.youInitiated < metrics.communicationPatterns.frequency.theyResponded ? 'them' : 'equal',
        whoWritesLonger: metrics.communicationPatterns.frequency.averageMessageLength?.longer || 'equal',
        balance: metrics.communicationPatterns.frequency.balance?.interpretation || '',
      } : null,
      summary: metrics.communicationPatterns?.summary || '',
      details: [],
    },

    engagement: {
      value: `${metrics.engagement?.level || 'Unknown'} (${metrics.engagement?.overallScore || 0}/100)`,
      // engagement has you/them with score, level, messageCount, drivers
      sections: metrics.engagement?.you && metrics.engagement?.them ? {
        you: {
          score: metrics.engagement.you.score || 0,
          level: metrics.engagement.you.level || 'unknown',
          messageCount: metrics.engagement.you.messageCount || 0,
          topDriver: metrics.engagement.you.drivers?.[0]?.name || 'None',
        },
        them: {
          score: metrics.engagement.them.score || 0,
          level: metrics.engagement.them.level || 'unknown',
          messageCount: metrics.engagement.them.messageCount || 0,
          topDriver: metrics.engagement.them.drivers?.[0]?.name || 'None',
        },
      } : null,
      comparison: metrics.engagement?.comparison ? {
        whoIsMoreEngaged: metrics.engagement.comparison.moreEngaged || 'equal',
        scoreDifference: metrics.engagement.comparison.difference || 0,
        interpretation: metrics.engagement.comparison.interpretation || '',
      } : null,
      summary: metrics.engagement?.summary || '',
      details: [],
    },

    // Double texting with enhanced per-person data
    conflict: {
      value: `${metrics.doubleTexting?.totalDoubleTexts || 0} double texts`,
      sections: metrics.doubleTexting?.you && metrics.doubleTexting?.them ? {
        you: {
          doubleTexts: metrics.doubleTexting.you.doubleTexts || 0,
          tripleTexts: metrics.doubleTexting.you.tripleTexts || 0,
          quadPlusTexts: metrics.doubleTexting.you.quadPlusTexts || 0,
          longestStreak: metrics.doubleTexting.you.longestStreak || 0,
          investmentScore: metrics.doubleTexting.you.investmentScore || 0,
          averageStreakLength: metrics.doubleTexting.you.averageStreakLength || 0,
        },
        them: {
          doubleTexts: metrics.doubleTexting.them.doubleTexts || 0,
          tripleTexts: metrics.doubleTexting.them.tripleTexts || 0,
          quadPlusTexts: metrics.doubleTexting.them.quadPlusTexts || 0,
          longestStreak: metrics.doubleTexting.them.longestStreak || 0,
          investmentScore: metrics.doubleTexting.them.investmentScore || 0,
          averageStreakLength: metrics.doubleTexting.them.averageStreakLength || 0,
        },
      } : null,
      comparison: metrics.doubleTexting?.comparison ? {
        whoDoubleTextsMore: metrics.doubleTexting.comparison.whoDoubleTextsMore || 'equal',
        whoTripleTextsMore: metrics.doubleTexting.comparison.whoTripleTextsMore || 'equal',
        moreInvested: metrics.doubleTexting.comparison.moreInvested || 'equal',
        investmentDifference: metrics.doubleTexting.comparison.difference || 0,
        interpretation: metrics.doubleTexting.comparison.interpretation || '',
      } : null,
      summary: metrics.doubleTexting?.summary || metrics.doubleTexting?.analysis || '',
      details: [],
    },

    // Toxicity with per-person breakdown
    // toxicity has you.toxicity, you.toxicMessages
    toxicity: {
      value: `${metrics.toxicity?.level || 'Unknown'} (${Math.round((metrics.toxicity?.overallToxicity || 0) * 100)}/100)`,
      sections: metrics.toxicity?.you && metrics.toxicity?.them ? {
        you: {
          toxicity: Math.round((metrics.toxicity.you.toxicity || 0) * 100),
          toxicMessages: metrics.toxicity.you.toxicMessages || 0,
        },
        them: {
          toxicity: Math.round((metrics.toxicity.them.toxicity || 0) * 100),
          toxicMessages: metrics.toxicity.them.toxicMessages || 0,
        },
      } : null,
      comparison: metrics.toxicity?.you && metrics.toxicity?.them ? {
        whoIsMoreToxic: metrics.toxicity.you.toxicity > metrics.toxicity.them.toxicity ? 'you' :
                        metrics.toxicity.you.toxicity < metrics.toxicity.them.toxicity ? 'them' : 'equal',
        scoreDifference: Math.abs(Math.round((metrics.toxicity.you.toxicity - metrics.toxicity.them.toxicity) * 100)),
      } : null,
      summary: metrics.toxicity?.summary || '',
      details: [],
    },

    // Positivity/Health with per-person breakdown
    // positivity now has you/them with score, positiveCount, negativeCount, neutralCount, ratio, level
    positivity: {
      value: `${metrics.positivity?.health || 'Unknown'} (${metrics.positivity?.score || 0}/100)`,
      sections: metrics.positivity?.you && metrics.positivity?.them ? {
        you: {
          score: metrics.positivity.you.score || 0,
          positiveCount: metrics.positivity.you.positiveCount || 0,
          negativeCount: metrics.positivity.you.negativeCount || 0,
          neutralCount: metrics.positivity.you.neutralCount || 0,
          level: metrics.positivity.you.level || 'unknown',
        },
        them: {
          score: metrics.positivity.them.score || 0,
          positiveCount: metrics.positivity.them.positiveCount || 0,
          negativeCount: metrics.positivity.them.negativeCount || 0,
          neutralCount: metrics.positivity.them.neutralCount || 0,
          level: metrics.positivity.them.level || 'unknown',
        },
      } : null,
      comparison: metrics.positivity?.comparison ? {
        whoIsMorePositive: metrics.positivity.comparison.morePositive || 'equal',
        scoreDifference: metrics.positivity.comparison.scoreDiff || 0,
        interpretation: metrics.positivity.comparison.interpretation || '',
      } : null,
      summary: metrics.positivity?.summary || '',
      details: [],
    },

    // NEW: Apology patterns with per-person breakdown
    apologyPatterns: {
      value: `${metrics.apologyPatterns?.totalApologies || 0} apologies`,
      sections: metrics.apologyPatterns?.you && metrics.apologyPatterns?.them ? {
        you: {
          totalApologies: metrics.apologyPatterns.you.totalApologies || 0,
          explicitApologies: metrics.apologyPatterns.you.explicitApologies || 0,
          softApologies: metrics.apologyPatterns.you.softApologies || 0,
          averageSincerity: metrics.apologyPatterns.you.averageSincerity || 0,
          reconciliationAttempts: metrics.apologyPatterns.you.reconciliationAttempts || 0,
          firstToApologize: metrics.apologyPatterns.you.firstToApologize || 0,
        },
        them: {
          totalApologies: metrics.apologyPatterns.them.totalApologies || 0,
          explicitApologies: metrics.apologyPatterns.them.explicitApologies || 0,
          softApologies: metrics.apologyPatterns.them.softApologies || 0,
          averageSincerity: metrics.apologyPatterns.them.averageSincerity || 0,
          reconciliationAttempts: metrics.apologyPatterns.them.reconciliationAttempts || 0,
          firstToApologize: metrics.apologyPatterns.them.firstToApologize || 0,
        },
      } : null,
      comparison: metrics.apologyPatterns?.comparison ? {
        whoApologizesMore: metrics.apologyPatterns.comparison.whoApologizesMore || 'equal',
        apologyDifference: metrics.apologyPatterns.comparison.apologyDifference || 0,
        balanceScore: metrics.apologyPatterns.comparison.balanceScore || 50,
        reconciliationBalance: metrics.apologyPatterns.comparison.reconciliationBalance || 50,
      } : null,
      reconciliation: metrics.apologyPatterns?.reconciliation || null,
      summary: metrics.apologyPatterns?.summary || '',
      details: [],
    },

    // Keep original nested structure for advanced features (LLM, exports)
    rawMetrics: metrics,
    rawStats: stats,
    metrics, // For ExportButton compatibility
    stats,   // For ExportButton compatibility
    summary,
    insights,
    recommendations,
    timestamp,
    success: true,

    // ARCHITECTURAL FIX: Include message excerpts for LLM deep analysis
    messageExcerpts,

    // PERSONALIZATION: Include user-provided names and insights goal for UI components
    personalization: personalization || { userName: 'You', contactName: 'Them', insightsGoal: '' },
  }
}

/**
 * Extract representative message excerpts for LLM analysis
 * Selects a diverse sample including positive, negative, and neutral messages
 * @param {Array} messages - All parsed messages
 * @returns {Array} Selected message excerpts (max 50)
 */
function extractMessageExcerpts(messages) {
  if (!messages || messages.length === 0) return []

  const MAX_EXCERPTS = 50
  const excerpts = []

  // Sort messages by different criteria to get diverse sample
  const sortedByLength = [...messages].sort((a, b) => (b.content?.length || 0) - (a.content?.length || 0))

  // Get longest messages (often most substantive)
  const longestMessages = sortedByLength.slice(0, 10)

  // Get messages with questions (shows engagement)
  const questionMessages = messages.filter(m => (m.content || '').includes('?')).slice(0, 10)

  // Get messages with emoji (shows emotion)
  const emojiPattern = /[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]/gu
  const emojiMessages = messages.filter(m => emojiPattern.test(m.content || '')).slice(0, 10)

  // Get evenly distributed messages throughout conversation
  const step = Math.max(1, Math.floor(messages.length / 20))
  const distributedMessages = []
  for (let i = 0; i < messages.length && distributedMessages.length < 20; i += step) {
    distributedMessages.push(messages[i])
  }

  // Combine and deduplicate
  const allSelected = [...longestMessages, ...questionMessages, ...emojiMessages, ...distributedMessages]
  const seen = new Set()

  for (const msg of allSelected) {
    if (excerpts.length >= MAX_EXCERPTS) break
    const key = `${msg.sender}:${msg.content?.substring(0, 50)}`
    if (!seen.has(key)) {
      seen.add(key)
      excerpts.push({
        sender: msg.sender || 'Unknown',
        direction: msg.direction || 'unknown',
        content: (msg.content || '').substring(0, 300), // Limit content length
        timestamp: msg.timestamp ? new Date(msg.timestamp).toISOString() : null,
      })
    }
  }

  return excerpts
}

/**
 * Run quick analysis (summary only, skips deep metrics)
 * @param {Array} messages - Parsed messages
 * @returns {Object} Quick analysis summary
 */
export function runQuickAnalysis(messages) {
  if (!messages || messages.length < 2) {
    return { error: 'Need at least 2 messages' }
  }

  const sentiment = analyzeSentiment(messages)
  const engagement = scoreEngagement(messages)
  const positivity = calculatePositivityIndex(messages)
  const doubleTexting = detectDoubleTexting(messages)

  return {
    sentiment: sentiment.sentiment,
    sentimentScore: sentiment.overallScore,
    engagementLevel: engagement.level,
    engagementScore: engagement.overallScore,
    relationshipHealth: positivity.health,
    healthScore: positivity.score,
    hasDoubleTexts: doubleTexting.hasDoubleTexts,
    investmentLevel: doubleTexting.comparison.moreInvested,
  }
}

/**
 * Export analysis report as JSON
 * @param {Object} report - Full analysis report
 * @returns {string} JSON string
 */
export function exportAnalysisJSON(report) {
  return JSON.stringify(report, null, 2)
}

/**
 * Export analysis report as CSV
 * @param {Object} report - Full analysis report
 * @returns {string} CSV string
 */
export function exportAnalysisCSV(report) {
  const metrics = report.metrics
  const data = [
    ['Metric', 'Value'],
    ['Overall Health', report.metrics.positivity.health],
    ['Health Score', report.metrics.positivity.score],
    ['Sentiment', metrics.sentiment.sentiment],
    ['Sentiment Score', metrics.sentiment.overallScore],
    ['Engagement Level', metrics.engagement.level],
    ['Engagement Score', metrics.engagement.overallScore],
    ['Toxicity Level', metrics.toxicity.level],
    ['Double Texting', metrics.doubleTexting.hasDoubleTexts ? 'Yes' : 'No'],
    ['Your Investment Score', metrics.doubleTexting.you.investmentScore],
    ['Their Investment Score', metrics.doubleTexting.them.investmentScore],
    ['Avg Response Time (You)', metrics.responseTimes.you.average],
    ['Avg Response Time (Them)', metrics.responseTimes.them.average],
    ['Messages Analyzed', report.stats.totalMessages],
    ['Unique Senders', report.stats.uniqueSenders],
  ]

  return data.map((row) => row.join(',')).join('\n')
}
