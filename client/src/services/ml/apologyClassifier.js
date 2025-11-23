/**
 * apologyClassifier.js
 * Detects apologies, reconciliation attempts, and conflict resolution patterns
 * Tracks per-person metrics for who apologizes more and reconciliation success
 */

// Apology keywords - explicit
const EXPLICIT_APOLOGIES = [
  'sorry', 'apologize', 'apologies', 'my bad', 'my mistake', 'my fault',
  'i was wrong', 'forgive me', 'pardon me', 'i messed up', 'i screwed up',
  'i fucked up', 'shouldnt have', "shouldn't have", 'regret',
]

// Soft apologies - less direct
const SOFT_APOLOGIES = [
  'didnt mean to', "didn't mean to", 'wasnt trying to', "wasn't trying to",
  'i understand why', 'i get why', 'i see why', 'you have every right',
  'i can see how', 'that came out wrong', 'let me explain',
]

// Reconciliation attempts
const RECONCILIATION_PHRASES = [
  'can we talk', 'lets talk', "let's talk", 'can we fix this',
  'i want to work this out', 'i miss you', 'i love you',
  'youre right', "you're right", 'you were right', 'i agree',
  'i see your point', 'you make a good point', 'fair enough',
  'lets move on', "let's move on", 'can we move past', 'water under the bridge',
  'truce', 'peace', 'hug', 'make up', 'start over', 'fresh start',
]

// Conflict indicators (to detect what triggers apologies)
const CONFLICT_INDICATORS = [
  'angry', 'upset', 'mad', 'frustrated', 'annoyed', 'hurt',
  'disappointed', 'cant believe', "can't believe", 'how could you',
  'why would you', 'not okay', 'not cool', 'wtf', 'seriously',
]

/**
 * Main function - detect apology patterns in conversation
 * @param {Array} messages - Normalized messages array
 * @returns {Object} Comprehensive apology analysis
 */
export function detectApologyPatterns(messages) {
  if (!messages || messages.length < 2) {
    return getEmptyResult()
  }

  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  // Analyze each person's apology patterns
  const youApologies = analyzePersonApologies(sent, messages, 'sent')
  const themApologies = analyzePersonApologies(received, messages, 'received')

  // Analyze reconciliation attempts
  const youReconciliation = analyzeReconciliation(sent)
  const themReconciliation = analyzeReconciliation(received)

  // Calculate overall metrics
  const totalApologies = youApologies.total + themApologies.total
  const apologyRatio = calculateApologyRatio(youApologies, themApologies)
  const reconciliationSuccess = analyzeReconciliationSuccess(messages)

  return {
    hasApologies: totalApologies > 0,
    totalApologies,
    apologyRatio,

    you: {
      totalApologies: youApologies.total,
      explicitApologies: youApologies.explicit,
      softApologies: youApologies.soft,
      apologyPercentage: sent.length > 0 ? ((youApologies.total / sent.length) * 100).toFixed(1) : 0,
      averageSincerity: youApologies.averageSincerity,
      reconciliationAttempts: youReconciliation.attempts,
      reconciliationPhrases: youReconciliation.phrases,
      firstToApologize: youApologies.firstToApologizeCount,
      examples: youApologies.examples.slice(0, 5),
    },

    them: {
      totalApologies: themApologies.total,
      explicitApologies: themApologies.explicit,
      softApologies: themApologies.soft,
      apologyPercentage: received.length > 0 ? ((themApologies.total / received.length) * 100).toFixed(1) : 0,
      averageSincerity: themApologies.averageSincerity,
      reconciliationAttempts: themReconciliation.attempts,
      reconciliationPhrases: themReconciliation.phrases,
      firstToApologize: themApologies.firstToApologizeCount,
      examples: themApologies.examples.slice(0, 5),
    },

    comparison: {
      whoApologizesMore: getWhoApologizesMore(youApologies, themApologies),
      apologyDifference: Math.abs(youApologies.total - themApologies.total),
      balanceScore: calculateBalanceScore(youApologies.total, themApologies.total),
      reconciliationBalance: calculateBalanceScore(youReconciliation.attempts, themReconciliation.attempts),
    },

    reconciliation: {
      totalAttempts: youReconciliation.attempts + themReconciliation.attempts,
      successRate: reconciliationSuccess.successRate,
      averageResolutionTime: reconciliationSuccess.averageResolutionTime,
    },

    patterns: detectApologyPatterns_internal(messages),
    summary: generateApologySummary(youApologies, themApologies, youReconciliation, themReconciliation),
  }
}

/**
 * Analyze one person's apology patterns
 */
function analyzePersonApologies(personMessages, allMessages, direction) {
  let explicit = 0
  let soft = 0
  let totalSincerity = 0
  let firstToApologizeCount = 0
  const examples = []

  for (let i = 0; i < personMessages.length; i++) {
    const msg = personMessages[i]
    const text = (msg.content || '').toLowerCase()

    // Check for explicit apologies
    const hasExplicit = EXPLICIT_APOLOGIES.some((phrase) => text.includes(phrase))
    if (hasExplicit) {
      explicit++
      const sincerity = calculateSincerity(text)
      totalSincerity += sincerity
      examples.push({
        content: msg.content.substring(0, 100),
        sincerity,
        type: 'explicit',
      })

      // Check if they were first to apologize in this conflict
      if (wasFirstToApologize(allMessages, msg, direction)) {
        firstToApologizeCount++
      }
    }

    // Check for soft apologies
    const hasSoft = SOFT_APOLOGIES.some((phrase) => text.includes(phrase))
    if (hasSoft && !hasExplicit) {
      soft++
      const sincerity = calculateSincerity(text) * 0.7 // Soft apologies rated lower
      totalSincerity += sincerity
      examples.push({
        content: msg.content.substring(0, 100),
        sincerity,
        type: 'soft',
      })
    }
  }

  const total = explicit + soft
  return {
    total,
    explicit,
    soft,
    averageSincerity: total > 0 ? Math.round(totalSincerity / total) : 0,
    firstToApologizeCount,
    examples,
  }
}

/**
 * Calculate apology sincerity based on message characteristics
 */
function calculateSincerity(text) {
  let score = 50 // Base score

  // Length bonus - longer apologies tend to be more sincere
  if (text.length > 100) score += 15
  if (text.length > 200) score += 10

  // Specific acknowledgment phrases
  if (text.includes('i was wrong')) score += 20
  if (text.includes('my fault')) score += 15
  if (text.includes('i understand')) score += 10
  if (text.includes('hurt you') || text.includes('hurt your')) score += 15

  // Promise to change
  if (text.includes('wont happen') || text.includes("won't happen")) score += 15
  if (text.includes('i promise') || text.includes('ill try') || text.includes("i'll try")) score += 10

  // Deflection penalties
  if (text.includes('but you') || text.includes('but if you')) score -= 20
  if (text.includes('whatever') || text.includes('fine')) score -= 15
  if (text.includes('if you say so')) score -= 15

  return Math.max(0, Math.min(100, score))
}

/**
 * Check if this person was first to apologize in the surrounding conflict
 */
function wasFirstToApologize(allMessages, apologyMsg, direction) {
  const msgIndex = allMessages.findIndex((m) => m.id === apologyMsg.id)
  if (msgIndex === -1) return false

  // Look back up to 10 messages for conflict and other apologies
  const lookbackStart = Math.max(0, msgIndex - 10)
  const previousMessages = allMessages.slice(lookbackStart, msgIndex)

  // Check if there's a conflict indicator before this
  const hasConflictBefore = previousMessages.some((m) => {
    const text = (m.content || '').toLowerCase()
    return CONFLICT_INDICATORS.some((indicator) => text.includes(indicator))
  })

  if (!hasConflictBefore) return false

  // Check if the other person apologized first
  const otherDirection = direction === 'sent' ? 'received' : 'sent'
  const otherApologizedFirst = previousMessages.some((m) => {
    if (m.direction !== otherDirection) return false
    const text = (m.content || '').toLowerCase()
    return EXPLICIT_APOLOGIES.some((phrase) => text.includes(phrase))
  })

  return !otherApologizedFirst
}

/**
 * Analyze reconciliation attempts
 */
function analyzeReconciliation(personMessages) {
  let attempts = 0
  const phrases = []

  for (const msg of personMessages) {
    const text = (msg.content || '').toLowerCase()

    for (const phrase of RECONCILIATION_PHRASES) {
      if (text.includes(phrase)) {
        attempts++
        if (!phrases.includes(phrase)) {
          phrases.push(phrase)
        }
        break // Count each message only once
      }
    }
  }

  return { attempts, phrases }
}

/**
 * Analyze overall reconciliation success rate
 */
function analyzeReconciliationSuccess(messages) {
  let conflictCount = 0
  let resolvedCount = 0
  let totalResolutionTime = 0

  // Find conflict-resolution pairs
  for (let i = 0; i < messages.length - 1; i++) {
    const text = (messages[i].content || '').toLowerCase()
    const isConflict = CONFLICT_INDICATORS.some((indicator) => text.includes(indicator))

    if (isConflict) {
      conflictCount++

      // Look for resolution in next 20 messages
      for (let j = i + 1; j < Math.min(i + 20, messages.length); j++) {
        const resolveText = (messages[j].content || '').toLowerCase()
        const isResolved =
          RECONCILIATION_PHRASES.some((phrase) => resolveText.includes(phrase)) ||
          EXPLICIT_APOLOGIES.some((phrase) => resolveText.includes(phrase))

        if (isResolved) {
          resolvedCount++
          totalResolutionTime += j - i // Messages until resolution
          break
        }
      }
    }
  }

  return {
    successRate: conflictCount > 0 ? Math.round((resolvedCount / conflictCount) * 100) : 0,
    averageResolutionTime: resolvedCount > 0 ? Math.round(totalResolutionTime / resolvedCount) : 0,
  }
}

/**
 * Calculate who apologizes more
 */
function getWhoApologizesMore(youApologies, themApologies) {
  if (youApologies.total === themApologies.total) return 'equal'
  return youApologies.total > themApologies.total ? 'you' : 'them'
}

/**
 * Calculate apology ratio
 */
function calculateApologyRatio(youApologies, themApologies) {
  const total = youApologies.total + themApologies.total
  if (total === 0) return { you: 0, them: 0 }
  return {
    you: Math.round((youApologies.total / total) * 100),
    them: Math.round((themApologies.total / total) * 100),
  }
}

/**
 * Calculate balance score (0-100, where 50 is perfectly balanced)
 */
function calculateBalanceScore(youCount, themCount) {
  const total = youCount + themCount
  if (total === 0) return 50
  const ratio = youCount / total
  return Math.round(50 - Math.abs(50 - ratio * 100))
}

/**
 * Detect apology timing patterns
 */
function detectApologyPatterns_internal(messages) {
  const patterns = []

  // Check for immediate vs delayed apologies
  let immediateCount = 0
  let delayedCount = 0

  for (let i = 1; i < messages.length; i++) {
    const text = (messages[i].content || '').toLowerCase()
    const hasApology = EXPLICIT_APOLOGIES.some((phrase) => text.includes(phrase))

    if (hasApology) {
      const prevText = (messages[i - 1].content || '').toLowerCase()
      const wasConflict = CONFLICT_INDICATORS.some((indicator) => prevText.includes(indicator))

      if (wasConflict) {
        immediateCount++
      } else {
        delayedCount++
      }
    }
  }

  if (immediateCount > delayedCount) {
    patterns.push('Apologies tend to come immediately after conflict')
  } else if (delayedCount > immediateCount) {
    patterns.push('Apologies tend to come after cooling off periods')
  }

  return patterns
}

/**
 * Generate summary
 */
function generateApologySummary(youApologies, themApologies, youReconciliation, themReconciliation) {
  const parts = []

  const totalApologies = youApologies.total + themApologies.total
  if (totalApologies === 0) {
    return 'No apologies detected in the conversation.'
  }

  // Who apologizes more
  if (youApologies.total > themApologies.total * 1.5) {
    parts.push(`You apologize significantly more (${youApologies.total} vs ${themApologies.total})`)
  } else if (themApologies.total > youApologies.total * 1.5) {
    parts.push(`They apologize significantly more (${themApologies.total} vs ${youApologies.total})`)
  } else if (totalApologies > 0) {
    parts.push(`Apologies are relatively balanced (${youApologies.total} from you, ${themApologies.total} from them)`)
  }

  // Reconciliation
  const totalReconciliation = youReconciliation.attempts + themReconciliation.attempts
  if (totalReconciliation > 0) {
    parts.push(`${totalReconciliation} reconciliation attempts detected`)
  }

  // Sincerity
  const avgSincerity = (youApologies.averageSincerity + themApologies.averageSincerity) / 2
  if (avgSincerity >= 70) {
    parts.push('Apologies appear sincere and heartfelt')
  } else if (avgSincerity <= 40) {
    parts.push('Some apologies may lack depth or sincerity')
  }

  return parts.join('. ') + '.'
}

/**
 * Empty result for insufficient data
 */
function getEmptyResult() {
  return {
    hasApologies: false,
    totalApologies: 0,
    apologyRatio: { you: 0, them: 0 },
    you: {
      totalApologies: 0,
      explicitApologies: 0,
      softApologies: 0,
      apologyPercentage: 0,
      averageSincerity: 0,
      reconciliationAttempts: 0,
      reconciliationPhrases: [],
      firstToApologize: 0,
      examples: [],
    },
    them: {
      totalApologies: 0,
      explicitApologies: 0,
      softApologies: 0,
      apologyPercentage: 0,
      averageSincerity: 0,
      reconciliationAttempts: 0,
      reconciliationPhrases: [],
      firstToApologize: 0,
      examples: [],
    },
    comparison: {
      whoApologizesMore: 'equal',
      apologyDifference: 0,
      balanceScore: 50,
      reconciliationBalance: 50,
    },
    reconciliation: {
      totalAttempts: 0,
      successRate: 0,
      averageResolutionTime: 0,
    },
    patterns: [],
    summary: 'Not enough data to analyze apology patterns.',
  }
}
