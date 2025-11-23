/**
 * toxicityClassifier.js
 * Detects toxic language, conflict indicators, and negativity
 *
 * ARCHITECTURAL IMPROVEMENTS v2.0:
 * - Word boundary matching (prevents "classic" matching "ass")
 * - Context-aware toxicity (not all profanity is toxic in context)
 * - Expanded relationship-specific toxic patterns
 * - Gaslighting and manipulation detection
 * - Severity-weighted scoring
 */

/**
 * Toxic keywords and phrases - EXPANDED with relationship abuse patterns
 */
const TOXIC_KEYWORDS = {
  severe: [
    // Direct attacks
    'kill yourself', 'kys', 'go die', 'hope you die', 'wish you were dead',
    // Extreme insults
    'worthless', 'piece of shit', 'piece of crap', 'useless', 'garbage human',
    // Threats
    'will hurt you', 'gonna hurt you', 'kill you', 'beat you', 'hit you'
  ],
  strong: [
    'hate you', 'hate your', 'fuck you', 'fuck off', 'screw you',
    'disgusting', 'pathetic', 'loser', 'stupid', 'idiot', 'moron', 'dumbass',
    'jerk', 'asshole', 'bitch', 'bastard', 'dick', 'prick',
    'manipulative', 'selfish', 'toxic', 'abusive', 'psycho', 'crazy',
    'shut up', 'shut the fuck up', 'stfu'
  ],
  moderate: [
    'hate', 'horrible', 'terrible', 'awful', 'disgusted', 'gross',
    'annoying', 'annoyed', 'pissed', 'pissed off', 'mad at you',
    'sick of you', 'tired of you', 'done with you', 'over you',
    'rude', 'mean', 'cruel', 'heartless', 'cold',
    // Profanity (moderate in casual context)
    'damn', 'crap', 'sucks', 'bullshit', 'bs'
  ],
  mild: [
    'whatever', 'fine then', 'forget it', 'never mind',
    'disappointed', 'let down', 'frustrated'
  ]
}

/**
 * Gaslighting and manipulation patterns - HIGH severity
 */
const GASLIGHTING_PATTERNS = [
  'you\'re crazy', 'youre crazy', 'you are crazy',
  'you\'re imagining', 'youre imagining', 'you are imagining',
  'that never happened', 'i never said that', 'i never did that',
  'you\'re overreacting', 'youre overreacting', 'you are overreacting',
  'you\'re too sensitive', 'youre too sensitive', 'you are too sensitive',
  'no one else thinks that', 'everyone agrees with me',
  'you\'re making things up', 'youre making things up',
  'you always do this', 'you never listen',
  'if you really loved me', 'if you cared about me'
]

/**
 * Conflict escalation indicators
 */
const CONFLICT_INDICATORS = {
  escalation: [
    'you never', 'you always', 'every time', 'once again',
    'as usual', 'typical', 'of course you', 'here we go again'
  ],
  shutdown: [
    'im done', 'i\'m done', 'i quit', 'forget it', 'whatever',
    'i give up', 'what\'s the point', 'why bother',
    'talking to a wall', 'waste of time'
  ],
  dismissive: [
    'i don\'t care', 'don\'t care', 'couldn\'t care less',
    'not my problem', 'deal with it', 'get over it',
    'grow up', 'be an adult', 'stop being'
  ]
}

/**
 * Context words that REDUCE toxicity (playful context)
 * "you're such an idiot lol" is less toxic than "you're an idiot"
 */
const PLAYFUL_CONTEXT = [
  'lol', 'lmao', 'haha', 'hahaha', 'jk', 'just kidding', 'joking',
  '😂', '🤣', '😜', '😝', '😋', '💀', 'im dead', 'i\'m dead'
]

/**
 * Classify toxicity in messages
 * @param {Array} messages - Normalized messages
 * @returns {Object} Toxicity analysis
 */
export function classifyToxicity(messages) {
  if (!messages || messages.length === 0) {
    return {
      overallToxicity: 0,
      level: 'none',
      hasToxicity: false,
      analysis: [],
      summary: 'No messages to analyze',
    }
  }

  const toxicityScores = messages.map((message) => scoreToxicity(message))
  const averageToxicity = toxicityScores.reduce((sum, s) => sum + s.score, 0) / toxicityScores.length
  const toxicMessages = toxicityScores.filter((s) => s.isToxic)

  const hasToxicity = toxicMessages.length > 0
  const toxicityLevel = determineToxicityLevel(averageToxicity, toxicMessages.length, messages.length)

  // CRITICAL FIX: Cache toxicity scores by message ID to avoid O(n³) complexity
  const toxicityMap = new Map(toxicityScores.map((s) => [s.messageId, s]))

  // Group by party
  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  // Calculate toxicity stats for each party (O(n) instead of O(n³))
  const sentToxicMessages = sent.filter((m) => toxicityMap.get(m.id)?.isToxic)
  const receivedToxicMessages = received.filter((m) => toxicityMap.get(m.id)?.isToxic)

  const sentToxicity = sent.reduce((sum, m) => sum + (toxicityMap.get(m.id)?.score || 0), 0) / (sent.length || 1)
  const receivedToxicity = received.reduce((sum, m) => sum + (toxicityMap.get(m.id)?.score || 0), 0) / (received.length || 1)

  return {
    overallToxicity: parseFloat(averageToxicity.toFixed(2)),
    level: toxicityLevel,
    hasToxicity,
    toxicMessages: toxicMessages.length,
    toxicityPercentage: parseFloat(((toxicMessages.length / messages.length) * 100).toFixed(1)),
    you: {
      toxicity: parseFloat(sentToxicity.toFixed(2)),
      toxicMessages: sentToxicMessages.length,
    },
    them: {
      toxicity: parseFloat(receivedToxicity.toFixed(2)),
      toxicMessages: receivedToxicMessages.length,
    },
    topConcerns: identifyTopConcerns(toxicityScores),
    summary: generateToxicitySummary(averageToxicity, toxicMessages.length, sentToxicity, receivedToxicity),
  }
}

/**
 * Score toxicity of a single message
 * IMPROVED: Word boundary matching, context awareness, gaslighting detection
 * @param {Object} message - Message object
 * @returns {Object} Toxicity score and details
 */
function scoreToxicity(message) {
  const text = message.content.toLowerCase()
  let score = 0
  let indicators = []
  let isToxic = false
  let gaslightingDetected = false
  let severityLevel = 'none'

  // Check playful context first (reduces toxicity score)
  const hasPlayfulContext = PLAYFUL_CONTEXT.some(marker => text.includes(marker))
  const contextMultiplier = hasPlayfulContext ? 0.5 : 1.0

  // Check SEVERE toxic patterns FIRST (highest priority)
  for (const keyword of TOXIC_KEYWORDS.severe) {
    if (matchWithWordBoundary(text, keyword)) {
      score += 1.0 * contextMultiplier
      indicators.push(`severe: ${keyword}`)
      isToxic = true
      severityLevel = 'severe'
    }
  }

  // Check strong toxic keywords with word boundary matching
  for (const keyword of TOXIC_KEYWORDS.strong) {
    if (matchWithWordBoundary(text, keyword)) {
      score += 0.7 * contextMultiplier
      indicators.push(`strong: ${keyword}`)
      isToxic = true
      if (severityLevel === 'none') severityLevel = 'strong'
    }
  }

  // Check moderate toxic keywords with word boundary matching
  for (const keyword of TOXIC_KEYWORDS.moderate) {
    if (matchWithWordBoundary(text, keyword)) {
      score += 0.4 * contextMultiplier
      indicators.push(`moderate: ${keyword}`)
      if (severityLevel === 'none') severityLevel = 'moderate'
    }
  }

  // Check mild toxic keywords
  for (const keyword of TOXIC_KEYWORDS.mild) {
    if (matchWithWordBoundary(text, keyword)) {
      score += 0.2
      indicators.push(`mild: ${keyword}`)
      if (severityLevel === 'none') severityLevel = 'mild'
    }
  }

  // Check gaslighting patterns (HIGH severity)
  for (const pattern of GASLIGHTING_PATTERNS) {
    if (text.includes(pattern)) {
      score += 0.8
      indicators.push(`gaslighting: ${pattern}`)
      gaslightingDetected = true
      isToxic = true
      if (severityLevel !== 'severe') severityLevel = 'strong'
    }
  }

  // Check conflict escalation indicators
  for (const indicator of CONFLICT_INDICATORS.escalation) {
    if (text.includes(indicator)) {
      score += 0.3
      indicators.push(`escalation: ${indicator}`)
    }
  }

  // Check shutdown indicators
  for (const indicator of CONFLICT_INDICATORS.shutdown) {
    if (text.includes(indicator)) {
      score += 0.25
      indicators.push(`shutdown: ${indicator}`)
    }
  }

  // Check dismissive indicators
  for (const indicator of CONFLICT_INDICATORS.dismissive) {
    if (text.includes(indicator)) {
      score += 0.35
      indicators.push(`dismissive: ${indicator}`)
    }
  }

  // Check for excessive punctuation (!!!???)
  const exclamations = (text.match(/!/g) || []).length
  const questions = (text.match(/\?/g) || []).length
  if (exclamations > 3 || questions > 3) {
    score += 0.2
    indicators.push('aggressive_punctuation')
  }

  // Check for ALL CAPS (yelling)
  const capsRatio = (message.content.match(/[A-Z]/g) || []).length / message.content.length
  if (capsRatio > 0.6 && message.content.length > 10) {
    score += 0.25
    indicators.push('yelling')
  }

  // Normalize score (0-1)
  score = Math.min(1, score)

  // Lower threshold for toxicity detection
  if (score > 0.25) isToxic = true

  return {
    messageId: message.id,
    content: message.content.substring(0, 50),
    score: parseFloat(score.toFixed(2)),
    isToxic,
    indicators,
    severity: severityLevel,
    flags: {
      gaslightingDetected,
      hasPlayfulContext
    }
  }
}

/**
 * Match keyword with word boundaries to prevent false positives
 * Prevents "classic" from matching "ass", "therapist" from matching "the"
 * @param {string} text - Text to search
 * @param {string} keyword - Keyword to find
 * @returns {boolean} True if matched
 */
function matchWithWordBoundary(text, keyword) {
  // Escape special regex characters
  const escaped = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')

  // For phrases, use contains; for single words, use word boundaries
  if (keyword.includes(' ')) {
    return text.includes(keyword)
  }

  // Use word boundary for single words
  const regex = new RegExp(`\\b${escaped}\\b`, 'i')
  return regex.test(text)
}

/**
 * Determine toxicity level
 * @param {number} average - Average toxicity score
 * @param {number} toxicCount - Count of toxic messages
 * @param {number} totalCount - Total messages
 * @returns {string} Toxicity level
 */
function determineToxicityLevel(average, toxicCount, totalCount) {
  const percentage = (toxicCount / totalCount) * 100

  if (average < 0.1 || percentage < 5) return 'none'
  if (average < 0.3 || percentage < 15) return 'low'
  if (average < 0.5 || percentage < 30) return 'moderate'
  if (average < 0.7 || percentage < 50) return 'high'
  return 'severe'
}

/**
 * Identify top toxic concerns
 * @param {Array} toxicityScores - Toxicity scores for all messages
 * @returns {Array} Top concerns
 */
function identifyTopConcerns(toxicityScores) {
  const concerns = {}

  toxicityScores.forEach((score) => {
    score.indicators.forEach((indicator) => {
      concerns[indicator] = (concerns[indicator] || 0) + 1
    })
  })

  return Object.entries(concerns)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([concern, count]) => ({ concern, count }))
}

/**
 * Generate toxicity summary
 * @param {number} average - Average toxicity
 * @param {number} toxicCount - Toxic message count
 * @param {number} sentToxicity - Your toxicity
 * @param {number} receivedToxicity - Their toxicity
 * @returns {string} Summary
 */
function generateToxicitySummary(average, toxicCount, sentToxicity, receivedToxicity) {
  const parts = []

  if (average === 0) {
    parts.push('No toxic language detected - healthy communication')
  } else if (average < 0.3) {
    parts.push('Minimal toxicity - mostly respectful conversation')
  } else if (average < 0.5) {
    parts.push('Moderate toxicity detected - some hostile language')
  } else {
    parts.push('High toxicity detected - significant conflict in language')
  }

  if (sentToxicity > receivedToxicity) {
    parts.push(`You use more toxic language (${sentToxicity} vs ${receivedToxicity})`)
  } else if (receivedToxicity > sentToxicity) {
    parts.push(`They use more toxic language (${receivedToxicity} vs ${sentToxicity})`)
  } else if (sentToxicity > 0) {
    parts.push('Both use similar levels of toxic language')
  }

  return parts.join('. ')
}
