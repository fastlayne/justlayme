/**
 * engagementScorer.js
 * Scores emotional engagement based on message content and style
 */

/**
 * Score emotional engagement
 * High engagement = personalization, questions, emoji, depth
 * @param {Array} messages - Normalized messages
 * @returns {Object} Engagement analysis
 */
export function scoreEngagement(messages) {
  if (!messages || messages.length === 0) {
    return {
      overallScore: 0,
      level: 'none',
      analysis: [],
      summary: 'No messages to analyze',
    }
  }

  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  const yourEngagement = calculateEngagementScore(sent)
  const theirEngagement = calculateEngagementScore(received)

  const overallScore = (yourEngagement.score + theirEngagement.score) / 2

  return {
    overallScore: parseFloat(overallScore.toFixed(0)),
    level: getEngagementLevel(overallScore),
    you: yourEngagement,
    them: theirEngagement,
    comparison: compareEngagement(yourEngagement.score, theirEngagement.score),
    drivers: identifyEngagementDrivers(sent, received),
    summary: generateEngagementSummary(yourEngagement, theirEngagement),
  }
}

/**
 * Calculate engagement score for messages from one party
 * @param {Array} messages - Messages from one party
 * @returns {Object} Engagement metrics
 */
function calculateEngagementScore(messages) {
  if (messages.length === 0) {
    return { score: 0, level: 'none', drivers: [] }
  }

  let score = 0
  const drivers = []

  // 1. Questions (shows interest) - 20 points
  const questionCount = messages.filter((m) => m.content.includes('?')).length
  const questionScore = Math.min((questionCount / messages.length) * 20, 20)
  if (questionCount > 0) {
    score += questionScore
    drivers.push({ name: 'Questions', value: questionCount, score: questionScore })
  }

  // 2. Emoji usage (shows emotional expression) - 15 points
  // ARCHITECTURAL FIX: Comprehensive emoji detection covering all Unicode ranges
  const emojiPattern = /[\u{1F300}-\u{1F9FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]|[\u{1F600}-\u{1F64F}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2300}-\u{23FF}]|[\u{2B50}]|[\u{231A}-\u{231B}]|[\u{25AA}-\u{25AB}]|[\u{25B6}]|[\u{25C0}]|[\u{25FB}-\u{25FE}]|[\u{2614}-\u{2615}]|[\u{2648}-\u{2653}]|[\u{267F}]|[\u{2693}]|[\u{26A1}]|[\u{26AA}-\u{26AB}]|[\u{26BD}-\u{26BE}]|[\u{26C4}-\u{26C5}]|[\u{26CE}]|[\u{26D4}]|[\u{26EA}]|[\u{26F2}-\u{26F3}]|[\u{26F5}]|[\u{26FA}]|[\u{26FD}]|[\u{2702}]|[\u{2705}]|[\u{2708}-\u{270D}]|[\u{270F}]|[\u{2712}]|[\u{2714}]|[\u{2716}]|[\u{271D}]|[\u{2721}]|[\u{2728}]|[\u{2733}-\u{2734}]|[\u{2744}]|[\u{2747}]|[\u{274C}]|[\u{274E}]|[\u{2753}-\u{2755}]|[\u{2757}]|[\u{2763}-\u{2764}]|[\u{2795}-\u{2797}]|[\u{27A1}]|[\u{27B0}]|[\u{27BF}]|[\u{2934}-\u{2935}]|[\u{2B05}-\u{2B07}]|[\u{2B1B}-\u{2B1C}]|[\u{2B55}]|[\u{3030}]|[\u{303D}]|[\u{3297}]|[\u{3299}]/gu
  const emojiCount = messages.filter((m) => emojiPattern.test(m.content || '')).length
  const emojiScore = Math.min((emojiCount / messages.length) * 15, 15)
  if (emojiCount > 0) {
    score += emojiScore
    drivers.push({ name: 'Emoji usage', value: emojiCount, score: emojiScore })
  }

  // 3. Personalization (mentions of specific things, names) - 15 points
  const personalMessages = messages.filter((m) => containsPersonalization(m.content)).length
  const personalScore = Math.min((personalMessages / messages.length) * 15, 15)
  if (personalMessages > 0) {
    score += personalScore
    drivers.push({ name: 'Personalization', value: personalMessages, score: personalScore })
  }

  // 4. Message length/depth - 15 points
  const avgLength = messages.reduce((sum, m) => sum + (m.length || 0), 0) / messages.length
  const depthScore = Math.min((avgLength / 100) * 15, 15) // 100+ chars = full points
  if (avgLength > 20) {
    score += depthScore
    drivers.push({ name: 'Message depth', value: Math.round(avgLength), score: depthScore })
  }

  // 5. Exclamation marks (enthusiasm) - 10 points
  const exclamationCount = messages.reduce((sum, m) => sum + (m.content.match(/!/g) || []).length, 0)
  const enthusiasmScore = Math.min((exclamationCount / messages.length) * 10, 10)
  if (exclamationCount > 0) {
    score += enthusiasmScore
    drivers.push({ name: 'Enthusiasm', value: exclamationCount, score: enthusiasmScore })
  }

  // 6. Follow-up messages (continued engagement) - 10 points
  const hasFollowUps = messages.some((m, i) => i > 0 && messages[i - 1].direction === m.direction)
  if (hasFollowUps) {
    score += 10
    drivers.push({ name: 'Follow-up messages', value: 1, score: 10 })
  }

  // Normalize to 0-100
  score = Math.min(100, parseFloat(score.toFixed(0)))

  return {
    score,
    level: getEngagementLevel(score),
    messageCount: messages.length,
    drivers: drivers.sort((a, b) => b.score - a.score),
  }
}

/**
 * Check if message contains personalization
 * Mentions specific things, uses names, references shared memories
 * @param {string} content - Message content
 * @returns {boolean} Is personalized
 */
function containsPersonalization(content) {
  const personalizations = [
    /\b(i|we|you|your|my|our)\b/i,
    /\b(remember|forgot|told|said|mentioned)\b/i,
    /\b(love|miss|think about|remember when)\b/i,
    /[a-z]+ing/i, // -ing words suggest activities/feelings
  ]

  return personalizations.some((pattern) => pattern.test(content))
}

/**
 * Get engagement level from score
 * @param {number} score - Score 0-100
 * @returns {string} Level
 */
function getEngagementLevel(score) {
  if (score < 20) return 'minimal'
  if (score < 40) return 'low'
  if (score < 60) return 'moderate'
  if (score < 80) return 'high'
  return 'very_high'
}

/**
 * Compare engagement between parties
 * @param {number} yourScore - Your engagement score
 * @param {number} theirScore - Their engagement score
 * @returns {Object} Comparison
 */
function compareEngagement(yourScore, theirScore) {
  const diff = Math.abs(yourScore - theirScore)
  const moreEngaged = yourScore > theirScore ? 'you' : yourScore < theirScore ? 'them' : 'equal'

  let interpretation = ''
  if (moreEngaged === 'equal') {
    interpretation = 'Both show similar engagement levels'
  } else if (diff > 20) {
    interpretation = `${moreEngaged === 'you' ? 'You' : 'They'} are significantly more emotionally engaged`
  } else {
    interpretation = `${moreEngaged === 'you' ? 'You' : 'They'} show slightly more engagement`
  }

  return {
    moreEngaged,
    difference: diff,
    interpretation,
  }
}

/**
 * Identify what drives engagement
 * @param {Array} sentMessages - Your messages
 * @param {Array} receivedMessages - Their messages
 * @returns {Array} Top engagement drivers
 */
function identifyEngagementDrivers(sentMessages, receivedMessages) {
  const allDrivers = {}

  const yourEngagement = calculateEngagementScore(sentMessages)
  const theirEngagement = calculateEngagementScore(receivedMessages)

  const yourTop = yourEngagement.drivers.slice(0, 2).map((d) => d.name)
  const theirTop = theirEngagement.drivers.slice(0, 2).map((d) => d.name)

  return {
    yourTopDrivers: yourTop,
    theirTopDrivers: theirTop,
    sharedDrivers: yourTop.filter((d) => theirTop.includes(d)),
  }
}

/**
 * Generate engagement summary
 * @param {Object} yourEngagement - Your engagement
 * @param {Object} theirEngagement - Their engagement
 * @returns {string} Summary
 */
function generateEngagementSummary(yourEngagement, theirEngagement) {
  const parts = []

  if (yourEngagement.score > 70) {
    parts.push('You show very high emotional engagement')
  } else if (yourEngagement.score > 50) {
    parts.push('You show moderate to high engagement')
  } else if (yourEngagement.score > 30) {
    parts.push('You show low engagement')
  } else {
    parts.push('You show minimal engagement')
  }

  if (theirEngagement.score > 70) {
    parts.push('They show very high emotional engagement')
  } else if (theirEngagement.score > 50) {
    parts.push('They show moderate to high engagement')
  } else if (theirEngagement.score > 30) {
    parts.push('They show low engagement')
  } else {
    parts.push('They show minimal engagement')
  }

  if (yourEngagement.drivers.length > 0) {
    parts.push(`Your main engagement driver is: ${yourEngagement.drivers[0].name}`)
  }

  if (theirEngagement.drivers.length > 0) {
    parts.push(`Their main engagement driver is: ${theirEngagement.drivers[0].name}`)
  }

  return parts.join('. ')
}
