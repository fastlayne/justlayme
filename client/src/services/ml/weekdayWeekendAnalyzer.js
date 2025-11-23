/**
 * weekdayWeekendAnalyzer.js
 * Analyzes communication patterns: weekday vs weekend, work hours vs off-hours
 * Shows prioritization and availability patterns
 * Reveals if someone prioritizes you during busy times vs only on weekends
 */

/**
 * Analyze weekday vs weekend communication patterns
 * @param {Array} messages - Normalized messages from messageParser
 * @returns {Object} Weekday/weekend analysis
 */
export function analyzeWeekdayWeekend(messages) {
  if (!messages || messages.length < 2) {
    return {
      summary: 'Need at least 2 messages for pattern analysis',
      data: null,
    }
  }

  const weekdayData = categorizeByDayOfWeek(messages)
  const timeOfDayData = categorizeByTimeOfDay(messages)
  const yourAnalysis = analyzePartyPatterns(messages, 'sent')
  const themAnalysis = analyzePartyPatterns(messages, 'received')

  return {
    weekdayWeekendDistribution: weekdayData.distribution,
    timeOfDayDistribution: timeOfDayData.distribution,
    you: yourAnalysis,
    them: themAnalysis,
    patterns: detectAvailabilityPatterns(messages),
    summary: generateWeekdayWeekendSummary(weekdayData, timeOfDayData, yourAnalysis, themAnalysis),
  }
}

/**
 * Categorize messages by day of week
 * @param {Array} messages - Messages
 * @returns {Object} Day-of-week statistics
 */
function categorizeByDayOfWeek(messages) {
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
  const dayStats = {
    Sunday: { count: 0, messages: [] },
    Monday: { count: 0, messages: [] },
    Tuesday: { count: 0, messages: [] },
    Wednesday: { count: 0, messages: [] },
    Thursday: { count: 0, messages: [] },
    Friday: { count: 0, messages: [] },
    Saturday: { count: 0, messages: [] },
  }

  messages.forEach((message) => {
    const dayIndex = message.timestamp.getDay()
    const dayName = days[dayIndex]
    dayStats[dayName].count++
    dayStats[dayName].messages.push(message)
  })

  // Calculate percentages and identify patterns
  const total = messages.length
  const distribution = {}
  const weekdayCount = dayStats.Monday.count + dayStats.Tuesday.count + dayStats.Wednesday.count + dayStats.Thursday.count + dayStats.Friday.count
  const weekendCount = dayStats.Saturday.count + dayStats.Sunday.count

  Object.keys(dayStats).forEach((day) => {
    const dayData = dayStats[day]
    distribution[day] = {
      count: dayData.count,
      percentage: parseFloat(((dayData.count / total) * 100).toFixed(1)),
      sent: dayData.messages.filter((m) => m.direction === 'sent').length,
      received: dayData.messages.filter((m) => m.direction === 'received').length,
    }
  })

  const weekdayPercentage = parseFloat(((weekdayCount / total) * 100).toFixed(1))
  const weekendPercentage = parseFloat(((weekendCount / total) * 100).toFixed(1))

  return {
    distribution,
    summary: {
      weekday: {
        count: weekdayCount,
        percentage: weekdayPercentage,
      },
      weekend: {
        count: weekendCount,
        percentage: weekendPercentage,
      },
      busierDay: getBusiestDay(distribution),
      quietestDay: getQuietestDay(distribution),
    },
  }
}

/**
 * Get busiest day of week
 * @param {Object} distribution - Day distributions
 * @returns {string} Busiest day
 */
function getBusiestDay(distribution) {
  let busiest = 'Sunday'
  let maxCount = 0
  Object.entries(distribution).forEach(([day, data]) => {
    // ARCHITECTURAL FIX: Safe count access with defensive checks
    const count = data && typeof data.count === 'number' ? data.count : 0
    if (count > maxCount) {
      maxCount = count
      busiest = day
    }
  })
  return busiest
}

/**
 * Get quietest day of week
 * @param {Object} distribution - Day distributions
 * @returns {string} Quietest day
 */
function getQuietestDay(distribution) {
  let quietest = 'Sunday'
  let minCount = Infinity
  Object.entries(distribution).forEach(([day, data]) => {
    // ARCHITECTURAL FIX: Safe count access with defensive checks
    const count = data && typeof data.count === 'number' ? data.count : 0
    if (count < minCount && count > 0) {
      minCount = count
      quietest = day
    }
  })
  return quietest
}

/**
 * Categorize messages by time of day
 * @param {Array} messages - Messages
 * @returns {Object} Time of day statistics
 */
function categorizeByTimeOfDay(messages) {
  const timeStats = {
    'Morning (6am-12pm)': { count: 0, messages: [] },
    'Afternoon (12pm-5pm)': { count: 0, messages: [] },
    'Evening (5pm-10pm)': { count: 0, messages: [] },
    'Night (10pm-6am)': { count: 0, messages: [] },
  }

  messages.forEach((message) => {
    const hour = message.timestamp.getHours()
    let timeSlot

    if (hour >= 6 && hour < 12) timeSlot = 'Morning (6am-12pm)'
    else if (hour >= 12 && hour < 17) timeSlot = 'Afternoon (12pm-5pm)'
    else if (hour >= 17 && hour < 22) timeSlot = 'Evening (5pm-10pm)'
    else timeSlot = 'Night (10pm-6am)'

    timeStats[timeSlot].count++
    timeStats[timeSlot].messages.push(message)
  })

  // Calculate percentages
  const total = messages.length
  const distribution = {}

  Object.keys(timeStats).forEach((timeSlot) => {
    const slotData = timeStats[timeSlot]
    distribution[timeSlot] = {
      count: slotData.count,
      percentage: parseFloat(((slotData.count / total) * 100).toFixed(1)),
      sent: slotData.messages.filter((m) => m.direction === 'sent').length,
      received: slotData.messages.filter((m) => m.direction === 'received').length,
    }
  })

  // ARCHITECTURAL FIX: Safe reduce with defensive checks
  // Prevents crash when distribution is empty or has undefined values
  const entries = Object.entries(distribution)
  let busiestTime = 'Unknown'

  if (entries.length > 0) {
    try {
      const maxEntry = entries.reduce((a, b) => {
        // Defensive check: ensure both entries have valid count properties
        const aCount = a && a[1] && typeof a[1].count === 'number' ? a[1].count : 0
        const bCount = b && b[1] && typeof b[1].count === 'number' ? b[1].count : 0
        return aCount > bCount ? a : b
      })
      busiestTime = maxEntry[0]
    } catch (error) {
      console.warn('Error calculating busiest time:', error)
      busiestTime = 'Unknown'
    }
  }

  return {
    distribution,
    busiestTime,
  }
}

/**
 * Analyze patterns for one party
 * @param {Array} messages - All messages
 * @param {string} direction - 'sent' or 'received'
 * @returns {Object} Party-specific analysis
 */
function analyzePartyPatterns(messages, direction) {
  const partyMessages = messages.filter((m) => m.direction === direction)

  if (partyMessages.length === 0) {
    return { none: 'No messages in this direction' }
  }

  // Day of week breakdown for this party
  const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
  const dayBreakdown = {}

  days.forEach((day) => {
    const count = partyMessages.filter((m) => days[m.timestamp.getDay()] === day).length
    if (count > 0) {
      dayBreakdown[day] = count
    }
  })

  // Time of day breakdown
  const timeBreakdown = {
    morning: partyMessages.filter((m) => {
      const h = m.timestamp.getHours()
      return h >= 6 && h < 12
    }).length,
    afternoon: partyMessages.filter((m) => {
      const h = m.timestamp.getHours()
      return h >= 12 && h < 17
    }).length,
    evening: partyMessages.filter((m) => {
      const h = m.timestamp.getHours()
      return h >= 17 && h < 22
    }).length,
    night: partyMessages.filter((m) => {
      const h = m.timestamp.getHours()
      return h < 6 || h >= 22
    }).length,
  }

  // Calculate work hours vs off-hours
  const workHours = partyMessages.filter((m) => {
    const h = m.timestamp.getHours()
    const d = m.timestamp.getDay()
    // Work hours: Mon-Fri, 9am-5pm
    return d >= 1 && d <= 5 && h >= 9 && h < 17
  }).length

  const offHours = partyMessages.length - workHours

  return {
    totalMessages: partyMessages.length,
    dayBreakdown,
    timeBreakdown,
    workHoursVsOffHours: {
      workHours,
      offHours,
      workHoursPercentage: parseFloat(((workHours / partyMessages.length) * 100).toFixed(1)),
      offHoursPercentage: parseFloat(((offHours / partyMessages.length) * 100).toFixed(1)),
      pattern: interpretWorkHoursPattern(workHours, offHours, partyMessages.length),
    },
    preferredTime: getPreferredTime(timeBreakdown),
  }
}

/**
 * Interpret work hours vs off-hours pattern
 * @param {number} workHours - Messages during work hours
 * @param {number} offHours - Messages during off-hours
 * @param {number} total - Total messages
 * @returns {string} Pattern interpretation
 */
function interpretWorkHoursPattern(workHours, offHours, total) {
  const workPercentage = (workHours / total) * 100

  if (workPercentage > 60) {
    return 'Primarily communicates during work hours - may be sneaking time during busy schedule'
  } else if (workPercentage > 40) {
    return 'Communicates during both work and off-hours - balanced approach'
  } else {
    return 'Primarily communicates during off-hours - prioritizes personal time for you'
  }
}

/**
 * Get preferred time of day
 * @param {Object} timeBreakdown - Time breakdown data
 * @returns {string} Preferred time
 */
function getPreferredTime(timeBreakdown) {
  const times = Object.keys(timeBreakdown)
  return times.reduce((a, b) => (timeBreakdown[a] > timeBreakdown[b] ? a : b))
}

/**
 * Detect availability patterns
 * @param {Array} messages - Messages
 * @returns {Array} Detected patterns
 */
function detectAvailabilityPatterns(messages) {
  const patterns = []

  // Weekend warrior pattern (very active on weekends)
  const dayStats = categorizeByDayOfWeek(messages)
  const saturdayPercent = dayStats.distribution.Saturday.percentage
  const sundayPercent = dayStats.distribution.Sunday.percentage
  const weekendAvg = (saturdayPercent + sundayPercent) / 2
  const weekdayAvg = 20 // Average expected if evenly distributed

  if (weekendAvg > weekdayAvg * 1.5) {
    patterns.push({
      name: 'Weekend Warrior',
      description: 'Much more active on weekends than weekdays',
      severity: 'high',
    })
  }

  // Night owl pattern
  const nightMessages = messages.filter((m) => {
    const h = m.timestamp.getHours()
    return h < 6 || h >= 22
  }).length
  const nightPercent = (nightMessages / messages.length) * 100

  if (nightPercent > 30) {
    patterns.push({
      name: 'Night Owl',
      description: 'Frequently communicates late at night (10pm-6am)',
      severity: 'medium',
    })
  }

  // Early bird pattern
  const morningMessages = messages.filter((m) => {
    const h = m.timestamp.getHours()
    return h >= 5 && h < 9
  }).length
  const morningPercent = (morningMessages / messages.length) * 100

  if (morningPercent > 20) {
    patterns.push({
      name: 'Early Bird',
      description: 'Often reaches out in early morning (5am-9am)',
      severity: 'low',
    })
  }

  // Lunch break pattern
  const lunchMessages = messages.filter((m) => {
    const h = m.timestamp.getHours()
    return h >= 12 && h < 13
  }).length
  const lunchPercent = (lunchMessages / messages.length) * 100

  if (lunchPercent > 15) {
    patterns.push({
      name: 'Lunch Break Communicator',
      description: 'Regularly reaches out during lunch time',
      severity: 'low',
    })
  }

  return patterns
}

/**
 * Generate summary
 * @param {Object} weekdayData - Weekday analysis
 * @param {Object} timeOfDayData - Time of day analysis
 * @param {Object} yourAnalysis - Your patterns
 * @param {Object} themAnalysis - Their patterns
 * @returns {string} Summary text
 */
function generateWeekdayWeekendSummary(weekdayData, timeOfDayData, yourAnalysis, themAnalysis) {
  const summary = []

  const weekendDiff = weekdayData.summary.weekend.percentage - weekdayData.summary.weekday.percentage

  if (Math.abs(weekendDiff) < 5) {
    summary.push('Communication is evenly distributed throughout the week')
  } else if (weekendDiff > 5) {
    summary.push(`More active on weekends (${weekdayData.summary.weekend.percentage}% vs ${weekdayData.summary.weekday.percentage}%)`)
  } else {
    summary.push(`More active on weekdays (${weekdayData.summary.weekday.percentage}% vs ${weekdayData.summary.weekend.percentage}%)`)
  }

  if (yourAnalysis.workHoursVsOffHours) {
    if (yourAnalysis.workHoursVsOffHours.workHoursPercentage > 50) {
      summary.push('You prioritize messaging during work hours - multitasking at work')
    } else {
      summary.push('You prioritize messaging during off-hours - dedicating personal time')
    }
  }

  if (themAnalysis.workHoursVsOffHours) {
    if (themAnalysis.workHoursVsOffHours.offHoursPercentage > 60) {
      summary.push('They primarily message during off-hours - you are a priority outside work')
    } else if (themAnalysis.workHoursVsOffHours.workHoursPercentage > 50) {
      summary.push('They often message during work hours - you are worth their work time attention')
    }
  }

  return summary.join('. ')
}
