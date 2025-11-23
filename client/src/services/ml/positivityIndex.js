/**
 * positivityIndex.js
 * Calculates overall relationship health positivity score
 * Combines sentiment, engagement, and reduces based on toxicity
 *
 * ARCHITECTURAL FIX: Uses comprehensive keyword lists for accurate scoring
 */

// Extended sentiment keywords for more accurate analysis
const POSITIVE_KEYWORDS = [
  // Strong positive
  'love', 'amazing', 'wonderful', 'fantastic', 'excellent', 'awesome',
  'beautiful', 'perfect', 'incredible', 'outstanding', 'brilliant',
  'delighted', 'thrilled', 'ecstatic', 'adore', 'cherish',
  // Moderate positive
  'good', 'great', 'nice', 'happy', 'glad', 'pleased', 'enjoyed',
  'like', 'lovely', 'sweet', 'kind', 'thoughtful', 'cool', 'fun',
  'exciting', 'interesting', 'appreciate', 'grateful', 'thankful',
  'proud', 'confident', 'hopeful', 'comfortable', 'relaxed',
  // Casual positive
  'haha', 'lol', 'lmao', 'hehe', 'yay', 'woo', 'yes', 'yeah',
  'definitely', 'absolutely', 'totally', 'exactly', 'perfect'
]

const NEGATIVE_KEYWORDS = [
  // Strong negative
  'hate', 'horrible', 'terrible', 'awful', 'disgusting', 'despise',
  'furious', 'devastated', 'miserable', 'pathetic', 'angry',
  // Moderate negative
  'bad', 'sad', 'disappointed', 'upset', 'annoyed', 'frustrated',
  'worried', 'concerned', 'confused', 'stressed', 'tired',
  'dislike', 'gross', 'ugh', 'yuck', 'blah', 'boring', 'annoying',
  'irritating', 'stupid', 'dumb', 'ridiculous', 'pathetic',
  // Dismissive
  'whatever', 'nevermind', 'forget it', 'dont care', "don't care",
  'leave me alone', 'go away'
]

const TOXIC_KEYWORDS = [
  // Explicit toxicity
  'hate you', 'fuck you', 'fuck off', 'go to hell', 'kill yourself',
  'worthless', 'useless', 'pathetic', 'loser', 'idiot', 'stupid',
  'moron', 'dumb', 'shut up', 'screw you',
  // Manipulation/Control
  'youre crazy', "you're crazy", 'gaslighting', 'manipulative',
  'controlling', 'abusive', 'toxic',
  // Individual toxic words
  'fuck', 'shit', 'bullshit', 'asshole', 'bitch', 'bastard'
]

/**
 * Calculate positivity index for relationship
 * This is the OVERALL HEALTH SCORE of the relationship (0-100)
 * @param {Array} messages - Normalized messages
 * @returns {Object} Positivity analysis
 */
export function calculatePositivityIndex(messages) {
  if (!messages || messages.length < 2) {
    return {
      score: 0,
      health: 'unknown',
      summary: 'Need at least 2 messages for analysis',
    }
  }

  // We'll need to import and use other analysis functions
  // For now, create a local calculation
  const components = calculateHealthComponents(messages)
  const finalScore = calculateFinalScore(components)
  const health = determineRelationshipHealth(finalScore)
  const trend = detectTrend(messages)

  // ARCHITECTURAL FIX: Add per-person positivity breakdown
  const perPersonData = calculatePerPersonPositivity(messages)

  return {
    score: finalScore,
    health,
    trend,
    components,
    // NEW: Per-person breakdown for UI display
    you: perPersonData.you,
    them: perPersonData.them,
    comparison: perPersonData.comparison,
    indicators: generateHealthIndicators(messages, finalScore),
    recommendation: generateRecommendation(finalScore, components),
    summary: generatePositivitySummary(finalScore, health, components),
  }
}

/**
 * Calculate per-person positivity metrics
 * Breaks down positivity for "you" vs "them" to show who contributes more positively
 * @param {Array} messages - Messages
 * @returns {Object} Per-person positivity data
 */
function calculatePerPersonPositivity(messages) {
  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  const yourPositivity = calculateIndividualPositivity(sent)
  const theirPositivity = calculateIndividualPositivity(received)

  // Determine who is more positive
  let morePositive = 'equal'
  const scoreDiff = Math.abs(yourPositivity.score - theirPositivity.score)
  if (scoreDiff > 5) {
    morePositive = yourPositivity.score > theirPositivity.score ? 'you' : 'them'
  }

  return {
    you: yourPositivity,
    them: theirPositivity,
    comparison: {
      morePositive,
      scoreDiff: parseFloat(scoreDiff.toFixed(1)),
      interpretation: generatePositivityComparison(yourPositivity.score, theirPositivity.score),
    },
  }
}

/**
 * Calculate positivity score for one person's messages
 * @param {Array} messages - Messages from one party
 * @returns {Object} Positivity metrics
 */
function calculateIndividualPositivity(messages) {
  if (messages.length === 0) {
    return {
      score: 0,
      positiveCount: 0,
      negativeCount: 0,
      neutralCount: 0,
      ratio: 0,
      level: 'unknown',
    }
  }

  let positiveCount = 0
  let negativeCount = 0

  // Positive emoji patterns
  const positiveEmoji = /[\u{1F600}-\u{1F64F}]|[\u{2764}\u{1F495}-\u{1F49F}]|[\u{1F389}\u{1F38A}]|👍|🎉|❤️|😊|😍|🥰|💕|✨|🔥|💯/gu

  // Negative emoji patterns
  const negativeEmoji = /😢|😞|😡|😠|💔|👎|😒|🙄|😤|😭|😫|😩|😔/gu

  for (const m of messages) {
    const text = (m.content || '').toLowerCase()
    let isPositive = false
    let isNegative = false

    // Check positive keywords
    for (const keyword of POSITIVE_KEYWORDS) {
      if (text.includes(keyword)) {
        isPositive = true
        break
      }
    }

    // Check negative keywords
    for (const keyword of NEGATIVE_KEYWORDS) {
      if (text.includes(keyword)) {
        isNegative = true
        break
      }
    }

    // Check toxic keywords (strongly negative)
    for (const keyword of TOXIC_KEYWORDS) {
      if (text.includes(keyword)) {
        isNegative = true
        break
      }
    }

    // Check emoji
    if (positiveEmoji.test(m.content || '')) isPositive = true
    if (negativeEmoji.test(m.content || '')) isNegative = true

    if (isPositive && !isNegative) positiveCount++
    else if (isNegative) negativeCount++
  }

  const neutralCount = messages.length - positiveCount - negativeCount
  const ratio = messages.length > 0 ? parseFloat(((positiveCount - negativeCount) / messages.length).toFixed(2)) : 0

  // Calculate score (0-100)
  const rawScore = ((positiveCount - negativeCount * 2) / messages.length + 0.5) * 100
  const score = Math.max(0, Math.min(100, parseFloat(rawScore.toFixed(0))))

  // Determine level
  let level = 'neutral'
  if (score >= 70) level = 'very_positive'
  else if (score >= 55) level = 'positive'
  else if (score >= 45) level = 'neutral'
  else if (score >= 30) level = 'negative'
  else level = 'very_negative'

  return {
    score,
    positiveCount,
    negativeCount,
    neutralCount,
    ratio,
    level,
    messageCount: messages.length,
  }
}

/**
 * Generate positivity comparison interpretation
 * @param {number} yourScore - Your positivity score
 * @param {number} theirScore - Their positivity score
 * @returns {string} Interpretation
 */
function generatePositivityComparison(yourScore, theirScore) {
  const diff = yourScore - theirScore

  if (Math.abs(diff) <= 5) {
    return 'Both parties show similar levels of positivity in communication'
  } else if (diff > 20) {
    return 'You are significantly more positive in communication'
  } else if (diff > 0) {
    return 'You tend to be slightly more positive in communication'
  } else if (diff < -20) {
    return 'They are significantly more positive in communication'
  } else {
    return 'They tend to be slightly more positive in communication'
  }
}

/**
 * Calculate health components (sub-scores)
 * @param {Array} messages - Messages
 * @returns {Object} Component scores
 */
function calculateHealthComponents(messages) {
  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  // 1. Sentiment Component (40% of score)
  const sentimentComponent = calculateSentimentComponent(messages)

  // 2. Engagement Component (30% of score)
  const engagementComponent = calculateEngagementComponent(messages)

  // 3. Toxicity Component (0-30% reduction)
  const toxicityComponent = calculateToxicityComponent(messages)

  // 4. Effort Component (20% of score)
  const effortComponent = calculateEffortComponent(sent, received)

  // 5. Consistency Component (10% of score)
  const consistencyComponent = calculateConsistencyComponent(messages)

  return {
    sentiment: sentimentComponent,
    engagement: engagementComponent,
    toxicity: toxicityComponent,
    effort: effortComponent,
    consistency: consistencyComponent,
  }
}

/**
 * Calculate sentiment component (0-40)
 * ARCHITECTURAL FIX: Uses comprehensive keyword lists for accurate analysis
 * @param {Array} messages - Messages
 * @returns {number} Sentiment component score
 */
function calculateSentimentComponent(messages) {
  let positiveCount = 0
  let negativeCount = 0

  // Positive emoji patterns
  const positiveEmoji = /[\u{1F600}-\u{1F64F}]|[\u{2764}\u{1F495}-\u{1F49F}]|[\u{1F389}\u{1F38A}]|👍|🎉|❤️|😊|😍|🥰|💕|✨|🔥|💯/gu

  // Negative emoji patterns
  const negativeEmoji = /😢|😞|😡|😠|💔|👎|😒|🙄|😤|😭|😫|😩|😔/gu

  for (const m of messages) {
    const text = (m.content || '').toLowerCase()

    // Check positive keywords
    for (const keyword of POSITIVE_KEYWORDS) {
      if (text.includes(keyword)) {
        positiveCount++
        break // Count each message only once for sentiment
      }
    }

    // Check negative keywords
    for (const keyword of NEGATIVE_KEYWORDS) {
      if (text.includes(keyword)) {
        negativeCount++
        break
      }
    }

    // Check emoji
    if (positiveEmoji.test(m.content || '')) positiveCount += 0.5
    if (negativeEmoji.test(m.content || '')) negativeCount += 0.5
  }

  const sentimentRatio = (positiveCount - negativeCount) / messages.length
  return Math.max(0, Math.min(40, 20 + sentimentRatio * 40))
}

/**
 * Calculate engagement component (0-30)
 * ARCHITECTURAL FIX: Robust property access and enhanced emoji detection
 * @param {Array} messages - Messages
 * @returns {number} Engagement component score
 */
function calculateEngagementComponent(messages) {
  const questions = messages.filter((m) => (m.content || '').includes('?')).length

  // Enhanced emoji detection - all common emoji ranges
  const emojiPattern = /[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]/gu
  const emoji = messages.filter((m) => emojiPattern.test(m.content || '')).length

  // ARCHITECTURAL FIX: Use content.length or m.length, whichever is available
  const avgLength = messages.reduce((sum, m) => {
    const len = m.length || (m.content ? m.content.length : 0)
    return sum + len
  }, 0) / messages.length

  let score = 0
  score += Math.min((questions / messages.length) * 10, 10)
  score += Math.min((emoji / messages.length) * 10, 10)
  score += Math.min((avgLength / 100) * 10, 10)

  return Math.min(30, score)
}

/**
 * Calculate toxicity component (reduction 0-30)
 * ARCHITECTURAL FIX: Uses comprehensive toxic keyword detection
 * @param {Array} messages - Messages
 * @returns {number} Toxicity penalty
 */
function calculateToxicityComponent(messages) {
  let toxicCount = 0

  for (const m of messages) {
    const text = (m.content || '').toLowerCase()
    for (const keyword of TOXIC_KEYWORDS) {
      if (text.includes(keyword)) {
        toxicCount++
        break // Count each message only once
      }
    }
  }

  const toxicityPercentage = (toxicCount / messages.length) * 100

  // More granular toxicity penalties
  if (toxicityPercentage > 50) return -30
  if (toxicityPercentage > 30) return -25
  if (toxicityPercentage > 20) return -20
  if (toxicityPercentage > 10) return -15
  if (toxicityPercentage > 5) return -10
  if (toxicityPercentage > 2) return -5
  return 0
}

/**
 * Calculate effort component (0-20)
 * How much do they invest in the relationship?
 * @param {Array} sent - Your messages
 * @param {Array} received - Their messages
 * @returns {number} Effort score
 */
function calculateEffortComponent(sent, received) {
  if (received.length === 0) return 0

  // Do they respond to your messages?
  const responseRate = Math.min(received.length / Math.max(sent.length, 1), 1)

  // Do they send long messages?
  const avgTheirLength = received.reduce((sum, m) => sum + (m.length || 0), 0) / received.length
  const lengthScore = Math.min(avgTheirLength / 100, 1)

  return (responseRate + lengthScore) / 2 * 20
}

/**
 * Calculate consistency component (0-10)
 * Are response times and engagement consistent?
 * @param {Array} messages - Messages
 * @returns {number} Consistency score
 */
function calculateConsistencyComponent(messages) {
  // Check if messaging is consistent over time
  if (messages.length < 10) return 5

  const gaps = []
  for (let i = 1; i < messages.length; i++) {
    const gap = messages[i].timestamp.getTime() - messages[i - 1].timestamp.getTime()
    gaps.push(gap)
  }

  const avgGap = gaps.reduce((a, b) => a + b) / gaps.length
  const variance = gaps.reduce((sum, gap) => sum + Math.pow(gap - avgGap, 2), 0) / gaps.length
  const stdDev = Math.sqrt(variance)
  const cv = stdDev / avgGap

  if (cv < 0.5) return 10 // Very consistent
  if (cv < 1.0) return 7.5 // Somewhat consistent
  if (cv < 2.0) return 5 // Variable
  return 2.5 // Highly inconsistent
}

/**
 * Calculate final positivity score (0-100)
 * @param {Object} components - Component scores
 * @returns {number} Final score
 */
function calculateFinalScore(components) {
  const baseScore = components.sentiment + components.engagement + components.effort + components.consistency

  let finalScore = baseScore + components.toxicity // toxicity is negative

  return Math.max(0, Math.min(100, parseFloat(finalScore.toFixed(0))))
}

/**
 * Determine relationship health level
 * @param {number} score - Positivity score
 * @returns {string} Health level
 */
function determineRelationshipHealth(score) {
  if (score >= 80) return 'excellent'
  if (score >= 60) return 'good'
  if (score >= 40) return 'moderate'
  if (score >= 20) return 'poor'
  return 'toxic'
}

/**
 * Detect score trend (improving or declining)
 * @param {Array} messages - Messages
 * @returns {string} Trend
 */
function detectTrend(messages) {
  if (messages.length < 10) return 'insufficient_data'

  const firstHalf = messages.slice(0, Math.floor(messages.length / 2))
  const secondHalf = messages.slice(Math.floor(messages.length / 2))

  const firstScore = calculateSentimentComponent(firstHalf) / 40
  const secondScore = calculateSentimentComponent(secondHalf) / 40

  if (secondScore > firstScore + 0.1) return 'improving'
  if (secondScore < firstScore - 0.1) return 'declining'
  return 'stable'
}

/**
 * Generate health indicators
 * @param {Array} messages - Messages
 * @param {number} score - Positivity score
 * @returns {Array} Indicators
 */
function generateHealthIndicators(messages, score) {
  const indicators = []

  const sent = messages.filter((m) => m.direction === 'sent').length
  const received = messages.filter((m) => m.direction === 'received').length
  const questions = messages.filter((m) => m.content.includes('?')).length
  const emoji = messages.filter((m) => /[\u{1F300}-\u{1F9FF}]/u.test(m.content)).length

  if (received > sent * 0.8) {
    indicators.push({ type: 'positive', text: 'They engage actively in conversation' })
  }

  if (questions > messages.length * 0.1) {
    indicators.push({ type: 'positive', text: 'Good amount of question asking - shows interest' })
  }

  if (emoji > 0) {
    indicators.push({ type: 'positive', text: 'Using emoji - shows emotional expression' })
  }

  if (score >= 70) {
    indicators.push({ type: 'positive', text: 'Overall positive and healthy communication' })
  }

  if (score < 40) {
    indicators.push({ type: 'warning', text: 'Low engagement and positivity' })
  }

  return indicators
}

/**
 * Generate recommendation
 * @param {number} score - Positivity score
 * @param {Object} components - Component scores
 * @returns {string} Recommendation
 */
function generateRecommendation(score, components) {
  if (score >= 80) {
    return 'Relationship is very healthy! Continue investing in open communication and engagement.'
  }

  if (score >= 60) {
    return 'Relationship is good. Focus on increasing engagement and deepening emotional connection.'
  }

  if (score >= 40) {
    return 'Relationship needs attention. Try increasing positive interactions and being more responsive.'
  }

  if (components.toxicity < 0) {
    return 'Significant toxicity detected. Consider addressing conflicts directly and respectfully.'
  }

  return 'Relationship shows warning signs. Prioritize communication and rebuilding trust.'
}

/**
 * Generate positivity summary
 * @param {number} score - Score
 * @param {string} health - Health level
 * @param {Object} components - Components
 * @returns {string} Summary
 */
function generatePositivitySummary(score, health, components) {
  const summary = []

  summary.push(`Overall relationship health: ${health.toUpperCase()} (${score}/100)`)

  if (components.sentiment > 20) {
    summary.push('Positive sentiment in conversations')
  } else if (components.sentiment < 10) {
    summary.push('Mostly neutral or negative sentiment')
  }

  if (components.engagement > 15) {
    summary.push('Strong emotional engagement between parties')
  } else if (components.engagement < 5) {
    summary.push('Limited emotional engagement')
  }

  if (components.effort > 15) {
    summary.push('Both parties investing significant effort')
  } else if (components.effort < 5) {
    summary.push('Effort may be one-sided')
  }

  return summary.join('. ')
}
