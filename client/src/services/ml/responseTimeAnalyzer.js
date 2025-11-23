/**
 * responseTimeAnalyzer.js
 * Analyzes response times and callback patterns
 * Shows attentiveness, availability, and consistency
 */

/**
 * Calculate response times and analyze patterns
 * @param {Array} messages - Normalized messages
 * @returns {Object} Response time analysis
 */
export function analyzeResponseTimes(messages) {
  if (!messages || messages.length < 2) {
    return {
      summary: 'Need at least 2 messages for response time analysis',
      data: null,
    }
  }

  const responseTimes = extractResponseTimes(messages)

  if (responseTimes.length === 0) {
    return {
      summary: 'Unable to calculate response times - need back-and-forth messages',
      data: null,
    }
  }

  // Separate responses by direction
  const yourResponses = responseTimes.filter((r) => r.responder === 'you')
  const theirResponses = responseTimes.filter((r) => r.responder === 'them')

  const yourStats = calculateStats(yourResponses.map((r) => r.time))
  const theirStats = calculateStats(theirResponses.map((r) => r.time))

  return {
    you: {
      count: yourResponses.length,
      ...yourStats,
      averageReadiness: calculateReadiness(yourStats.average),
    },
    them: {
      count: theirResponses.length,
      ...theirStats,
      averageReadiness: calculateReadiness(theirStats.average),
    },
    comparison: compareResponseTimes(yourStats, theirStats),
    patterns: detectResponsePatterns(yourResponses, theirResponses),
    summary: generateResponseTimeSummary(yourStats, theirStats),
  }
}

/**
 * Extract response times (time between sent and received messages)
 * @param {Array} messages - Messages
 * @returns {Array} Response time objects
 */
function extractResponseTimes(messages) {
  const responseTimes = []

  for (let i = 1; i < messages.length; i++) {
    const current = messages[i]
    const previous = messages[i - 1]

    // Only count when direction changes (sent->received or received->sent)
    if (current.direction !== previous.direction) {
      const timeDiff = current.timestamp.getTime() - previous.timestamp.getTime()
      responseTimes.push({
        responder: current.direction === 'received' ? 'them' : 'you',
        time: timeDiff,
        messageIndex: i,
        promptMessage: previous.content.substring(0, 40),
        responseMessage: current.content.substring(0, 40),
      })
    }
  }

  return responseTimes
}

/**
 * Calculate statistics from response times
 * @param {Array} times - Array of milliseconds
 * @returns {Object} Statistics
 */
function calculateStats(times) {
  if (times.length === 0) {
    return { count: 0, average: null, median: null, min: null, max: null }
  }

  const sorted = [...times].sort((a, b) => a - b)
  const sum = times.reduce((a, b) => a + b, 0)
  const average = sum / times.length
  const median = sorted[Math.floor(sorted.length / 2)]

  // Calculate standard deviation to show consistency
  const variance = times.reduce((sum, time) => sum + Math.pow(time - average, 2), 0) / times.length
  const stdDev = Math.sqrt(variance)

  // Percentiles
  const p25 = sorted[Math.floor(sorted.length * 0.25)]
  const p75 = sorted[Math.floor(sorted.length * 0.75)]

  return {
    count: times.length,
    average: formatTime(average),
    averageMs: parseFloat(average.toFixed(0)),
    median: formatTime(median),
    min: formatTime(sorted[0]),
    max: formatTime(sorted[sorted.length - 1]),
    stdDev: formatTime(stdDev),
    percentile25: formatTime(p25),
    percentile75: formatTime(p75),
    consistency: calculateConsistency(stdDev, average),
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
 * Calculate response readiness level
 * @param {string} avgTime - Average formatted time
 * @returns {string} Readiness level
 */
function calculateReadiness(avgTime) {
  if (!avgTime) return 'unknown'

  const ms = parseFloat(avgTime)
  if (avgTime.includes('s')) return 'immediate'
  if (avgTime.includes('m')) {
    const minutes = parseInt(avgTime)
    if (minutes < 5) return 'very_quick'
    if (minutes < 30) return 'quick'
    return 'moderate'
  }
  if (avgTime.includes('h')) return 'slow'
  return 'very_slow'
}

/**
 * Calculate consistency score based on standard deviation
 * @param {number} stdDev - Standard deviation
 * @param {number} average - Average
 * @returns {string} Consistency level
 */
function calculateConsistency(stdDev, average) {
  // CRITICAL FIX: Prevent division by zero
  if (average === 0 || !average) return 'unknown'
  const cv = stdDev / average // Coefficient of variation
  if (cv < 0.5) return 'very_consistent'
  if (cv < 1.0) return 'consistent'
  if (cv < 2.0) return 'somewhat_variable'
  return 'highly_variable'
}

/**
 * Compare response times between parties
 * @param {Object} yourStats - Your stats
 * @param {Object} theirStats - Their stats
 * @returns {Object} Comparison
 */
function compareResponseTimes(yourStats, theirStats) {
  if (!yourStats.averageMs || !theirStats.averageMs) {
    return { comparison: 'insufficient_data' }
  }

  const diff = Math.abs(yourStats.averageMs - theirStats.averageMs)
  const percentDiff = (diff / Math.max(yourStats.averageMs, theirStats.averageMs)) * 100

  let faster = yourStats.averageMs < theirStats.averageMs ? 'you' : 'them'
  let interpretation = ''

  if (percentDiff < 10) {
    faster = 'equal'
    interpretation = 'Both respond with similar speed'
  } else if (percentDiff < 50) {
    interpretation = `${faster === 'you' ? 'You' : 'They'} respond somewhat faster`
  } else {
    interpretation = `${faster === 'you' ? 'You' : 'They'} respond significantly faster`
  }

  return {
    faster,
    timeDifference: formatTime(diff),
    percentDifference: parseFloat(percentDiff.toFixed(1)),
    interpretation,
  }
}

/**
 * Detect response patterns
 * @param {Array} yourResponses - Your responses
 * @param {Array} theirResponses - Their responses
 * @returns {Object} Patterns
 */
function detectResponsePatterns(yourResponses, theirResponses) {
  const patterns = []

  // Check for immediate responses (< 1 minute)
  const yourImmediate = yourResponses.filter((r) => r.time < 60000).length
  const theirImmediate = theirResponses.filter((r) => r.time < 60000).length

  if (yourImmediate > yourResponses.length * 0.3) {
    patterns.push({
      type: 'immediate_responder',
      party: 'you',
      indicator: `You respond immediately ${((yourImmediate / yourResponses.length) * 100).toFixed(0)}% of the time`,
    })
  }

  if (theirImmediate > theirResponses.length * 0.3) {
    patterns.push({
      type: 'immediate_responder',
      party: 'them',
      indicator: `They respond immediately ${((theirImmediate / theirResponses.length) * 100).toFixed(0)}% of the time`,
    })
  }

  // Check for slow responses (> 1 hour)
  const yourSlow = yourResponses.filter((r) => r.time > 3600000).length
  const theirSlow = theirResponses.filter((r) => r.time > 3600000).length

  if (theirSlow > theirResponses.length * 0.3) {
    patterns.push({
      type: 'slow_responder',
      party: 'them',
      indicator: `They take over an hour to respond ${((theirSlow / theirResponses.length) * 100).toFixed(0)}% of the time`,
    })
  }

  // Check for inconsistency (high variance)
  const yourTimes = yourResponses.map((r) => r.time)
  const theirTimes = theirResponses.map((r) => r.time)

  if (yourTimes.length > 0) {
    const yourVariance = calculateVariance(yourTimes)
    if (yourVariance > 1.5) {
      patterns.push({
        type: 'inconsistent',
        party: 'you',
        indicator: 'Your response times vary significantly',
      })
    }
  }

  if (theirTimes.length > 0) {
    const theirVariance = calculateVariance(theirTimes)
    if (theirVariance > 1.5) {
      patterns.push({
        type: 'inconsistent',
        party: 'them',
        indicator: 'Their response times vary significantly',
      })
    }
  }

  return patterns
}

/**
 * Calculate coefficient of variation
 * @param {Array} values - Values
 * @returns {number} CV
 */
function calculateVariance(values) {
  if (values.length === 0) return 0
  const avg = values.reduce((a, b) => a + b) / values.length
  // CRITICAL FIX: Prevent division by zero when avg is 0
  if (avg === 0) return 0
  const variance = values.reduce((sum, val) => sum + Math.pow(val - avg, 2), 0) / values.length
  const stdDev = Math.sqrt(variance)
  return stdDev / avg
}

/**
 * Generate response time summary
 * @param {Object} yourStats - Your stats
 * @param {Object} theirStats - Their stats
 * @returns {string} Summary
 */
function generateResponseTimeSummary(yourStats, theirStats) {
  const parts = []

  if (yourStats.average) {
    const readiness = calculateReadiness(yourStats.average)
    parts.push(`You respond on average in ${yourStats.average} (${readiness})`)
  }

  if (theirStats.average) {
    const readiness = calculateReadiness(theirStats.average)
    parts.push(`They respond on average in ${theirStats.average} (${readiness})`)
  }

  if (yourStats.consistency) {
    parts.push(`Your responses are ${yourStats.consistency}`)
  }

  return parts.join('. ')
}

/**
 * Analyze callback consistency
 * How often do they follow up vs how often they initiate?
 * @param {Array} messages - Messages
 * @returns {Object} Callback analysis
 */
export function analyzeCallbackConsistency(messages) {
  if (!messages || messages.length < 3) {
    return {
      summary: 'Need at least 3 messages for callback analysis',
      data: null,
    }
  }

  const interactions = extractInteractions(messages)

  if (interactions.length === 0) {
    return {
      summary: 'Unable to analyze callbacks - need more back-and-forth messages',
      data: null,
    }
  }

  const yourInitiations = interactions.filter((i) => i.initiator === 'you')
  const theirInitiations = interactions.filter((i) => i.initiator === 'them')
  const yourCallbacks = interactions.filter((i) => i.responder === 'you')
  const theirCallbacks = interactions.filter((i) => i.responder === 'them')

  return {
    totalInteractions: interactions.length,
    you: {
      initiations: yourInitiations.length,
      callbacksToTheirInitiations: theirInitiations.filter((i) => i.responded).length,
      callbackRate: theirInitiations.length > 0 ?
        parseFloat(((theirInitiations.filter((i) => i.responded).length / theirInitiations.length) * 100).toFixed(1)) : 0,
      followUpMessages: yourCallbacks.filter((c) => c.messageCount > 1).length,
    },
    them: {
      initiations: theirInitiations.length,
      callbacksToYourInitiations: yourInitiations.filter((i) => i.responded).length,
      callbackRate: yourInitiations.length > 0 ?
        parseFloat(((yourInitiations.filter((i) => i.responded).length / yourInitiations.length) * 100).toFixed(1)) : 0,
      followUpMessages: theirCallbacks.filter((c) => c.messageCount > 1).length,
    },
    reliability: calculateReliability(yourInitiations, theirInitiations),
    summary: generateCallbackSummary(yourInitiations, theirInitiations),
  }
}

/**
 * Extract interactions (initiation + response)
 * @param {Array} messages - Messages
 * @returns {Array} Interactions
 */
function extractInteractions(messages) {
  const interactions = []
  let currentInteraction = null

  for (let i = 0; i < messages.length; i++) {
    const message = messages[i]

    if (!currentInteraction) {
      // Start new interaction
      currentInteraction = {
        initiator: message.direction === 'sent' ? 'you' : 'them',
        initiationIndex: i,
        responder: null,
        responseIndex: null,
        responded: false,
        messageCount: 1,
      }
    } else if (message.direction !== messages[i - 1].direction) {
      // Direction changed - this is a response
      if (!currentInteraction.responded) {
        currentInteraction.responded = true
        currentInteraction.responder = message.direction === 'sent' ? 'you' : 'them'
        currentInteraction.responseIndex = i
        currentInteraction.messageCount++
      } else {
        currentInteraction.messageCount++
      }

      // Check if we should start a new interaction (if same person speaks twice)
      if (i + 1 < messages.length && messages[i + 1].direction === message.direction) {
        if (currentInteraction.messageCount >= 2) {
          interactions.push(currentInteraction)
          currentInteraction = null
        }
      }
    }
  }

  if (currentInteraction && currentInteraction.messageCount >= 2) {
    interactions.push(currentInteraction)
  }

  return interactions
}

/**
 * Calculate reliability score
 * @param {Array} yourInitiations - Your initiations
 * @param {Array} theirInitiations - Their initiations
 * @returns {Object} Reliability metrics
 */
function calculateReliability(yourInitiations, theirInitiations) {
  const yourCallbackRate = yourInitiations.length > 0 ?
    (yourInitiations.filter((i) => i.responded).length / yourInitiations.length) : 0
  const theirCallbackRate = theirInitiations.length > 0 ?
    (theirInitiations.filter((i) => i.responded).length / theirInitiations.length) : 0

  return {
    youRespond: parseFloat((yourCallbackRate * 100).toFixed(0)) + '%',
    theyRespond: parseFloat((theirCallbackRate * 100).toFixed(0)) + '%',
    moreReliable: theirCallbackRate > yourCallbackRate * 1.1 ? 'them' : yourCallbackRate > theirCallbackRate * 1.1 ? 'you' : 'equal',
  }
}

/**
 * Generate callback summary
 * @param {Array} yourInitiations - Your initiations
 * @param {Array} theirInitiations - Their initiations
 * @returns {string} Summary
 */
function generateCallbackSummary(yourInitiations, theirInitiations) {
  const yourCallbacks = yourInitiations.filter((i) => i.responded).length
  const theirCallbacks = theirInitiations.filter((i) => i.responded).length

  const parts = []

  if (yourInitiations.length > 0) {
    const rate = ((yourCallbacks / yourInitiations.length) * 100).toFixed(0)
    parts.push(`You respond to ${rate}% of their messages (${yourCallbacks}/${yourInitiations.length})`)
  }

  if (theirInitiations.length > 0) {
    const rate = ((theirCallbacks / theirInitiations.length) * 100).toFixed(0)
    parts.push(`They respond to ${rate}% of your messages (${theirCallbacks}/${theirInitiations.length})`)
  }

  return parts.join('. ')
}
