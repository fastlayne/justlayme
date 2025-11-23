/**
 * communicationPatterns.js
 * Analyzes communication patterns: frequency, timing, engagement style, response patterns
 */

/**
 * Analyze communication patterns in conversation
 * @param {Array} messages - Normalized messages
 * @returns {Object} Communication pattern analysis
 */
export function analyzeCommunicationPatterns(messages) {
  if (!messages || messages.length < 2) {
    return {
      frequency: null,
      engagement: null,
      responseStyle: null,
      summary: 'Need at least 2 messages for pattern analysis',
    }
  }

  const frequency = analyzeFrequency(messages)
  const engagement = analyzeEngagement(messages)
  const responseStyle = analyzeResponseStyle(messages)
  const patterns = detectPatterns(messages)

  return {
    frequency,
    engagement,
    responseStyle,
    patterns,
    summary: generatePatternSummary(frequency, engagement, responseStyle),
  }
}

/**
 * Analyze message frequency patterns
 * @param {Array} messages - Normalized messages
 * @returns {Object} Frequency analysis
 */
function analyzeFrequency(messages) {
  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  // Calculate message counts
  const sentCount = sent.length
  const receivedCount = received.length
  const totalCount = messages.length

  // Calculate average message lengths
  const sentAvgLength = sent.length > 0 ? sent.reduce((sum, m) => sum + (m.length || 0), 0) / sent.length : 0
  const receivedAvgLength = received.length > 0 ? received.reduce((sum, m) => sum + (m.length || 0), 0) / received.length : 0

  // Calculate time span
  const timestamps = messages.map((m) => m.timestamp.getTime()).sort((a, b) => a - b)
  const timeSpan = timestamps.length > 1 ? timestamps[timestamps.length - 1] - timestamps[0] : 0
  const timeSpanDays = timeSpan / (1000 * 60 * 60 * 24)

  // Messages per day
  const messagesPerDay = timeSpanDays > 0 ? totalCount / timeSpanDays : totalCount

  // Conversation balance (who talks more?)
  const balance = sentCount > 0 ? (sentCount / (sentCount + receivedCount)) : 0

  return {
    youInitiated: sentCount,
    theyResponded: receivedCount,
    total: totalCount,
    balance: {
      percentage: parseFloat((balance * 100).toFixed(1)),
      interpretation: getBalanceInterpretation(balance),
    },
    averageMessageLength: {
      you: parseFloat(sentAvgLength.toFixed(0)),
      them: parseFloat(receivedAvgLength.toFixed(0)),
      longer: sentAvgLength > receivedAvgLength ? 'you' : sentAvgLength < receivedAvgLength ? 'them' : 'equal',
    },
    timespan: {
      days: parseFloat(timeSpanDays.toFixed(1)),
      messagesPerDay: parseFloat(messagesPerDay.toFixed(2)),
    },
  }
}

/**
 * Get interpretation of message balance
 * @param {number} balance - Balance ratio (0-1)
 * @returns {string} Interpretation
 */
function getBalanceInterpretation(balance) {
  if (balance > 0.65) return 'You initiate most messages - showing high investment'
  if (balance > 0.55) return 'You initiate slightly more - balanced with slight initiative'
  if (balance > 0.45) return 'Nearly equal - very balanced conversation'
  if (balance > 0.35) return 'They initiate slightly more - they show engagement'
  return 'They initiate most messages - showing high investment'
}

/**
 * Analyze engagement level
 * @param {Array} messages - Normalized messages
 * @returns {Object} Engagement analysis
 */
function analyzeEngagement(messages) {
  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  // Question analysis (indicates engagement/interest)
  const sentQuestions = sent.filter((m) => m.content.includes('?')).length
  const receivedQuestions = received.filter((m) => m.content.includes('?')).length

  // Emoji usage (emotional engagement)
  const sentEmoji = sent.filter((m) => /[\u{1F300}-\u{1F9FF}]/u.test(m.content)).length
  const receivedEmoji = received.filter((m) => /[\u{1F300}-\u{1F9FF}]/u.test(m.content)).length

  // Exclamation marks (emotional expression)
  const sentExclamations = sent.reduce((sum, m) => sum + (m.content.match(/!/g) || []).length, 0)
  const receivedExclamations = received.reduce((sum, m) => sum + (m.content.match(/!/g) || []).length, 0)

  // Response times analysis
  const responseTimes = calculateResponseTimes(messages)

  // Engagement score (0-100)
  const engagementScore = calculateEngagementScore({
    questions: sentQuestions + receivedQuestions,
    emoji: sentEmoji + receivedEmoji,
    exclamations: sentExclamations + receivedExclamations,
    messageCount: messages.length,
  })

  return {
    level: engagementScore > 70 ? 'high' : engagementScore > 40 ? 'moderate' : 'low',
    score: engagementScore,
    questions: {
      you: sentQuestions,
      them: receivedQuestions,
      total: sentQuestions + receivedQuestions,
    },
    emoji: {
      you: sentEmoji,
      them: receivedEmoji,
      total: sentEmoji + receivedEmoji,
    },
    exclamations: {
      you: sentExclamations,
      them: receivedExclamations,
      total: sentExclamations + receivedExclamations,
    },
    responseTimes,
  }
}

/**
 * Calculate engagement score
 * @param {Object} factors - Engagement factors
 * @returns {number} Engagement score 0-100
 */
function calculateEngagementScore(factors) {
  let score = 0

  // Questions contribute 30 points
  score += Math.min((factors.questions * 10), 30)

  // Emoji contribute 20 points
  score += Math.min((factors.emoji * 10), 20)

  // Exclamations contribute 20 points
  score += Math.min((factors.exclamations * 3), 20)

  // Message frequency contributes 30 points
  const avgMessages = factors.messageCount / 5 // baseline 5 messages
  score += Math.min(avgMessages * 6, 30)

  return Math.min(100, parseFloat(score.toFixed(0)))
}

/**
 * Calculate response times between messages
 * @param {Array} messages - Normalized messages
 * @returns {Object} Response time analysis
 */
function calculateResponseTimes(messages) {
  const responseTimes = []

  for (let i = 1; i < messages.length; i++) {
    const current = messages[i]
    const previous = messages[i - 1]

    // Only count responses (sent -> received or received -> sent)
    if (current.direction !== previous.direction) {
      const timeDiff = current.timestamp.getTime() - previous.timestamp.getTime()
      responseTimes.push(timeDiff)
    }
  }

  if (responseTimes.length === 0) {
    return { average: null, min: null, max: null, median: null }
  }

  const sorted = [...responseTimes].sort((a, b) => a - b)
  const average = responseTimes.reduce((a, b) => a + b, 0) / responseTimes.length
  const median = sorted[Math.floor(sorted.length / 2)]

  return {
    average: formatTime(average),
    min: formatTime(sorted[0]),
    max: formatTime(sorted[sorted.length - 1]),
    median: formatTime(median),
    count: responseTimes.length,
  }
}

/**
 * Format milliseconds to readable time
 * @param {number} ms - Milliseconds
 * @returns {string} Formatted time
 */
function formatTime(ms) {
  if (ms < 60000) return `${Math.round(ms / 1000)}s`
  if (ms < 3600000) return `${Math.round(ms / 60000)}m`
  if (ms < 86400000) return `${Math.round(ms / 3600000)}h`
  return `${Math.round(ms / 86400000)}d`
}

/**
 * Analyze response style
 * @param {Array} messages - Normalized messages
 * @returns {Object} Response style analysis
 */
function analyzeResponseStyle(messages) {
  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  // One-word responses
  const sentShort = sent.filter((m) => m.content.split(/\s+/).length === 1).length
  const receivedShort = received.filter((m) => m.content.split(/\s+/).length === 1).length

  // Long messages (>100 chars)
  const sentLong = sent.filter((m) => (m.length || 0) > 100).length
  const receivedLong = received.filter((m) => (m.length || 0) > 100).length

  // Conversational style
  const yourStyle = determineStyle(sent)
  const theirStyle = determineStyle(received)

  return {
    you: {
      style: yourStyle,
      shortMessages: sentShort,
      longMessages: sentLong,
    },
    them: {
      style: theirStyle,
      shortMessages: receivedShort,
      longMessages: receivedLong,
    },
    compatibility: assessStyleCompatibility(yourStyle, theirStyle),
  }
}

/**
 * Determine communication style
 * @param {Array} messages - Messages from one party
 * @returns {string} Style classification
 */
function determineStyle(messages) {
  if (messages.length === 0) return 'unknown'

  const avgLength = messages.reduce((sum, m) => sum + (m.length || 0), 0) / messages.length
  const shortCount = messages.filter((m) => (m.length || 0) < 20).length
  const shortRatio = shortCount / messages.length

  if (avgLength > 100) return 'detailed_thoughtful'
  if (shortRatio > 0.5) return 'brief_casual'
  return 'balanced'
}

/**
 * Assess style compatibility
 * @param {string} yourStyle - Your style
 * @param {string} theirStyle - Their style
 * @returns {string} Compatibility assessment
 */
function assessStyleCompatibility(yourStyle, theirStyle) {
  if (yourStyle === theirStyle) {
    return `Both use ${yourStyle} style - great compatibility`
  }
  if ((yourStyle === 'balanced' && theirStyle === 'balanced') ||
      (yourStyle === 'brief_casual' && theirStyle === 'balanced') ||
      (yourStyle === 'balanced' && theirStyle === 'brief_casual')) {
    return 'Compatible communication styles'
  }
  return 'Different communication styles - may need adjustment'
}

/**
 * Detect specific communication patterns
 * @param {Array} messages - Normalized messages
 * @returns {Object} Patterns detected
 */
function detectPatterns(messages) {
  const patterns = {
    hasLongGaps: false,
    hasConsistentTiming: false,
    hasInitiatorPattern: false,
    hasEvenDistribution: false,
  }

  if (messages.length < 3) return patterns

  // Check for long gaps (>24 hours)
  let longGapCount = 0
  for (let i = 1; i < messages.length; i++) {
    const gap = messages[i].timestamp.getTime() - messages[i - 1].timestamp.getTime()
    if (gap > 86400000) longGapCount++
  }
  patterns.hasLongGaps = longGapCount > messages.length * 0.1

  // Check if timing is consistent
  const gaps = []
  for (let i = 1; i < messages.length; i++) {
    gaps.push(messages[i].timestamp.getTime() - messages[i - 1].timestamp.getTime())
  }
  if (gaps.length > 0) {
    const avgGap = gaps.reduce((a, b) => a + b) / gaps.length
    const variance = gaps.reduce((sum, gap) => sum + Math.pow(gap - avgGap, 2), 0) / gaps.length
    const stdDev = Math.sqrt(variance)
    patterns.hasConsistentTiming = stdDev < avgGap * 0.5 // Low variance = consistent
  }

  // Check if one person initiates more
  const sent = messages.filter((m) => m.direction === 'sent').length
  const received = messages.filter((m) => m.direction === 'received').length
  patterns.hasInitiatorPattern = Math.abs(sent - received) > messages.length * 0.3

  // Check for even distribution (no long sequences of one person)
  let maxSequence = 1
  let currentSequence = 1
  for (let i = 1; i < messages.length; i++) {
    if (messages[i].direction === messages[i - 1].direction) {
      currentSequence++
      maxSequence = Math.max(maxSequence, currentSequence)
    } else {
      currentSequence = 1
    }
  }
  patterns.hasEvenDistribution = maxSequence <= 2

  return patterns
}

/**
 * Generate pattern summary
 * @param {Object} frequency - Frequency analysis
 * @param {Object} engagement - Engagement analysis
 * @param {Object} responseStyle - Response style analysis
 * @returns {string} Summary text
 */
function generatePatternSummary(frequency, engagement, responseStyle) {
  const summary = []

  // Frequency summary
  if (frequency.balance.percentage > 60) {
    summary.push('You initiate most conversations')
  } else if (frequency.balance.percentage < 40) {
    summary.push('They initiate most conversations')
  } else {
    summary.push('Balanced conversation initiation')
  }

  // Engagement summary
  if (engagement.level === 'high') {
    summary.push(`High engagement with frequent questions (${engagement.questions.total} total)`)
  } else if (engagement.level === 'low') {
    summary.push('Limited engagement - fewer questions and interactions')
  } else {
    summary.push('Moderate engagement level')
  }

  // Style summary
  if (responseStyle.you.style === responseStyle.them.style) {
    summary.push(`Both use ${responseStyle.you.style} communication style`)
  } else {
    summary.push('Different communication styles - potential for adjustment')
  }

  return summary.join('. ')
}
