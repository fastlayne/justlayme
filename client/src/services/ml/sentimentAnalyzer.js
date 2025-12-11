/**
 * sentimentAnalyzer.js
 * Analyzes sentiment (positive, negative, neutral) in conversation messages
 * Uses keyword matching, tone analysis, and linguistic indicators
 *
 * ARCHITECTURAL IMPROVEMENTS v2.0:
 * - Context-aware negation handling
 * - Word boundary matching (prevents "therapist" matching "the")
 * - N-gram phrase detection
 * - Sarcasm detection heuristics
 * - Modern relationship slang support
 * - Passive-aggressive pattern detection
 */

/**
 * Negation words that flip sentiment
 */
const NEGATION_WORDS = [
  'not', "n't", 'never', 'no', 'none', 'nobody', 'nothing', 'nowhere',
  'neither', 'nor', 'cannot', "can't", "won't", "wouldn't", "shouldn't",
  "couldn't", "didn't", "doesn't", "don't", "hasn't", "haven't", "isn't",
  "aren't", "wasn't", "weren't", 'barely', 'hardly', 'scarcely', 'seldom'
]

/**
 * Negation window - how many words after negation to check
 */
const NEGATION_WINDOW = 4

/**
 * Positive sentiment keywords - strong, moderate, weak indicators
 * EXPANDED with modern slang and relationship-specific terms
 */
const POSITIVE_KEYWORDS = {
  strong: [
    'love', 'amazing', 'wonderful', 'fantastic', 'excellent', 'awesome',
    'beautiful', 'perfect', 'incredible', 'outstanding', 'brilliant',
    'delighted', 'thrilled', 'ecstatic', 'adore', 'cherish', 'obsessed',
    'blessed', 'grateful', 'treasure', 'soulmate', 'forever', 'always yours',
    // Relationship affirmations
    'miss you', 'need you', 'want you', 'thinking of you', 'dreaming of you',
    'cant wait', "can't wait", 'so happy', 'so proud', 'best thing', 'my everything',
    'my world', 'my heart', 'my love', 'babe', 'baby', 'honey', 'sweetheart',
    // Modern slang
    'slay', 'iconic', 'goated', 'fire', 'bussin', 'elite', 'immaculate',
    'ate that', 'served', 'no cap', 'fr fr', 'real one', 'main character'
  ],
  moderate: [
    'good', 'great', 'nice', 'happy', 'glad', 'pleased', 'enjoyed',
    'like', 'lovely', 'sweet', 'kind', 'thoughtful', 'fun', 'exciting',
    'interesting', 'appreciate', 'thankful', 'proud', 'comfortable',
    'safe', 'supported', 'understood', 'valued', 'respected', 'cared',
    // Relationship terms
    'together', 'us', 'we', 'our', 'date', 'surprise', 'gift', 'special',
    'excited', 'looking forward', 'cant stop', "can't stop", 'always',
    'believe in you', 'trust you', 'support you', 'here for you',
    // Modern slang
    'valid', 'bet', 'lowkey', 'vibing', 'based', 'wholesome', 'cute',
    'adorable', 'precious', 'iconic', 'snatched', 'periodt', 'understood assignment'
  ],
  weak: [
    'okay', 'fine', 'sure', 'yeah', 'alright', 'decent', 'fair',
    'chill', 'solid', 'reasonable', 'manageable', 'cool', 'nice',
    'sounds good', 'works for me', 'im down', "i'm down", 'fasho'
  ]
}

/**
 * Negative sentiment keywords - strong, moderate, weak indicators
 * EXPANDED with relationship-specific terms
 */
const NEGATIVE_KEYWORDS = {
  strong: [
    'hate', 'horrible', 'terrible', 'awful', 'disgusting', 'despise',
    'rage', 'furious', 'devastated', 'miserable', 'suffering',
    'pathetic', 'sick of', 'done with', 'over it', 'betrayed',
    'heartbroken', 'crushed', 'destroyed', 'ruined', 'toxic',
    // Relationship pain
    'cheating', 'cheated', 'lied to me', 'lying', 'dont trust', "don't trust",
    'breaking up', 'break up', 'divorce', 'leave me', 'left me', 'abandoned',
    'used me', 'manipulated', 'gaslighting', 'abusive', 'controlling',
    // Modern slang
    'mid', 'cringe', 'yikes', 'oof', 'bruh', 'dead to me', 'blocked'
  ],
  moderate: [
    'bad', 'sad', 'disappointed', 'upset', 'annoyed', 'frustrated',
    'worried', 'concerned', 'confused', 'stressed', 'tired', 'exhausted',
    'dislike', 'gross', 'ugh', 'yuck', 'blah', 'drained', 'overwhelmed',
    'insecure', 'jealous', 'ignored', 'neglected', 'hurt', 'lonely',
    // Relationship strain
    'distant', 'cold', 'pulling away', 'space', 'need space', 'suffocating',
    'clingy', 'needy', 'demanding', 'controlling', 'selfish', 'inconsiderate',
    'unappreciated', 'taken for granted', 'second choice', 'backup plan',
    // Modern slang
    'sus', 'sketchy', 'weird', 'off', 'uncomfortable', 'red flag', 'toxic trait',
    'ick', 'giving me the ick', 'npc behavior', 'chronically online'
  ],
  weak: [
    'meh', 'eh', 'hmm', 'nah', 'nope', 'kinda bad', 'not great',
    'could be better', 'idk', 'unsure', 'uncertain', 'maybe not',
    'not sure', 'i guess', 'not really', 'whatever', 'nm', 'nvrmnd'
  ]
}

/**
 * Passive-aggressive patterns - strongly indicate negativity
 */
const PASSIVE_AGGRESSIVE_PATTERNS = [
  'fine', 'whatever', 'sure', 'k', 'okay then', 'if you say so',
  'do what you want', 'do whatever', 'i guess', 'never mind',
  'forget it', 'it\'s fine', 'i\'m fine', 'not mad', 'not upset',
  'no worries', 'don\'t worry about it', 'doesn\'t matter',
  'as you wish', 'have fun', 'good for you', 'must be nice'
]

/**
 * Sarcasm indicators - text patterns that suggest sarcasm
 */
const SARCASM_INDICATORS = [
  'oh great', 'oh wonderful', 'oh perfect', 'oh amazing', 'oh sure',
  'yeah right', 'sure sure', 'totally', 'obviously', 'clearly',
  'of course', 'wow just wow', 'brilliant', 'genius', 'thanks so much'
]

/**
 * Question words that indicate engagement/interest
 */
const QUESTION_INDICATORS = ['?', 'what', 'why', 'how', 'when', 'where', 'who', 'which']

/**
 * Emoji sentiment mapping - EXPANDED
 */
const EMOJI_SENTIMENT = {
  positive: [
    '😊', '😄', '😍', '❤️', '👍', '🎉', '💯', '✨', '🔥', '😘', '🙌', '😃', '😁', '😆',
    '🥰', '💕', '💖', '💗', '💓', '💞', '💘', '😻', '🤗', '☺️', '🥳', '🤩', '😎', '💪',
    '👏', '🙏', '😇', '🌟', '⭐', '🌈', '🦋', '💐', '🌹', '🌺', '🎊', '🎁', '💝'
  ],
  negative: [
    '😢', '😞', '😡', '😠', '💔', '👎', '😒', '🙄', '😤', '😭', '😫', '😩', '😔',
    '😟', '😕', '🙁', '☹️', '😣', '😖', '😪', '😥', '😰', '😨', '😱', '😬', '🤢',
    '🤮', '😵', '🥴', '😷', '🤒', '💀', '☠️', '😈', '👿', '🖕'
  ],
  // Ambiguous emoji that need context
  ambiguous: ['😅', '😂', '🤣', '😏', '🤔', '🤷', '😑', '😐', '🫠']
}

/**
 * Analyze sentiment of messages
 * @param {Array} messages - Normalized messages from messageParser
 * @returns {Object} Sentiment analysis results with score and breakdown
 */
export function analyzeSentiment(messages) {
  if (!messages || messages.length === 0) {
    return {
      overallScore: 0,
      sentiment: 'neutral',
      confidence: 0,
      breakdown: {
        positive: 0,
        negative: 0,
        neutral: 0,
      },
      analysis: [],
      summary: 'No messages to analyze',
    }
  }

  // Analyze each message
  const sentiments = messages.map((message) => analyzeSingleMessage(message))

  // Calculate overall sentiment
  const positiveCount = sentiments.filter((s) => s.sentiment === 'positive').length
  const negativeCount = sentiments.filter((s) => s.sentiment === 'negative').length
  const neutralCount = sentiments.filter((s) => s.sentiment === 'neutral').length

  // Calculate weighted sentiment score (-1 to 1)
  const totalScore = sentiments.reduce((sum, s) => sum + s.score, 0)
  const averageScore = sentiments.length > 0 ? totalScore / sentiments.length : 0

  // Determine overall sentiment
  let overallSentiment = 'neutral'
  if (averageScore > 0.2) overallSentiment = 'positive'
  else if (averageScore < -0.2) overallSentiment = 'negative'

  // Calculate confidence (how certain we are)
  const dominantCount = Math.max(positiveCount, negativeCount, neutralCount)
  const confidence = sentiments.length > 0 ? (dominantCount / sentiments.length) : 0

  return {
    overallScore: parseFloat(averageScore.toFixed(3)),
    sentiment: overallSentiment,
    confidence: parseFloat((confidence * 100).toFixed(1)),
    breakdown: {
      positive: positiveCount,
      negative: negativeCount,
      neutral: neutralCount,
      percentages: {
        positive: parseFloat(((positiveCount / sentiments.length) * 100).toFixed(1)),
        negative: parseFloat(((negativeCount / sentiments.length) * 100).toFixed(1)),
        neutral: parseFloat(((neutralCount / sentiments.length) * 100).toFixed(1)),
      },
    },
    analysis: sentiments,
    emotionalIntensity: calculateEmotionalIntensity(sentiments),
    summary: generateSentimentSummary(overallSentiment, averageScore, sentiments),
  }
}

/**
 * Analyze sentiment of a single message
 * IMPROVED: Negation handling, sarcasm detection, passive-aggressive patterns
 * @param {Object} message - Message object with content
 * @returns {Object} Sentiment analysis for message
 */
function analyzeSingleMessage(message) {
  const text = message.content.toLowerCase().trim()
  const words = text.split(/\s+/)

  let score = 0
  let indicators = []
  let negationDetected = false
  let sarcasmDetected = false
  let passiveAggressiveDetected = false

  // 1. Check for sarcasm patterns FIRST (affects interpretation)
  sarcasmDetected = detectSarcasm(text)
  if (sarcasmDetected) {
    indicators.push('sarcasm_detected')
  }

  // 2. Check for passive-aggressive patterns
  passiveAggressiveDetected = detectPassiveAggressive(text)
  if (passiveAggressiveDetected) {
    score -= 0.4 // Passive-aggressive is negative
    indicators.push('passive_aggressive')
  }

  // 3. Check for positive keywords WITH negation awareness
  const positiveMatches = countKeywordMatchesWithNegation(text, words, POSITIVE_KEYWORDS)
  if (positiveMatches.count > 0) {
    // If negated, flip the sentiment
    if (positiveMatches.negated > 0) {
      score -= positiveMatches.negatedWeight
      negationDetected = true
      indicators.push(`negated_positive: ${positiveMatches.negated}`)
    }
    if (positiveMatches.nonNegated > 0) {
      // If sarcasm detected, reduce positive impact
      const adjustedWeight = sarcasmDetected ? positiveMatches.nonNegatedWeight * 0.3 : positiveMatches.nonNegatedWeight
      score += adjustedWeight
      indicators.push(`positive_keywords: ${positiveMatches.nonNegated}`)
    }
  }

  // 4. Check for negative keywords WITH negation awareness
  const negativeMatches = countKeywordMatchesWithNegation(text, words, NEGATIVE_KEYWORDS)
  if (negativeMatches.count > 0) {
    // If negated ("not sad"), it's slightly positive
    if (negativeMatches.negated > 0) {
      score += negativeMatches.negatedWeight * 0.5 // "not sad" is only mildly positive
      negationDetected = true
      indicators.push(`negated_negative: ${negativeMatches.negated}`)
    }
    if (negativeMatches.nonNegated > 0) {
      score -= negativeMatches.nonNegatedWeight
      indicators.push(`negative_keywords: ${negativeMatches.nonNegated}`)
    }
  }

  // 5. Check for questions (indicates engagement/interest)
  const questionCount = (text.match(/\?/g) || []).length
  if (questionCount > 0) {
    score += Math.min(questionCount * 0.12, 0.4)
    indicators.push(`questions: ${questionCount}`)
  }

  // 6. Check for all-caps words (emotional intensity)
  const capsWords = (message.content.match(/\b[A-Z]{2,}\b/g) || []).length
  if (capsWords > 0) {
    const intensity = Math.min(capsWords * 0.1, 0.4)
    // Caps can amplify existing sentiment
    if (score > 0) score += intensity
    else if (score < 0) score -= intensity
    indicators.push(`caps: ${capsWords}`)
  }

  // 7. Check for emoji sentiment
  const emojiSentiment = analyzeEmoji(message.content)
  if (emojiSentiment.score !== 0) {
    score += emojiSentiment.score
    indicators.push(`emoji: ${emojiSentiment.type}`)
  }

  // 8. Check for exclamation marks (intensity amplifier)
  const exclamations = (text.match(/!/g) || []).length
  if (exclamations > 0) {
    const intensity = Math.min(exclamations * 0.06, 0.25)
    if (score > 0) score += intensity
    else if (score < 0) score -= intensity
    indicators.push(`exclamations: ${exclamations}`)
  }

  // 9. Short message penalty for weak words like "k", "fine", "ok"
  if (text.length <= 3 && /^(k|ok|fine|sure|meh|eh|hmm)$/i.test(text.trim())) {
    score -= 0.3 // Short dismissive responses are negative
    indicators.push('dismissive_response')
  }

  // Normalize score to -1 to 1
  score = Math.max(-1, Math.min(1, score))

  // Determine sentiment classification
  let sentiment = 'neutral'
  if (score > 0.15) sentiment = 'positive'
  else if (score < -0.15) sentiment = 'negative'

  return {
    messageId: message.id,
    content: message.content.substring(0, 50) + (message.content.length > 50 ? '...' : ''),
    score: parseFloat(score.toFixed(3)),
    sentiment,
    indicators,
    length: message.content.length,
    flags: {
      negationDetected,
      sarcasmDetected,
      passiveAggressiveDetected
    }
  }
}

/**
 * Detect sarcasm in text
 * @param {string} text - Lowercase text
 * @returns {boolean} True if sarcasm detected
 */
function detectSarcasm(text) {
  // Check explicit sarcasm indicators
  for (const pattern of SARCASM_INDICATORS) {
    if (text.includes(pattern)) return true
  }

  // Check for repeated positive words (often sarcastic)
  if (/(\b(great|wonderful|perfect|amazing|nice|lovely)\b.*){2,}/i.test(text)) {
    return true
  }

  // Check for eye-roll pattern: positive word + punctuation overuse
  if (/\b(great|wonderful|perfect|amazing)\b.*[.!]{2,}$/i.test(text)) {
    return true
  }

  return false
}

/**
 * Detect passive-aggressive patterns
 * @param {string} text - Lowercase text
 * @returns {boolean} True if passive-aggressive detected
 */
function detectPassiveAggressive(text) {
  const trimmed = text.trim()

  // Single-word dismissive responses
  if (/^(k|fine|whatever|sure|okay)\.?$/i.test(trimmed)) {
    return true
  }

  // Check for passive-aggressive patterns
  for (const pattern of PASSIVE_AGGRESSIVE_PATTERNS) {
    // Only match if it's the whole message or a significant part
    if (trimmed === pattern || trimmed.startsWith(pattern + '.') || trimmed.startsWith(pattern + '!')) {
      return true
    }
  }

  // "I'm fine" / "It's fine" patterns
  if (/\b(i'?m|it'?s|that'?s)\s+(fine|okay|ok|whatever)\b/i.test(text)) {
    return true
  }

  return false
}

/**
 * Count keyword matches with weighted scoring (legacy - kept for backward compatibility)
 * @param {string} text - Text to search
 * @param {Object} keywords - Keywords object with strength levels
 * @returns {Object} Count and weighted score
 */
function countKeywordMatches(text, keywords) {
  let count = 0
  let weight = 0

  // Strong keywords (weight: 0.6)
  for (const keyword of keywords.strong) {
    const matches = matchWordBoundary(text, keyword)
    count += matches
    weight += matches * 0.6
  }

  // Moderate keywords (weight: 0.35)
  for (const keyword of keywords.moderate) {
    const matches = matchWordBoundary(text, keyword)
    count += matches
    weight += matches * 0.35
  }

  // Weak keywords (weight: 0.15)
  for (const keyword of keywords.weak) {
    const matches = matchWordBoundary(text, keyword)
    count += matches
    weight += matches * 0.15
  }

  // Cap the weight to prevent over-amplification
  weight = Math.min(weight, 1)

  return { count, weight }
}

/**
 * Match word with proper boundaries (prevents "therapist" matching "the")
 * @param {string} text - Text to search
 * @param {string} keyword - Keyword to find
 * @returns {number} Number of matches
 */
function matchWordBoundary(text, keyword) {
  // Escape special regex characters in keyword
  const escaped = keyword.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  // Use word boundaries for single words, looser matching for phrases
  const pattern = keyword.includes(' ')
    ? new RegExp(escaped, 'gi')
    : new RegExp(`\\b${escaped}\\b`, 'gi')
  return (text.match(pattern) || []).length
}

/**
 * Count keyword matches WITH negation awareness
 * Handles "I don't love you" correctly by detecting negation context
 * @param {string} text - Full text
 * @param {Array} words - Text split into words
 * @param {Object} keywords - Keywords object with strength levels
 * @returns {Object} Detailed match info with negation tracking
 */
function countKeywordMatchesWithNegation(text, words, keywords) {
  let count = 0
  let negated = 0
  let nonNegated = 0
  let negatedWeight = 0
  let nonNegatedWeight = 0

  const weights = { strong: 0.6, moderate: 0.35, weak: 0.15 }

  for (const [level, keywordList] of Object.entries(keywords)) {
    const levelWeight = weights[level] || 0.3

    for (const keyword of keywordList) {
      // Find all positions of this keyword
      const positions = findKeywordPositions(words, keyword)

      for (const pos of positions) {
        count++

        // Check if keyword is negated (look back NEGATION_WINDOW words)
        const isNegated = checkNegationContext(words, pos)

        if (isNegated) {
          negated++
          negatedWeight += levelWeight
        } else {
          nonNegated++
          nonNegatedWeight += levelWeight
        }
      }
    }
  }

  // Cap weights
  negatedWeight = Math.min(negatedWeight, 1)
  nonNegatedWeight = Math.min(nonNegatedWeight, 1)

  return { count, negated, nonNegated, negatedWeight, nonNegatedWeight }
}

/**
 * Find positions of keyword in word array
 * @param {Array} words - Words array
 * @param {string} keyword - Keyword (can be phrase)
 * @returns {Array} Array of starting positions
 */
function findKeywordPositions(words, keyword) {
  const positions = []
  const keywordWords = keyword.toLowerCase().split(/\s+/)

  for (let i = 0; i <= words.length - keywordWords.length; i++) {
    let match = true
    for (let j = 0; j < keywordWords.length; j++) {
      // Clean word for comparison (remove punctuation)
      const cleanWord = words[i + j].replace(/[.,!?;:'"]/g, '')
      if (cleanWord !== keywordWords[j]) {
        match = false
        break
      }
    }
    if (match) {
      positions.push(i)
    }
  }

  return positions
}

/**
 * Check if position is in negation context
 * @param {Array} words - Words array
 * @param {number} pos - Position of keyword
 * @returns {boolean} True if negated
 */
function checkNegationContext(words, pos) {
  // Look back up to NEGATION_WINDOW words for negation
  const startPos = Math.max(0, pos - NEGATION_WINDOW)

  for (let i = startPos; i < pos; i++) {
    const word = words[i].toLowerCase().replace(/[.,!?;:'"]/g, '')

    // Check for negation words
    for (const negWord of NEGATION_WORDS) {
      if (word === negWord || word.includes(negWord)) {
        return true
      }
    }
  }

  return false
}

/**
 * Analyze emoji sentiment in text
 * @param {string} text - Text containing emoji
 * @returns {Object} Emoji sentiment score and type
 */
function analyzeEmoji(text) {
  let score = 0
  let type = 'neutral'

  // Check positive emoji
  for (const emoji of EMOJI_SENTIMENT.positive) {
    if (text.includes(emoji)) {
      score += 0.3
      type = 'positive'
    }
  }

  // Check negative emoji
  for (const emoji of EMOJI_SENTIMENT.negative) {
    if (text.includes(emoji)) {
      score -= 0.3
      type = 'negative'
    }
  }

  return { score: Math.max(-1, Math.min(1, score)), type }
}

/**
 * Calculate emotional intensity of conversation
 * @param {Array} sentiments - Array of sentiment analyses
 * @returns {Object} Intensity metrics
 */
function calculateEmotionalIntensity(sentiments) {
  const scores = sentiments.map((s) => Math.abs(s.score))
  const avgIntensity = scores.reduce((a, b) => a + b, 0) / sentiments.length
  // ARCHITECTURAL FIX: Use reduce instead of spread to avoid stack overflow on large arrays
  const maxIntensity = scores.reduce((max, val) => val > max ? val : max, scores[0] || 0)

  return {
    average: parseFloat(avgIntensity.toFixed(3)),
    max: parseFloat(maxIntensity.toFixed(3)),
    level: avgIntensity > 0.6 ? 'high' : avgIntensity > 0.3 ? 'moderate' : 'low',
  }
}

/**
 * Generate human-readable sentiment summary
 * @param {string} sentiment - Overall sentiment
 * @param {number} score - Sentiment score
 * @param {Array} sentiments - Individual message sentiments
 * @returns {string} Summary text
 */
function generateSentimentSummary(sentiment, score, sentiments) {
  const positive = sentiments.filter((s) => s.sentiment === 'positive').length
  const negative = sentiments.filter((s) => s.sentiment === 'negative').length
  const neutral = sentiments.filter((s) => s.sentiment === 'neutral').length
  const total = sentiments.length

  if (sentiment === 'positive') {
    return `Overall positive sentiment (${positive}/${total} messages). Shows warmth and positive emotion with ${(((positive / total) * 100).toFixed(0))}% positive messages.`
  } else if (sentiment === 'negative') {
    return `Overall negative sentiment (${negative}/${total} messages). Shows frustration or dissatisfaction with ${(((negative / total) * 100).toFixed(0))}% negative messages.`
  } else {
    return `Overall neutral sentiment. Mix of ${positive} positive, ${negative} negative, and ${neutral} neutral messages. Balanced communication style.`
  }
}

/**
 * Compare sentiment between two parties in a conversation
 * @param {Array} messages - Messages from both parties
 * @returns {Object} Sentiment comparison
 */
export function compareSentiment(messages) {
  if (messages.length < 2) {
    return {
      comparison: 'insufficient_data',
      message: 'Need at least 2 messages from different parties',
    }
  }

  // Group messages by direction (sent/received)
  const sent = messages.filter((m) => m.direction === 'sent')
  const received = messages.filter((m) => m.direction === 'received')

  if (sent.length === 0 || received.length === 0) {
    return {
      comparison: 'insufficient_data',
      message: 'Need messages from both parties',
    }
  }

  const sentSentiment = analyzeSentiment(sent)
  const receivedSentiment = analyzeSentiment(received)

  const diff = sentSentiment.overallScore - receivedSentiment.overallScore

  return {
    youSentiment: {
      score: sentSentiment.overallScore,
      sentiment: sentSentiment.sentiment,
      messageCount: sent.length,
    },
    themSentiment: {
      score: receivedSentiment.overallScore,
      sentiment: receivedSentiment.sentiment,
      messageCount: received.length,
    },
    difference: parseFloat(diff.toFixed(3)),
    morePositive: diff > 0.1 ? 'you' : diff < -0.1 ? 'them' : 'balanced',
    summary: generateComparativeSummary(sentSentiment, receivedSentiment, diff),
  }
}

/**
 * Generate comparative sentiment summary
 * @param {Object} sentSent - Your sentiment
 * @param {Object} receivedSent - Their sentiment
 * @param {number} diff - Difference in scores
 * @returns {string} Comparison summary
 */
function generateComparativeSummary(sentSent, receivedSent, diff) {
  if (Math.abs(diff) < 0.1) {
    return 'Both parties show similar sentiment. Balanced emotional exchange.'
  } else if (diff > 0.1) {
    return `You show more positive sentiment (${sentSent.overallScore}) than them (${receivedSent.overallScore}). You seem more invested or enthusiastic.`
  } else {
    return `They show more positive sentiment (${receivedSent.overallScore}) than you (${sentSent.overallScore}). They seem more invested or enthusiastic.`
  }
}
