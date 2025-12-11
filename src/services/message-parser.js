/**
 * message-parser.js (Server-Side)
 * Normalizes and parses raw conversation data
 * Handles multiple formats: JSON, CSV, plain text, iMessage exports
 *
 * This is the Node.js equivalent of client/src/services/ml/messageParser.js
 */

/**
 * Parse raw conversation data into standardized format
 * @param {string|object} data - Raw conversation data
 * @param {string} format - Format type: 'paste', 'file', 'screenshot'
 * @param {object} personalization - User/contact names for correct attribution
 * @returns {Array} Normalized messages array
 */
function parseConversationData(data, format = 'paste', personalization = null) {
  try {
    // Validate input
    if (!data) {
      console.warn('[MessageParser] No data provided')
      return []
    }

    let messages = []

    if (format === 'paste') {
      messages = parseTextFormat(data)
    } else if (format === 'file') {
      messages = parseFileFormat(data)
    } else if (format === 'screenshot') {
      messages = parseScreenshotFormat(data)
    } else {
      // Default to text format for unknown types
      console.warn(`[MessageParser] Unknown format "${format}", defaulting to text parsing`)
      messages = parseTextFormat(data)
    }

    return normalizeMessages(messages, personalization)
  } catch (error) {
    console.error('[MessageParser] Parsing error:', error)
    // ARCHITECTURAL FIX: Never throw - return empty array with error logged
    // This ensures graceful error handling instead of crashing
    return []
  }
}

/**
 * Parse plain text format conversations
 * Supports multiple formats:
 * - "Person: message"
 * - "timestamp - person: message"
 * - iMessage export format (multi-line blocks with from/to indicators)
 */
function parseTextFormat(text) {
  try {
    // Handle various text encodings and normalize
    const normalizedText = typeof text === 'string' ? text : String(text)

    console.log(`[MessageParser] Starting parse...`)

    // DETECT iMessage export format
    // Pattern: "2018-11-18 23:14:08 from Name" or "2018-11-18 23:14:21 to Name"
    if (normalizedText.includes(' from ') && normalizedText.includes(' to ') &&
        /\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\s+(from|to)\s+/.test(normalizedText)) {
      console.log('[MessageParser] Detected iMessage export format')
      return parseIMessageFormat(normalizedText)
    }

    // Default line-by-line parsing
    const lines = normalizedText.split(/\r?\n/).filter((line) => line.trim())
    const messages = []

    console.log(`[MessageParser] Using line-by-line parse: ${lines.length} lines total`)
    if (lines.length > 0) {
      console.log(`[MessageParser] First 3 lines:`)
      for (let i = 0; i < Math.min(3, lines.length); i++) {
        console.log(`  Line ${i}: ${lines[i].substring(0, 100)}`)
      }
    }

    for (let i = 0; i < lines.length; i++) {
      try {
        const message = parseMessageLine(lines[i], i)
        if (message) {
          messages.push(message)
        }
      } catch (lineError) {
        // Skip malformed lines but continue parsing
        console.warn(`[MessageParser] Error parsing line ${i}, skipping:`, lineError)
      }
    }

    console.log(`[MessageParser] Parsed ${messages.length} messages from ${lines.length} lines`)
    return messages
  } catch (error) {
    console.error('[MessageParser] Error in parseTextFormat:', error)
    return []
  }
}

/**
 * Parse iMessage export format
 * Format example:
 * ----------------------------------------------------
 * Amber
 * 2018-11-18 23:14:08 from Amber (email) - Recently deleted
 *
 * One sec I'm gonna FaceTime you off of my laptop
 * ----------------------------------------------------
 *
 * Key patterns:
 * - "from Name" = received message (from them)
 * - "to Name" = sent message (from you)
 */
function parseIMessageFormat(text) {
  const messages = []

  // Split by the separator line
  const blocks = text.split(/[-]{20,}/)

  console.log(`[MessageParser] iMessage format: ${blocks.length} blocks found`)

  for (const block of blocks) {
    const trimmedBlock = block.trim()
    if (!trimmedBlock) continue

    // Parse the header line with timestamp and direction
    // Pattern: "2018-11-18 23:14:08 from Amber (email) - Recently deleted"
    // Pattern: "2018-11-18 23:14:21 to Amber - Recently deleted"
    const headerMatch = trimmedBlock.match(
      /(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(from|to)\s+([^\n(]+?)(?:\s*\([^)]*\))?\s*(?:-[^\n]*)?\n/i
    )

    if (!headerMatch) {
      // Try alternate format without newline
      const altMatch = trimmedBlock.match(
        /(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(from|to)\s+([^\n(]+?)(?:\s*\([^)]*\))?\s*(?:-[^\n]*)?$/im
      )
      if (!altMatch) continue
    }

    const match = headerMatch || trimmedBlock.match(
      /(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})\s+(from|to)\s+([^\n(]+?)(?:\s*\([^)]*\))?\s*(?:-[^\n]*)?/i
    )

    if (!match) continue

    const [fullMatch, timestampStr, direction, senderName] = match
    const timestamp = new Date(timestampStr.replace(' ', 'T'))

    // Extract message content (everything after the header line)
    let content = trimmedBlock.substring(trimmedBlock.indexOf(fullMatch) + fullMatch.length).trim()

    // Remove the contact name if it appears at the start
    const lines = trimmedBlock.split('\n')
    if (lines.length > 0 && lines[0].trim() === senderName.trim()) {
      // First line is just the name, skip it
      const afterName = trimmedBlock.substring(trimmedBlock.indexOf('\n') + 1)
      const afterHeader = afterName.substring(afterName.indexOf(fullMatch) + fullMatch.length).trim()
      content = afterHeader || content
    }

    // Clean up content - remove empty lines at start
    content = content.replace(/^\s*\n+/, '').trim()

    if (!content || content.length === 0) continue

    // Direction: "from" = received, "to" = sent
    // We mark the USER as the sender when direction is "to"
    // We mark the OTHER PERSON as sender when direction is "from"
    const sender = direction.toLowerCase() === 'to' ? 'You' : senderName.trim()

    messages.push({
      timestamp,
      sender,
      content,
      length: content.length,
      // Store explicit direction for normalizeMessages
      _iMessageDirection: direction.toLowerCase() === 'to' ? 'sent' : 'received',
    })
  }

  console.log(`[MessageParser] iMessage format: Parsed ${messages.length} messages`)
  return messages
}

/**
 * Parse file format (JSON, CSV, etc.)
 */
function parseFileFormat(data) {
  try {
    // Try JSON first if data looks like JSON
    if (typeof data === 'string' && (data.trimStart().startsWith('{') || data.trimStart().startsWith('['))) {
      try {
        const json = JSON.parse(data)
        if (Array.isArray(json)) {
          console.log('[MessageParser] Parsed as JSON array')
          return json
        } else if (json.messages && Array.isArray(json.messages)) {
          console.log('[MessageParser] Parsed as JSON with messages property')
          return json.messages
        }
      } catch (jsonError) {
        // Not valid JSON, continue to text parsing
        console.log('[MessageParser] JSON parse failed, trying text format')
      }
    }

    // ARCHITECTURAL FIX: Always fall back to text parsing
    // This ensures ANY text file can be analyzed
    return parseTextFormat(data)
  } catch (error) {
    console.error('[MessageParser] Error in parseFileFormat:', error)
    // Final fallback - return empty array rather than crashing
    return []
  }
}

/**
 * Parse screenshot OCR format
 */
function parseScreenshotFormat(data) {
  // Placeholder for OCR processing
  // In production, would integrate with OCR service
  return parseTextFormat(data)
}

/**
 * Parse single message line
 * Supports formats:
 * - "Person: message"
 * - "12:34 PM - Person: message"
 * - "2024-01-15 12:34 - Person: message"
 * - Plain text lines (fallback for non-standard formats)
 *
 * @param {string} line - The message line to parse
 * @param {number} lineIndex - The index of the line for deterministic alternation
 */
function parseMessageLine(line, lineIndex = 0) {
  if (!line || !line.trim()) return null

  // Extract timestamp if present
  let timestamp = new Date()
  let content = line
  let sender = 'unknown'

  // Try to extract timestamp - support ALL common messaging formats:
  const timestampPatterns = [
    // WhatsApp/iMessage: "7/29/22, 1:22 PM - Name:" or "7/29/22, 13:22 - Name:"
    /^\d{1,2}\/\d{1,2}\/\d{2,4},?\s+\d{1,2}:\d{2}(?::\d{2})?\s?(?:AM|PM)?\s*[-–—]\s*/,
    // ISO format: "2024-07-29 13:22:45" or "2024-07-29T13:22:45Z"
    /^\d{4}-\d{2}-\d{2}[T\s]\d{1,2}:\d{2}(?::\d{2})?(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2})?\s*[-–—:]\s*/,
    // Discord: "[13:22]" or "[1:22 PM]"
    /^\[\d{1,2}:\d{2}(?:\s?(?:AM|PM))?\]\s*/,
    // Slack: "1:22 PM" or "13:22"
    /^\d{1,2}:\d{2}(?::\d{2})?\s?(?:AM|PM)?\s*[-–—]\s*/,
    // Telegram: "Name, [29.07.22 13:22]"
    /^\[?\d{1,2}\.\d{1,2}\.\d{2,4}\s+\d{1,2}:\d{2}(?::\d{2})?\]?\s*[-–—]?\s*/,
    // SMS exports: "(7/29/22 1:22 PM)"
    /^\(?\d{1,2}\/\d{1,2}\/\d{2,4}\s+\d{1,2}:\d{2}(?:\s?(?:AM|PM))?\)?\s*[-–—:]\s*/,
  ]

  let timestampMatch = null
  for (const pattern of timestampPatterns) {
    timestampMatch = line.match(pattern)
    if (timestampMatch) break
  }

  if (timestampMatch) {
    content = line.replace(timestampMatch[0], '').trim()
    // Try to parse timestamp
    try {
      const parsedDate = new Date(timestampMatch[0])
      // ARCHITECTURAL FIX: Validate parsed date
      if (!isNaN(parsedDate.getTime())) {
        timestamp = parsedDate
      }
    } catch (e) {
      // Keep default timestamp
    }
  }

  // Extract sender and message with flexible delimiter matching
  // Try colon first (most common)
  const colonMatch = content.match(/^([^:]+):\s*(.+)$/)
  if (colonMatch) {
    sender = colonMatch[1].trim()
    content = colonMatch[2].trim()
  } else {
    // Try other common delimiters (hyphen, arrow, pipe)
    const altMatch = content.match(/^([^-–—|→>]+)\s*[-–—|→>]\s*(.+)$/)
    if (altMatch) {
      sender = altMatch[1].trim()
      content = altMatch[2].trim()
    } else {
      // ARCHITECTURAL FIX: Fallback for non-standard formats
      // Treat entire line as message from alternating senders
      // This enables analysis of plain text conversations
      content = content.trim()
      // Deterministically alternate senders based on line position
      // Even indices (0, 2, 4...) = person1, Odd indices (1, 3, 5...) = person2
      sender = lineIndex % 2 === 0 ? 'person1' : 'person2'
    }
  }

  if (!content || content.length === 0) return null

  return {
    timestamp,
    sender,
    content,
    length: content.length,
  }
}

/**
 * Normalize messages to standard format
 * Identifies sender, infers message direction, calculates intervals
 * ENHANCED: Supports explicit direction from iMessage format
 * CRITICAL FIX: Uses personalization to correctly attribute messages
 * @param {Array} messages - Parsed messages
 * @param {object} personalization - User/contact names for correct attribution
 */
function normalizeMessages(messages, personalization = null) {
  // ARCHITECTURAL FIX: Validate messages array
  if (!messages || !Array.isArray(messages)) {
    return []
  }

  // ARCHITECTURAL FIX: High message limit to support years of conversation history
  // 500K messages ≈ ~5 years of active texting (avg 275 msgs/day)
  // Analysis uses statistical sampling so more data = better insights
  const MAX_MESSAGES = 500000
  if (messages.length > MAX_MESSAGES) {
    console.warn(`Message count (${messages.length}) exceeds maximum. Truncating to ${MAX_MESSAGES}`)
    messages = messages.slice(0, MAX_MESSAGES)
  }

  if (messages.length < 2) {
    return messages.map((m, i) => ({
      ...m,
      id: i,
      direction: m._iMessageDirection || 'sent', // Use explicit direction if available
      timeSinceLast: null,
    }))
  }

  // Check if messages have explicit direction (from iMessage parser)
  const hasExplicitDirection = messages.some(m => m._iMessageDirection)

  // Identify unique senders (for non-iMessage formats)
  const senders = [...new Set(messages.map((m) => m.sender || 'unknown'))].sort()
  const [person1, person2] = senders.slice(0, 2)

  // CRITICAL: Determine which sender is the user based on personalization
  let userSender = person1

  if (personalization && personalization.userName) {
    // Match sender name to userName (case-insensitive, fuzzy match)
    const userName = personalization.userName.toLowerCase().trim()
    const matchingSender = senders.find(s =>
      s && s.toLowerCase().trim().includes(userName) ||
      userName.includes(s.toLowerCase().trim())
    )

    if (matchingSender) {
      userSender = matchingSender
      console.log(`✅ Matched user "${personalization.userName}" to sender "${matchingSender}"`)
    } else {
      console.warn(`⚠️ Could not match userName "${personalization.userName}" to any sender. Using first sender as user.`)
      console.warn(`   Available senders: ${senders.join(', ')}`)
    }
  } else if (hasExplicitDirection) {
    // For iMessage format, determine which sender is "You"
    // "You" is marked when direction is "to" in iMessage
    const sentMsg = messages.find(m => m._iMessageDirection === 'sent')
    if (sentMsg) {
      userSender = sentMsg.sender
    }
  }

  // Normalize messages with metadata
  return messages.map((m, i) => {
    // ARCHITECTURAL FIX: Safely calculate time difference
    let timeSinceLast = null
    if (i > 0) {
      try {
        const currentTime = m.timestamp && typeof m.timestamp.getTime === 'function'
          ? m.timestamp.getTime()
          : Date.now()
        const previousTime = messages[i - 1].timestamp && typeof messages[i - 1].timestamp.getTime === 'function'
          ? messages[i - 1].timestamp.getTime()
          : Date.now()
        timeSinceLast = currentTime - previousTime
      } catch (e) {
        console.warn('Failed to calculate time difference:', e)
        timeSinceLast = null
      }
    }

    // Determine direction:
    // 1. Use explicit _iMessageDirection if available
    // 2. Otherwise infer from sender (first sender = sent, others = received)
    let direction
    if (m._iMessageDirection) {
      direction = m._iMessageDirection
    } else if (m.sender === userSender || m.sender === person1) {
      direction = 'sent'
    } else {
      direction = 'received'
    }

    // Clean up internal properties
    const { _iMessageDirection, ...cleanMessage } = m

    return {
      ...cleanMessage,
      id: i,
      direction,
      person: m.sender || 'unknown',
      timeSinceLast,
    }
  })
}

/**
 * Get conversation statistics
 */
function getConversationStats(messages) {
  if (!messages.length) {
    return {
      totalMessages: 0,
      uniqueSenders: 0,
      dateRange: null,
      averageMessageLength: 0,
    }
  }

  const uniqueSenders = new Set(messages.map((m) => m.sender)).size
  const totalLength = messages.reduce((sum, m) => sum + (m.length || 0), 0)
  const avgLength = Math.round(totalLength / messages.length)

  const timestamps = messages.map((m) => m.timestamp).sort((a, b) => a.getTime() - b.getTime())

  return {
    totalMessages: messages.length,
    uniqueSenders,
    dateRange: {
      start: timestamps[0],
      end: timestamps[timestamps.length - 1],
    },
    averageMessageLength: avgLength,
  }
}

module.exports = {
  parseConversationData,
  getConversationStats,
}
