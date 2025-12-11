/**
 * doubleTextingDetector.js
 * Detects double texts, triple texts, quad+ texts, and message streaks
 * Shows investment level, eagerness, and emotional engagement per person
 * ENHANCED: Added detailed per-person breakdowns and percentage calculations
 */

/**
 * Detect double texting patterns
 * Double text = sending multiple messages before receiving a response
 * This indicates: investment, enthusiasm, emotional engagement, impatience
 * @param {Array} messages - Normalized messages from messageParser
 * @returns {Object} Double texting analysis with detailed per-person breakdowns
 */
export function detectDoubleTexting(messages) {
  if (!messages || messages.length < 2) {
    return getEmptyDoubleTextResult()
  }

  const streaks = findMessageStreaks(messages)
  const yourStreaks = streaks.filter((s) => s.direction === 'sent')
  const theirStreaks = streaks.filter((s) => s.direction === 'received')

  // Calculate sent/received message counts for percentages
  const sentMessages = messages.filter((m) => m.direction === 'sent')
  const receivedMessages = messages.filter((m) => m.direction === 'received')

  // Calculate detailed statistics for you
  const yourDoubleTexts = yourStreaks.filter((s) => s.length >= 2).length
  const yourTripleTexts = yourStreaks.filter((s) => s.length >= 3).length
  const yourQuadPlusTexts = yourStreaks.filter((s) => s.length >= 4).length
  // ARCHITECTURAL FIX: Use reduce instead of spread to avoid stack overflow on large arrays
  const yourLongestStreak = yourStreaks.length > 0 ? yourStreaks.reduce((max, s) => s.length > max ? s.length : max, 0) : 0
  const yourAverageStreakLength = yourStreaks.length > 0
    ? (yourStreaks.reduce((sum, s) => sum + s.length, 0) / yourStreaks.length).toFixed(1)
    : 0
  const yourTotalStreakMessages = yourStreaks.reduce((sum, s) => sum + s.length, 0)

  // Calculate detailed statistics for them
  const theirDoubleTexts = theirStreaks.filter((s) => s.length >= 2).length
  const theirTripleTexts = theirStreaks.filter((s) => s.length >= 3).length
  const theirQuadPlusTexts = theirStreaks.filter((s) => s.length >= 4).length
  // ARCHITECTURAL FIX: Use reduce instead of spread to avoid stack overflow on large arrays
  const theirLongestStreak = theirStreaks.length > 0 ? theirStreaks.reduce((max, s) => s.length > max ? s.length : max, 0) : 0
  const theirAverageStreakLength = theirStreaks.length > 0
    ? (theirStreaks.reduce((sum, s) => sum + s.length, 0) / theirStreaks.length).toFixed(1)
    : 0
  const theirTotalStreakMessages = theirStreaks.reduce((sum, s) => sum + s.length, 0)

  // Investment scores (how eager are they? 0-100)
  const yourInvestmentScore = calculateInvestmentScore(yourStreaks, messages)
  const theirInvestmentScore = calculateInvestmentScore(theirStreaks, messages)

  // Calculate percentages
  const yourDoubleTextRate = sentMessages.length > 0
    ? ((yourTotalStreakMessages / sentMessages.length) * 100).toFixed(1)
    : 0
  const theirDoubleTextRate = receivedMessages.length > 0
    ? ((theirTotalStreakMessages / receivedMessages.length) * 100).toFixed(1)
    : 0

  // Total counts for comparison
  const totalDoubleTexts = yourDoubleTexts + theirDoubleTexts
  const totalTripleTexts = yourTripleTexts + theirTripleTexts

  return {
    hasDoubleTexts: yourDoubleTexts > 0 || theirDoubleTexts > 0,
    totalDoubleTexts,
    totalTripleTexts,
    totalQuadPlusTexts: yourQuadPlusTexts + theirQuadPlusTexts,

    you: {
      doubleTexts: yourDoubleTexts,
      tripleTexts: yourTripleTexts,
      quadPlusTexts: yourQuadPlusTexts,
      longestStreak: yourLongestStreak,
      averageStreakLength: parseFloat(yourAverageStreakLength),
      totalStreakMessages: yourTotalStreakMessages,
      doubleTextRate: parseFloat(yourDoubleTextRate),
      investmentScore: yourInvestmentScore,
      streakBreakdown: {
        double: yourDoubleTexts - yourTripleTexts, // Exactly 2
        triple: yourTripleTexts - yourQuadPlusTexts, // Exactly 3
        quadPlus: yourQuadPlusTexts, // 4 or more
      },
      streakDetails: yourStreaks.slice(0, 10).map((s) => ({
        length: s.length,
        messages: s.count,
        timespan: formatTimeSpan(s.timespan),
        firstMessage: s.firstMessage,
        style: categorizeStreakStyle(s),
      })),
    },

    them: {
      doubleTexts: theirDoubleTexts,
      tripleTexts: theirTripleTexts,
      quadPlusTexts: theirQuadPlusTexts,
      longestStreak: theirLongestStreak,
      averageStreakLength: parseFloat(theirAverageStreakLength),
      totalStreakMessages: theirTotalStreakMessages,
      doubleTextRate: parseFloat(theirDoubleTextRate),
      investmentScore: theirInvestmentScore,
      streakBreakdown: {
        double: theirDoubleTexts - theirTripleTexts,
        triple: theirTripleTexts - theirQuadPlusTexts,
        quadPlus: theirQuadPlusTexts,
      },
      streakDetails: theirStreaks.slice(0, 10).map((s) => ({
        length: s.length,
        messages: s.count,
        timespan: formatTimeSpan(s.timespan),
        firstMessage: s.firstMessage,
        style: categorizeStreakStyle(s),
      })),
    },

    comparison: {
      ...compareInvestment(yourInvestmentScore, theirInvestmentScore),
      whoDoubleTextsMore: getWhoDoesMore(yourDoubleTexts, theirDoubleTexts),
      whoTripleTextsMore: getWhoDoesMore(yourTripleTexts, theirTripleTexts),
      doubleTextRatio: totalDoubleTexts > 0
        ? { you: Math.round((yourDoubleTexts / totalDoubleTexts) * 100), them: Math.round((theirDoubleTexts / totalDoubleTexts) * 100) }
        : { you: 0, them: 0 },
      streakLengthDifference: Math.abs(yourLongestStreak - theirLongestStreak),
      whoHasLongerStreaks: yourLongestStreak > theirLongestStreak ? 'you' : theirLongestStreak > yourLongestStreak ? 'them' : 'equal',
    },

    analysis: generateDoubleTextsAnalysis(yourDoubleTexts, theirDoubleTexts, yourInvestmentScore, theirInvestmentScore),
    summary: generateDoubleTextSummary(yourDoubleTexts, theirDoubleTexts, yourTripleTexts, theirTripleTexts, yourInvestmentScore, theirInvestmentScore),
  }
}

/**
 * Get empty result for insufficient data
 */
function getEmptyDoubleTextResult() {
  return {
    hasDoubleTexts: false,
    totalDoubleTexts: 0,
    totalTripleTexts: 0,
    totalQuadPlusTexts: 0,
    you: {
      doubleTexts: 0,
      tripleTexts: 0,
      quadPlusTexts: 0,
      longestStreak: 0,
      averageStreakLength: 0,
      totalStreakMessages: 0,
      doubleTextRate: 0,
      investmentScore: 0,
      streakBreakdown: { double: 0, triple: 0, quadPlus: 0 },
      streakDetails: [],
    },
    them: {
      doubleTexts: 0,
      tripleTexts: 0,
      quadPlusTexts: 0,
      longestStreak: 0,
      averageStreakLength: 0,
      totalStreakMessages: 0,
      doubleTextRate: 0,
      investmentScore: 0,
      streakBreakdown: { double: 0, triple: 0, quadPlus: 0 },
      streakDetails: [],
    },
    comparison: {
      moreInvested: 'equal',
      difference: 0,
      interpretation: 'Not enough data',
      whoDoubleTextsMore: 'equal',
      whoTripleTextsMore: 'equal',
      doubleTextRatio: { you: 0, them: 0 },
      streakLengthDifference: 0,
      whoHasLongerStreaks: 'equal',
    },
    analysis: 'Need at least 2 messages for analysis',
    summary: 'Not enough data to analyze double texting patterns.',
  }
}

/**
 * Helper to determine who does something more
 */
function getWhoDoesMore(yourCount, theirCount) {
  if (yourCount === theirCount) return 'equal'
  return yourCount > theirCount ? 'you' : 'them'
}

/**
 * Categorize streak style based on timing
 */
function categorizeStreakStyle(streak) {
  if (!streak.timespan || streak.timespan === 0) return 'instant'
  const avgGapMs = streak.timespan / (streak.length - 1)
  if (avgGapMs < 30000) return 'rapid' // < 30 seconds
  if (avgGapMs < 120000) return 'quick' // < 2 minutes
  if (avgGapMs < 600000) return 'moderate' // < 10 minutes
  return 'spaced' // 10+ minutes between messages
}

/**
 * Generate comprehensive summary
 */
function generateDoubleTextSummary(yourDT, theirDT, yourTT, theirTT, yourScore, theirScore) {
  const parts = []
  const totalDT = yourDT + theirDT
  const totalTT = yourTT + theirTT

  if (totalDT === 0) {
    return 'No double texting detected - both maintain measured messaging.'
  }

  // Who double texts more
  if (yourDT > theirDT * 1.5) {
    parts.push(`You double text significantly more (${yourDT} vs ${theirDT})`)
  } else if (theirDT > yourDT * 1.5) {
    parts.push(`They double text significantly more (${theirDT} vs ${yourDT})`)
  } else if (totalDT > 0) {
    parts.push(`Double texting is balanced (${yourDT} from you, ${theirDT} from them)`)
  }

  // Triple texts
  if (totalTT > 0) {
    if (yourTT > theirTT) {
      parts.push(`You also triple text more often (${yourTT} times)`)
    } else if (theirTT > yourTT) {
      parts.push(`They triple text more often (${theirTT} times)`)
    } else {
      parts.push(`Both triple text equally (${yourTT} each)`)
    }
  }

  // Investment interpretation
  if (Math.abs(yourScore - theirScore) > 20) {
    const moreInvested = yourScore > theirScore ? 'You' : 'They'
    parts.push(`${moreInvested} show higher messaging investment`)
  }

  return parts.join('. ') + '.'
}

/**
 * Find message streaks (consecutive messages from same person)
 * @param {Array} messages - Normalized messages
 * @returns {Array} Array of streak objects
 */
function findMessageStreaks(messages) {
  const streaks = []
  let currentStreak = null

  for (let i = 0; i < messages.length; i++) {
    const message = messages[i]

    if (!currentStreak || currentStreak.direction !== message.direction) {
      // Start new streak
      if (currentStreak && currentStreak.length > 1) {
        streaks.push(currentStreak)
      }
      currentStreak = {
        direction: message.direction,
        length: 1,
        count: 1,
        startIndex: i,
        endIndex: i,
        startTime: message.timestamp,
        endTime: message.timestamp,
        timespan: 0,
        firstMessage: message.content.substring(0, 40) + (message.content.length > 40 ? '...' : ''),
      }
    } else {
      // Continue streak
      currentStreak.length++
      currentStreak.count++
      currentStreak.endIndex = i
      currentStreak.endTime = message.timestamp
      currentStreak.timespan = currentStreak.endTime.getTime() - currentStreak.startTime.getTime()
      currentStreak.firstMessage = messages[currentStreak.startIndex].content.substring(0, 40) +
        (messages[currentStreak.startIndex].content.length > 40 ? '...' : '')
    }
  }

  // Add final streak if it's longer than 1
  if (currentStreak && currentStreak.length > 1) {
    streaks.push(currentStreak)
  }

  return streaks
}

/**
 * Calculate investment score based on double texting patterns
 * @param {Array} streaks - Message streaks from one party
 * @param {Array} messages - All messages for context
 * @returns {number} Investment score 0-100
 */
function calculateInvestmentScore(streaks, messages) {
  if (streaks.length === 0) return 0

  let score = 0

  // Double texts: 20 points per occurrence (capped at 30)
  const doubleTexts = streaks.filter((s) => s.length >= 2).length
  score += Math.min(doubleTexts * 5, 30)

  // Triple texts: 15 points each (capped at 25)
  const tripleTexts = streaks.filter((s) => s.length >= 3).length
  score += Math.min(tripleTexts * 8, 25)

  // Longer streaks (4+): 10 points each (capped at 20)
  const longStreaks = streaks.filter((s) => s.length >= 4).length
  score += Math.min(longStreaks * 5, 20)

  // Frequency: how often do they double text? (capped at 25)
  const doubleTextsFrequency = streaks.filter((s) => s.length >= 2).length / messages.length
  score += Math.min(doubleTextsFrequency * 100, 25)

  return Math.min(100, parseFloat(score.toFixed(0)))
}

/**
 * Compare investment levels
 * @param {number} yourScore - Your investment score
 * @param {number} theirScore - Their investment score
 * @returns {Object} Comparison result
 */
function compareInvestment(yourScore, theirScore) {
  const diff = Math.abs(yourScore - theirScore)
  const moreInvested = yourScore > theirScore ? 'you' : yourScore < theirScore ? 'them' : 'equal'

  let interpretation = ''
  if (moreInvested === 'equal') {
    interpretation = 'Both show similar investment levels'
  } else if (moreInvested === 'you') {
    if (diff > 30) interpretation = 'You show significantly more investment than them'
    else if (diff > 15) interpretation = 'You show notably more investment'
    else interpretation = 'You show slightly more investment'
  } else {
    if (diff > 30) interpretation = 'They show significantly more investment than you'
    else if (diff > 15) interpretation = 'They show notably more investment'
    else interpretation = 'They show slightly more investment'
  }

  return {
    moreInvested,
    difference: diff,
    interpretation,
  }
}

/**
 * Format time span
 * @param {number} ms - Milliseconds
 * @returns {string} Formatted time
 */
function formatTimeSpan(ms) {
  if (ms < 60000) return `${Math.round(ms / 1000)}s`
  if (ms < 3600000) return `${Math.round(ms / 60000)}m`
  if (ms < 86400000) return `${Math.round(ms / 3600000)}h`
  return `${Math.round(ms / 86400000)}d`
}

/**
 * Generate detailed analysis text
 * @param {number} yourDoubleTexts - Your double text count
 * @param {number} theirDoubleTexts - Their double text count
 * @param {number} yourScore - Your investment score
 * @param {number} theirScore - Their investment score
 * @returns {string} Analysis text
 */
function generateDoubleTextsAnalysis(yourDoubleTexts, theirDoubleTexts, yourScore, theirScore) {
  const analysis = []

  // Your activity
  if (yourDoubleTexts === 0) {
    analysis.push('You do not send double texts - more measured approach')
  } else if (yourDoubleTexts === 1) {
    analysis.push('You occasionally send double texts - shows some eagerness')
  } else if (yourDoubleTexts <= 3) {
    analysis.push('You frequently send double texts - shows investment and enthusiasm')
  } else {
    analysis.push('You very frequently send double texts - shows high eagerness and investment')
  }

  // Their activity
  if (theirDoubleTexts === 0) {
    analysis.push('They do not send double texts - more reserved or busy')
  } else if (theirDoubleTexts === 1) {
    analysis.push('They occasionally send double texts - shows casual investment')
  } else if (theirDoubleTexts <= 3) {
    analysis.push('They frequently send double texts - shows they are invested in the conversation')
  } else {
    analysis.push('They very frequently send double texts - shows high enthusiasm')
  }

  // Investment comparison
  if (yourScore > theirScore + 15) {
    analysis.push(`You are significantly more eager to keep the conversation going (${yourScore} vs ${theirScore})`)
  } else if (yourScore < theirScore - 15) {
    analysis.push(`They are significantly more eager to keep the conversation going (${theirScore} vs ${yourScore})`)
  } else if (yourScore > theirScore) {
    analysis.push(`You show slightly more enthusiasm than them`)
  } else if (theirScore > yourScore) {
    analysis.push(`They show slightly more enthusiasm than you`)
  } else {
    analysis.push('Both show similar eagerness levels')
  }

  return analysis.join('. ')
}

/**
 * Analyze message timing within streaks
 * How quickly does someone send multiple messages?
 * Quick succession = more emotional, impulsive
 * Spaced out = more thoughtful
 * @param {Array} messages - Normalized messages
 * @returns {Object} Streak timing analysis
 */
export function analyzeStreakTiming(messages) {
  const streaks = findMessageStreaks(messages)
  const doubleTextStreaks = streaks.filter((s) => s.length >= 2)

  if (doubleTextStreaks.length === 0) {
    return {
      hasDoubleTexts: false,
      message: 'No double text streaks found',
    }
  }

  const timings = doubleTextStreaks.map((streak) => {
    // Get individual messages in streak
    const streakMessages = messages.slice(streak.startIndex, streak.endIndex + 1)
    const gaps = []

    for (let i = 1; i < streakMessages.length; i++) {
      const gap = streakMessages[i].timestamp.getTime() - streakMessages[i - 1].timestamp.getTime()
      gaps.push(gap)
    }

    const avgGap = gaps.reduce((a, b) => a + b, 0) / gaps.length
    // ARCHITECTURAL FIX: Use reduce instead of spread to avoid stack overflow on large arrays
    const minGap = gaps.reduce((min, val) => val < min ? val : min, gaps[0] || 0)
    const maxGap = gaps.reduce((max, val) => val > max ? val : max, gaps[0] || 0)

    return {
      length: streak.length,
      averageGap: formatTimeSpan(avgGap),
      minGap: formatTimeSpan(minGap),
      maxGap: formatTimeSpan(maxGap),
      style: minGap < 60000 ? 'rapid_fire' : avgGap < 300000 ? 'quick' : 'spaced_out',
    }
  })

  const avgStyle = calculatePredominantStyle(timings)

  return {
    hasDoubleTexts: true,
    streakCount: doubleTextStreaks.length,
    timings,
    predominantStyle: avgStyle,
    interpretation: interpretStreakStyle(avgStyle),
  }
}

/**
 * Calculate predominant style from timings
 * @param {Array} timings - Streak timing data
 * @returns {string} Predominant style
 */
function calculatePredominantStyle(timings) {
  const styles = timings.map((t) => t.style)
  const counts = {}
  styles.forEach((s) => {
    counts[s] = (counts[s] || 0) + 1
  })
  const dominant = Object.keys(counts).reduce((a, b) => (counts[a] > counts[b] ? a : b))
  return dominant
}

/**
 * Interpret streak style
 * @param {string} style - Streak style
 * @returns {string} Interpretation
 */
function interpretStreakStyle(style) {
  const interpretations = {
    rapid_fire: 'Messages sent in quick succession - emotional, impulsive, or typing continuously',
    quick: 'Messages sent within a few minutes - thought out slightly but still eager',
    spaced_out: 'Messages spaced out over time - more thoughtful, less pressured approach',
  }
  return interpretations[style] || 'Unknown style'
}
